#!/usr/bin/env python3
"""샘플 리포트 생성.

    python build_sample.py --source evimp  --out out/sample_evimp.pdf
    python build_sample.py --source xlsx   --out out/sample_app.pdf
    python build_sample.py --source evimp  --out out/debug.pdf --debug

--debug 는 모든 플레이스홀더 위치에 마젠타 십자와 키 이름을 찍는다. 좌표 검증용.
"""

from __future__ import annotations

import argparse
import os

import numpy as np

from tune_report import charts, metrics, render

HERE = os.path.dirname(os.path.abspath(__file__))


def load_evimp(path: str) -> metrics.Signals:
    """OTIS EVIMP1 원본 포맷: 헤더 2줄(태그, 샘플레이트) + X Y Z dBA 4열."""
    with open(path) as fh:
        lines = [ln.strip() for ln in fh if ln.strip()]
    fs = float(lines[1])
    d = np.array([[float(v) for v in ln.split()] for ln in lines[2:]])
    t = np.arange(len(d)) / fs
    return metrics.Signals(t=t, x=d[:, 0], y=d[:, 1], z=d[:, 2],
                           noise=d[:, 3], fs=fs)


def load_app_xlsx(path: str) -> metrics.Signals:
    """앱 측정 데이터. '2_분석데이터' 시트를 쓴다."""
    import openpyxl
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb["2_분석데이터"]
    rows = list(ws.iter_rows(min_row=2, values_only=True))
    arr = np.array([[float(v if v is not None else 0) for v in r[:10]]
                    for r in rows])
    t = arr[:, 0]
    fs = 1.0 / np.median(np.diff(t))
    return metrics.Signals(
        t=t, x=arr[:, 8], y=arr[:, 9], z=arr[:, 4], noise=arr[:, 7], fs=fs,
        velocity=arr[:, 5], position=arr[:, 6])


#: 템플릿 헤더 칸과 앱 데이터의 대응.
#:
#: 요구사항서 6쪽 '현장 정보'(제번·현장명·최하층·최상층)를 우선 배치하고,
#: 앱이 들고 있지 않은 칸은 고정값으로 채우거나 비운다.
#:
#:   측정 ID   <- jobNo (제번)
#:   엔지니어   <- 로그인 ID. 미연결이면 공백
#:   일시      <- dateTime
#:   제품      고정 '엘리베이터'
#:   하중      공백 — 현장마다 달라 고정할 수 없고 앱이 입력받지 않는다
#:   품질성능기준 고정 'Standard'
#:   측정      고정 '층간 시험'
#:   운전 방향  <- direction
#:   층 정보    <- bottomFloor / topFloor
#:   건물명     <- siteName (현장명)
#:   주소      공백 — 앱이 입력받지 않는다
SAMPLE_META = {
    "measurement_id": "2025F 1234R01",
    "engineer_name": "",
    "datetime": "14/01/2026 11:03:59 AM",
    "product": "엘리베이터",
    "load": "",
    "standard": "Standard",
    "test_type": "층간 시험",
    "direction": "하부에서 상부로",
    "floors": "시작층 : b2, 도착층 : 6",
    "building_name": "럭키종합건설/송정동근생",
    "address": "",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["evimp", "xlsx"], default="evimp")
    ap.add_argument("--input", default=None)
    ap.add_argument("--out", default="out/sample.pdf")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--original-axes", action="store_true",
                    help="진동 축을 원본 범위(±4/±10)로 되돌린다. 필터 확정 후 사용.")
    args = ap.parse_args()

    if args.original_axes:
        charts.use_original_vibration_limits()

    if args.source == "evimp":
        src = args.input or os.path.join(
            HERE, "..", "test", "fixtures", "ride_reference.txt")
        sig = load_evimp(src)
    else:
        src = args.input or os.path.join(
            HERE, "..", "test", "fixtures", "app_measurement.xlsx")
        sig = load_app_xlsx(src)

    sig = metrics.derive_kinematics(sig)
    rm = metrics.compute(sig)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    r = render.ReportRenderer(os.path.join(HERE, "report_layout.json"), debug=args.debug)
    out = r.build(args.out, SAMPLE_META, rm, signals=sig)

    print(f"입력   : {src}")
    print(f"구간   : {rm.duration_s:.2f} s / {len(sig.t)} 샘플 @ {sig.fs:.1f} Hz")
    for k, m in rm.metrics.items():
        print(f"  {k:16s} {m.format_value():>18s}   판정 {m.verdict}")
    print(f"출력   : {out}")


if __name__ == "__main__":
    main()
