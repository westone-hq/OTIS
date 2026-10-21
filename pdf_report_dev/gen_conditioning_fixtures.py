"""신호 처리 시험용 픽스처를 만든다.

사용법 (저장소 루트에서):
    python pdf_report_dev/gen_conditioning_fixtures.py \
        test/fixtures/conditioning_input_dev_256hz.txt test/fixtures

    # 2026-10-21 저크 · 가속도 차트 저역 픽스처 1개만 만든다
    python pdf_report_dev/gen_conditioning_fixtures.py --jerk test/fixtures

    # 2026-10-15 가중 · 운행 구간 픽스처 2개만 만든다(아래 3개는 건드리지 않는다)
    python pdf_report_dev/gen_conditioning_fixtures.py --weighting \
        test/fixtures/ride_reference.txt \
        test/fixtures/conditioning_input_dev_256hz.txt test/fixtures

입력: EVIMP1 형식 256Hz 격자 (첫 두 줄 'EVIMP1', '256', 이후 'X Y Z noise')
출력:
    conditioning_expected_100hz.txt  기준선 제거 → sosfiltfilt → resample_poly(25, 64)
    conditioning_unit_cases.json     10Hz + 60Hz 합성 신호 300표본의
                                     filtfilt / resample_25_64 / sos
--weighting 출력:
    weighting_unit_cases.json        100Hz 합성 신호 400표본에 건 ISO 8041 가중
                                     (수평 Wd, 수직 1Hz 고역 양방향 + Wk)과 계수
    weighting_expected_metrics.json  두 실측 기록(ride_reference, 개발폰)을 앱과
                                     같은 길(신호 처리 → 운동 → 가중(수직은 뒤에
                                     20Hz 저역) → 운행 구간 → 반주기 P2P, 수직
                                     최대 · Jptp 는 정속 · 가감속 구간)로 계산한 지표
주의: unit_cases 의 값은 소수 12자리로 반올림해 저장한다.
      그래서 다시 만든 값과 6.7e-13 정도 차이가 날 수 있다(시험 기준 1e-9).
"""
import json
import sys
from pathlib import Path

import numpy as np
import scipy
from scipy.signal import bilinear, butter, resample_poly, sosfilt, sosfiltfilt

RATE_IN = 256
UP, DOWN = 25, 64
CUTOFF_HZ = 40
ORDER = 4
BASELINE_ROWS = 256  # 1000ms
MOTION_MPS = 0.05  # CaptureConfig.motionSpeedThresholdMps
MOTION_PAD_MS = 500  # CaptureConfig.motionPaddingMs


def main(src: str, out_dir: str) -> None:
    out = Path(out_dir)
    d = np.loadtxt(src, skiprows=2)
    xyz = d[:, :3]

    sos = butter(ORDER, CUTOFF_HZ, fs=RATE_IN, output='sos')
    off = xyz[:BASELINE_ROWS].mean(0)
    y = sosfiltfilt(sos, xyz - off, axis=0)
    y100 = resample_poly(y, UP, DOWN, axis=0, window=('kaiser', 5.0))

    np.savetxt(
        out / 'conditioning_expected_100hz.txt', y100, fmt='%.9f',
        header=(f'baseline-removed, sosfiltfilt(butter({ORDER},{CUTOFF_HZ},'
                f'fs={RATE_IN})), resample_poly({UP},{DOWN}) of '
                f'{Path(src).name} | scipy {scipy.__version__} | '
                'columns: x_mg y_mg z_mg'),
        comments='# ')

    n = np.arange(300)
    t = n / RATE_IN
    x = np.sin(2 * np.pi * 10 * t) + 0.5 * np.sin(2 * np.pi * 60 * t) + 0.2
    cases = {
        'input': x.round(12).tolist(),
        'filtfilt': sosfiltfilt(sos, x).round(12).tolist(),
        'resample_25_64': resample_poly(
            x, UP, DOWN, window=('kaiser', 5.0)).round(12).tolist(),
        'sos': sos.tolist(),
    }
    (out / 'conditioning_unit_cases.json').write_text(json.dumps(cases))

    print('scipy', scipy.__version__, 'rows', len(d), '->', len(y100))
    print('baseline', off)


# ---- 2026-10-15 가중 · 운행 구간 (lib/domain/capture/ride_weighting.dart,
#      lib/domain/report/travel_window.dart, half_cycle.dart 와 같은 정의) ----
FS = 100
EDGE_M = 0.5            # CaptureConfig.travelEdgeExclusionM
Z_HP_HZ, Z_HP_ORDER = 1.0, 2


def _stage_hp(f, q=1 / np.sqrt(2)):
    w = 2 * np.pi * f
    return [1, 0, 0], [1, w / q, w * w]


def _stage_transition(f, q):
    w = 2 * np.pi * f
    return [0, w, w * w], [1, w / q, w * w]


def _stage_step(f5, f6, q):
    w5, w6 = 2 * np.pi * f5, 2 * np.pi * f6
    return [1, w5 / q, w5 * w5], [1, w6 / q, w6 * w6]


WD = [_stage_hp(0.4), _stage_transition(2.0, 0.63)]
WK = [_stage_hp(0.4), _stage_transition(12.5, 0.63), _stage_step(2.37, 3.35, 0.91)]


def _sos(stages, fs=FS):
    rows = []
    for b, a in stages:
        bd, ad = bilinear(b, a, fs=fs)
        rows.append(np.concatenate([bd / ad[0], ad / ad[0]]))
    return np.array(rows)


def _hp1(fs=FS):
    return butter(Z_HP_ORDER, Z_HP_HZ, btype='high', fs=fs, output='sos')


def weight_horizontal(x, fs=FS):
    return sosfilt(_sos(WD, fs), x)


def weight_vertical(z, fs=FS):
    return sosfilt(_sos(WK, fs), sosfiltfilt(_hp1(fs), z))


Z_LP_HZ, Z_LP_ORDER = 20.0, 4  # CaptureConfig.rideVerticalLowpassHz · Order (2026-10-21 2차)
ZONE_V, ZONE_PEAK, ZONE_A, ZONE_MIN_S = 0.05, 0.5, 0.03, 1.0  # CaptureConfig.zone* (2026-10-21)


def vertical_path(z, fs=FS):
    """앱 수직 경로: 가중(1Hz 고역 양방향 + Wk) 뒤 20Hz 4차 저역 양방향."""
    return sosfiltfilt(butter(Z_LP_ORDER, Z_LP_HZ, fs=fs, output='sos'), weight_vertical(z, fs))


def _zones(v, smooth):
    """MotionZones.of() 와 같다. 정하지 못하면 None."""
    run = np.where(np.abs(v) > ZONE_V)[0]
    if not len(run):
        return None
    rs, re = run[0], run[-1]
    a = np.abs(smooth)
    over = np.where(a[rs:re + 1] > a[rs:re + 1].max() * ZONE_PEAK)[0] + rs
    ap, dp = over[0], over[-1]
    cs = next((i for i in range(ap, dp + 1) if a[i] < ZONE_A), None)
    ce = next((i for i in range(dp, ap - 1, -1) if a[i] < ZONE_A), None)
    if cs is None or ce is None or ce - cs + 1 < round(ZONE_MIN_S * FS):
        return None
    return int(rs), int(re), int(cs), int(ce)


def _max_p2p(series, lo, hi):
    p = _half_cycle_p2p(series[lo:hi + 1]) if hi > lo else []
    if not p:
        return None
    best = max(p, key=lambda t: t[0])
    return float(best[0]), [best[1] + lo, best[2] + lo]


def _half_cycle_p2p(series):
    peaks, idx = [], []
    cur, cur_i, sign = 0.0, -1, 0
    for i, v in enumerate(series):
        sg = 1 if v > 0 else (-1 if v < 0 else 0)
        if sg == 0:
            continue
        if sign != 0 and sg != sign:
            peaks.append(cur)
            idx.append(cur_i)
            cur, cur_i = 0.0, -1
        sign = sg
        if abs(v) > cur:
            cur, cur_i = abs(v), i
    if sign != 0:
        peaks.append(cur)
        idx.append(cur_i)
    return [(peaks[i] + peaks[i + 1], idx[i], idx[i + 1]) for i in range(len(peaks) - 1)]


def _pipeline(src):
    d = np.loadtxt(src, skiprows=2)
    xyz = d[:, :3]
    noise = d[:, 3] if d.shape[1] > 3 else np.zeros(len(d))
    sos = butter(ORDER, CUTOFF_HZ, fs=RATE_IN, output='sos')
    c = resample_poly(sosfiltfilt(sos, xyz - xyz[:BASELINE_ROWS].mean(0), axis=0),
                      UP, DOWN, axis=0, window=('kaiser', 5.0))
    n = len(c)
    noise100 = np.interp(np.arange(n) / FS, np.arange(len(noise)) / RATE_IN, noise)
    # 운동: 움직인 구간만 적분한다(2026-10-20, 앱 _deriveKinematics 와 같다)
    acc = c[:, 2] * 9.80665e-3
    a0 = acc - acc.mean()
    v0 = np.cumsum(a0) / FS
    v0 = v0 - (v0[0] + (v0[-1] - v0[0]) * np.arange(n) / (n - 1))
    moving = np.where(np.abs(v0) > MOTION_MPS)[0]
    v = np.zeros(n)
    if len(moving):
        pad = round(MOTION_PAD_MS / 1000 * FS)
        ms, me = max(0, moving[0] - pad), min(n - 1, moving[-1] + pad)
        acc = acc - acc[ms:me + 1].mean()
        v[ms:me + 1] = np.cumsum(acc[ms:me + 1]) / FS
    pos = np.cumsum(np.abs(v)) / FS
    start = int(np.argmax(np.abs(pos - pos[0]) > EDGE_M))
    end = int(n - 1 - np.argmax(np.abs(pos[-1] - pos[::-1]) > EDGE_M))
    w = slice(start, end + 1)
    out = {'rows100': n, 'maxSpeed': float(np.abs(v).max()),
           'distance': float(pos[-1]),
           'startIndex': start, 'endIndex': end}
    series = {'x': weight_horizontal(c[:, 0]), 'y': weight_horizontal(c[:, 1]),
              'z': vertical_path(c[:, 2])}
    for k, s in series.items():
        p2p = _half_cycle_p2p(s[w])
        vals = sorted(p for p, _, _ in p2p)
        best = max(p2p, key=lambda t: t[0])
        out[k + 'Ptp'] = float(best[0])
        out[k + 'PtpIndices'] = [best[1] + start, best[2] + start]
        out[k + 'A95'] = float(vals[int(np.ceil(0.95 * len(vals))) - 1])
    # 수직 최대 = 정속 구간 최대, Jptp = 가감속 구간 최대 (2026-10-21, 앱 MotionZones)
    smooth = sosfiltfilt(butter(4, 1.6, fs=FS, output='sos'), acc)
    zones = _zones(v, smooth)
    if zones is None:
        out['zPtp'] = out['zPtpIndices'] = out['zJptp'] = None
    else:
        rs, re, cs, ce = zones
        out['steadyStartIndex'], out['steadyEndIndex'] = cs, ce
        out['zPtp'], out['zPtpIndices'] = _max_p2p(series['z'], cs, ce)
        js = [j for j in (_max_p2p(series['z'], rs, cs - 1), _max_p2p(series['z'], ce + 1, re)) if j]
        out['zJptp'] = max(j[0] for j in js) if js else None
    wn = noise100[w]
    wn = wn[wn != 0]
    out['noiseAvg'] = float(wn.mean()) if len(wn) else None
    out['noiseMax'] = float(wn.max()) if len(wn) else None
    return out


def weighting(ride_src: str, dev_src: str, out_dir: str) -> None:
    out = Path(out_dir)
    t = np.arange(400) / FS
    x = (2.0 * np.sin(2 * np.pi * 0.3 * t) + np.sin(2 * np.pi * 5 * t)
         + 0.5 * np.sin(2 * np.pi * 20 * t)).round(12)
    cases = {
        'fs': FS,
        'input': x.tolist(),
        'wd': weight_horizontal(x).round(12).tolist(),
        'vertical': weight_vertical(x).round(12).tolist(),
        'sos_wd': _sos(WD).tolist(),
        'sos_wk': _sos(WK).tolist(),
        'sos_hp1': _hp1().tolist(),
    }
    (out / 'weighting_unit_cases.json').write_text(json.dumps(cases))
    metrics = {
        'scipy': scipy.__version__,
        'ride_reference': _pipeline(ride_src),
        'dev_20261006': _pipeline(dev_src),
    }
    (out / 'weighting_expected_metrics.json').write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps(metrics, indent=2, ensure_ascii=False))


JERK_HZ, JERK_ORDER = 1.6, 4      # CaptureConfig.jerkLowpassHz · jerkLowpassOrder
ACC_CHART_HZ, ACC_CHART_ORDER = 10.0, 4  # 3쪽 가속도 차트 저역 (2026-10-21)


def jerk(out_dir: str) -> None:
    """2026-10-21 저크 · 가속도 차트 저역 픽스처(jerk_unit_cases.json)를 만든다.

    100Hz 합성 가속도(m/s²) 600표본: 사다리꼴 가감속 + 7Hz · 23Hz 흔들림.
    1.6Hz · 10Hz 4차 버터워스 계수와 sosfiltfilt 출력, 1.6Hz 출력의 중앙 차분.
    """
    out = Path(out_dir)
    t = np.arange(600) / FS
    ramp = np.clip(t - 1.0, 0, 1) - np.clip(t - 4.0, 0, 1)  # 1~2초 올라 4~5초 내려감
    x = (0.5 * ramp + 0.05 * np.sin(2 * np.pi * 7 * t)
         + 0.02 * np.sin(2 * np.pi * 23 * t)).round(12)
    sos_j = butter(JERK_ORDER, JERK_HZ, fs=FS, output='sos')
    sos_a = butter(ACC_CHART_ORDER, ACC_CHART_HZ, fs=FS, output='sos')
    smooth = sosfiltfilt(sos_j, x)
    j = np.empty_like(smooth)
    j[1:-1] = (smooth[2:] - smooth[:-2]) * FS / 2
    j[0] = (smooth[1] - smooth[0]) * FS
    j[-1] = (smooth[-1] - smooth[-2]) * FS
    cases = {
        'scipy': scipy.__version__,
        'fs': FS,
        'input': x.tolist(),
        'sos_jerk': sos_j.tolist(),
        'smooth_jerk': smooth.round(12).tolist(),
        'jerk': j.round(12).tolist(),
        'sos_acc_chart': sos_a.tolist(),
        'acc_chart': sosfiltfilt(sos_a, x).round(12).tolist(),
    }
    (out / 'jerk_unit_cases.json').write_text(json.dumps(cases))
    print('jerk_unit_cases.json', len(x), 'samples')


if __name__ == '__main__':
    if sys.argv[1] == '--weighting':
        weighting(sys.argv[2], sys.argv[3], sys.argv[4])
    elif sys.argv[1] == '--jerk':
        jerk(sys.argv[2])
    else:
        main(sys.argv[1], sys.argv[2])
