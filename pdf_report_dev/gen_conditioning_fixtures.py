"""신호 처리 시험용 픽스처를 만든다.

사용법 (저장소 루트에서):
    python pdf_report_dev/gen_conditioning_fixtures.py \
        test/fixtures/conditioning_input_dev_256hz.txt test/fixtures

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
                                     같은 길(신호 처리 → 운동 → 가중 → 운행 구간
                                     → 반주기 P2P)로 계산한 지표
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
    acc = c[:, 2] * 9.80665e-3
    acc = acc - acc.mean()
    v = np.cumsum(acc) / FS
    v = v - (v[0] + (v[-1] - v[0]) * np.arange(n) / (n - 1))
    pos = np.cumsum(np.abs(v)) / FS
    start = int(np.argmax(np.abs(pos - pos[0]) > EDGE_M))
    end = int(n - 1 - np.argmax(np.abs(pos[-1] - pos[::-1]) > EDGE_M))
    w = slice(start, end + 1)
    out = {'rows100': n, 'maxSpeed': float(np.abs(v).max()),
           'distance': float(pos.max() - pos.min()),
           'startIndex': start, 'endIndex': end}
    series = {'x': weight_horizontal(c[:, 0]), 'y': weight_horizontal(c[:, 1]),
              'z': weight_vertical(c[:, 2])}
    for k, s in series.items():
        p2p = _half_cycle_p2p(s[w])
        vals = sorted(p for p, _, _ in p2p)
        best = max(p2p, key=lambda t: t[0])
        out[k + 'Ptp'] = float(best[0])
        out[k + 'PtpIndices'] = [best[1] + start, best[2] + start]
        out[k + 'A95'] = float(vals[int(np.ceil(0.95 * len(vals))) - 1])
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


if __name__ == '__main__':
    if sys.argv[1] == '--weighting':
        weighting(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        main(sys.argv[1], sys.argv[2])
