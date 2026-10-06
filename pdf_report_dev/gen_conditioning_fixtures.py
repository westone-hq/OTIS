"""신호 처리 시험용 픽스처 3개를 만든다.

사용법 (저장소 루트에서):
    python pdf_report_dev/gen_conditioning_fixtures.py \
        test/fixtures/conditioning_input_dev_256hz.txt test/fixtures

입력: EVIMP1 형식 256Hz 격자 (첫 두 줄 'EVIMP1', '256', 이후 'X Y Z noise')
출력:
    conditioning_expected_100hz.txt  기준선 제거 → sosfiltfilt → resample_poly(25, 64)
    conditioning_unit_cases.json     10Hz + 60Hz 합성 신호 300표본의
                                     filtfilt / resample_25_64 / sos
주의: unit_cases 의 값은 소수 12자리로 반올림해 저장한다.
      그래서 다시 만든 값과 6.7e-13 정도 차이가 날 수 있다(시험 기준 1e-9).
"""
import json
import sys
from pathlib import Path

import numpy as np
import scipy
from scipy.signal import butter, resample_poly, sosfiltfilt

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


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
