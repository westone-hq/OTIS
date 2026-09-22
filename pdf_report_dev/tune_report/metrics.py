"""측정 데이터 -> 리포트 지표.

이 모듈은 렌더링을 전혀 모른다. 나중에 진동 필터가 확정되면 여기만 고치면 되고
render.py 는 건드릴 일이 없다.

진동 지표(vert_avg / vert_max / horiz_avg / horiz_max)는 아직 필터 파라미터가
확정되지 않아 None 을 반환한다. None 은 리포트에서 '—' 로 표시되고 판정은 회색이 된다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np


# ---------------------------------------------------------------- 임계값

#: 적색 표시 기준. 출처는 `Vibration_Checking_App_Development_20260630.pdf` 6쪽
#: "결과 Report 파일에 포함되어야 하는 정보" 표다.
#:
#: 요구사항에는 황색 단계가 없다. 템플릿의 황색 컬럼은 비워 둔다.
#: H6N1AP65 리포트의 2단계 값(57/60, 72/75, 14/21 …)은 기존 iOS TuneApp 기준이며
#: 이 프로젝트의 요구사항이 아니므로 쓰지 않는다.
#:
#: 값이 None 인 항목은 요구사항에 기준이 없다는 뜻이고, 판정 대상에서 빠진다.
RED_LIMITS = {
    "noise_avg": None,        # 요구사항에 평균 소음 기준 없음
    "noise_max": 50.0,        # dBA
    "vert_avg": None,         # 요구사항에 평균 진동 기준 없음
    "vert_max": 15.0,         # Z축 p2p, mg
    "horiz_avg": None,
    "horiz_max": 10.0,        # X·Y축 p2p, mg. 둘 중 하나라도 넘으면 적색
    "max_speed": None,
    "travel_distance": None,
}

#: 행 라벨. 템플릿 이미지에 이미 박혀 있으므로 렌더러는 값만 찍는다.
#: 여기 둔 이유는 라벨 없는 템플릿으로 바꿀 때 바로 쓸 수 있게 하기 위해서다.
ROW_LABELS = {
    "noise_avg": "평균 소음 측정 수치",
    "noise_max": "최대 소음 측정 수치",
    "vert_avg": "평균 진동 측정 수치",
    "vert_max": "최대 진동 측정 수치",
    "horiz_avg": "평균 진동 측정 수치",
    "horiz_max": "최대 진동 측정 수치",
    "max_speed": "",
    "travel_distance": "",
}

ANALYSIS_ROWS = [
    "car_noise",
    "machine",
    "belts",
    "guide_rail",
    "transient_noise",
    "idler_sheave",
    "guide",
]


# ---------------------------------------------------------------- 자료구조


@dataclass
class Signals:
    """리샘플된 측정 신호. 모든 배열 길이가 같아야 한다."""

    t: np.ndarray           # 초
    x: np.ndarray           # 수평 X 가속도, milli-g
    y: np.ndarray           # 수평 Y 가속도, milli-g
    z: np.ndarray           # 수직 가속도, milli-g
    noise: np.ndarray       # dBA
    fs: float               # 샘플링 주파수, Hz
    position: Optional[np.ndarray] = None   # m
    velocity: Optional[np.ndarray] = None   # m/s
    accel: Optional[np.ndarray] = None      # m/s^2
    jerk: Optional[np.ndarray] = None       # m/s^3


@dataclass
class Metric:
    key: str
    value: Optional[float]
    unit: str
    suffix: str = ""              # 'A95' 같은 꼬리표
    detail: str = ""              # 축별 내역 등 값 뒤에 덧붙일 문구
    red: Optional[float] = None   # 적색 기준. None 이면 판정 대상 아님

    @property
    def judged(self) -> bool:
        return self.red is not None

    @property
    def verdict(self) -> str:
        """'green' | 'red' | 'unknown' | 'none'."""
        if self.red is None:
            return "none"
        if self.value is None:
            return "unknown"
        return "red" if self.value > self.red else "green"

    def format_value(self) -> str:
        if self.value is None:
            return "—"
        txt = f"{self.value:.0f}" if abs(self.value) >= 100 else f"{self.value:.1f}"
        out = f"{txt}{self.unit}"
        if self.suffix:
            out += f" {self.suffix}"
        if self.detail:
            out += f"  ({self.detail})"
        return out

    def format_red(self) -> str:
        """적색 컬럼에 찍을 문구. 기준이 없으면 빈칸."""
        return "" if self.red is None else f"{self.red:g}"


@dataclass
class ReportMetrics:
    metrics: dict[str, Metric] = field(default_factory=dict)
    analysis: dict[str, str] = field(default_factory=dict)
    duration_s: float = 0.0

    def __getitem__(self, key: str) -> Metric:
        return self.metrics[key]


# ---------------------------------------------------------------- 계산


def _trim_warmup(noise: np.ndarray) -> np.ndarray:
    """소음 센서 워밍업 구간(값 0)을 잘라낸다.

    앱 측정 데이터는 시작 직후 수십 샘플이 0으로 들어온다. 그대로 평균을 내면
    값이 끌려 내려가므로 유효값만 남긴다.
    """
    valid = noise[noise > 0]
    return valid if valid.size else noise


def compute(signals: Signals) -> ReportMetrics:
    """측정 신호에서 리포트 지표 8개를 만든다.

    진동 4개는 필터 파라미터가 확정되지 않아 None 이다. 원시 peak-to-peak 를
    대신 넣으면 전부 기준을 넘어 의미가 없으므로 채우지 않는다.
    """
    noise = _trim_warmup(signals.noise)

    def mk(key, value, unit, suffix="", detail=""):
        return Metric(key=key, value=value, unit=unit, suffix=suffix,
                      detail=detail, red=RED_LIMITS[key])

    max_speed = None
    if signals.velocity is not None and signals.velocity.size:
        max_speed = float(np.max(np.abs(signals.velocity)))

    distance = None
    if signals.position is not None and signals.position.size:
        distance = float(np.max(signals.position) - np.min(signals.position))

    metrics = {
        "noise_avg": mk("noise_avg", float(np.mean(noise)), "dBA"),
        "noise_max": mk("noise_max", float(np.max(noise)), "dBA"),

        # 필터 확정 후 채운다. 수평은 X·Y 중 큰 값을 싣고, 어느 축이었는지는
        # detail 에 'X 8.2 / Y 12.9' 형태로 함께 적는다. 요구사항이 X 와 Y 를
        # 각각 보고하도록 정하고 있어서 한쪽만 남기면 안 된다.
        "vert_avg":  mk("vert_avg",  None, "mg", suffix="A95"),
        "vert_max":  mk("vert_max",  None, "mg"),
        "horiz_avg": mk("horiz_avg", None, "mg", suffix="A95"),
        "horiz_max": mk("horiz_max", None, "mg"),

        "max_speed":       mk("max_speed", max_speed, "m/s"),
        "travel_distance": mk("travel_distance", distance, "m"),
    }

    return ReportMetrics(
        metrics=metrics,
        analysis={k: "" for k in ANALYSIS_ROWS},
        duration_s=float(signals.t[-1] - signals.t[0]) if signals.t.size else 0.0,
    )


# ---------------------------------------------------------------- 파생 물리량


def derive_kinematics(signals: Signals) -> Signals:
    """수직 가속도에서 위치·속도·가속도·jerk 를 만든다.

    이미 값이 들어있으면 건드리지 않는다(앱이 계산해 준 경우).
    """
    if signals.velocity is not None and signals.position is not None:
        return signals

    dt = 1.0 / signals.fs
    # milli-g -> m/s^2, 중력분은 z 에 이미 없다고 본다
    acc = signals.z * 9.80665e-3
    acc = acc - np.mean(acc)
    vel = np.cumsum(acc) * dt
    # 적분 드리프트 제거: 전체 구간 선형 추세를 뺀다
    vel = vel - np.linspace(vel[0], vel[-1], vel.size)
    pos = np.cumsum(np.abs(vel)) * dt
    jerk = np.gradient(acc, dt)

    signals.accel = acc
    signals.velocity = vel
    signals.position = pos
    signals.jerk = jerk
    return signals
