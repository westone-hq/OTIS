"""차트 레이어.

A4 한 장 크기의 투명 배경 PDF 를 만들고, layout.json 의 plot_box 좌표에 맞춰
축 프레임을 정확히 배치한다. 결과는 벡터라 확대해도 선명하다.
render.py 가 이 PDF 를 배경+텍스트 레이어 위에 합성한다.

축 범위는 AXES 에 상수로 박아 둔다. 원본 리포트에서 읽은 값이 기준이고,
X/Y 진동만 필터 확정 전 임시로 넓혀 두었다(주석 참조).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Sequence

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.font_manager import FontProperties


PAGE_W_PT = 595.276
PAGE_H_PT = 841.89
#: 서식 비율(1.414007)이 A4(1.414285)와 미세하게 달라 축별 계수를 쓴다.
PT_PER_PX_X = PAGE_W_PT / 2256
PT_PER_PX_Y = PAGE_H_PT / 3190


@dataclass
class AxisSpec:
    key: str
    ylabel: str
    ylim: tuple[float, float]
    yticks: Optional[Sequence[float]] = None
    #: ylim 이 데이터에 따라 단계적으로 올라가야 하는 축(위치·속도 등)
    ladder: Optional[Sequence[tuple[float, float]]] = None


#: 원본 리포트에서 읽은 축 범위.
#:
#: X/Y 진동의 원본 값은 (-4, 4) 와 (-10, 10) 인데, 이는 저역통과 필터를 거친
#: 파형 기준이다. 필터 미적용 원시 데이터를 그대로 그리면 8% 이상이 잘려
#: 파형이 뭉개지므로, 필터 확정 전까지만 임시로 넓혀 둔다.
#: 필터가 확정되면 ORIGINAL_VIBRATION_YLIM 값으로 되돌린다.
ORIGINAL_VIBRATION_YLIM = {"x": (-4.0, 4.0), "y": (-10.0, 10.0)}

AXES = {
    "x":     AxisSpec("x", "X-Vibration (milli-g)", (-10.0, 10.0)),
    "y":     AxisSpec("y", "Y-Vibration (milli-g)", (-15.0, 15.0)),
    "z":     AxisSpec("z", "Vertical Vibration (milli-g)", (-20.0, 20.0)),
    "noise": AxisSpec("noise", "Noise Level (dBA)", (40.0, 54.0),
                      yticks=[40, 42, 44, 46, 48, 50, 52, 54]),

    "pos":  AxisSpec("pos", "pos (m)", (0.0, 60.0),
                     ladder=[(0, 10), (0, 25), (0, 50), (0, 100), (0, 150)]),
    "vel":  AxisSpec("vel", "vel (m/s)", (0.0, 2.0),
                     ladder=[(0, 1.0), (0, 2.0), (0, 4.0)]),
    "acc":  AxisSpec("acc", "acc (m/s^2)", (-1.0, 1.0),
                     ladder=[(-0.6, 0.6), (-1.0, 1.0), (-2.0, 2.0)]),
    "jerk": AxisSpec("jerk", "jerk (m/s^3)", (-1.5, 1.5),
                     ladder=[(-0.5, 0.5), (-1.5, 1.5), (-3.0, 3.0)]),
}

# TODO(필터): jerk 는 원시 가속도를 그대로 미분해서 고주파 잡음이 그대로 남는다.
# 원본 리포트의 jerk 곡선은 저역통과 후 미분한 것이라 매끈하다. X/Y 진동과 함께
# 필터 확정 시 같이 정리한다. 그 전까지 jerk 차트는 형태만 참고할 것.
PAGE2_CHANNELS = ["x", "y", "z", "noise"]
PAGE3_CHANNELS = ["pos", "vel", "acc", "jerk"]


def use_original_vibration_limits() -> None:
    """필터가 확정되면 이걸 호출해 원본 축 범위로 되돌린다."""
    AXES["x"].ylim = ORIGINAL_VIBRATION_YLIM["x"]
    AXES["y"].ylim = ORIGINAL_VIBRATION_YLIM["y"]


def _resolve_ylim(spec: AxisSpec, data: np.ndarray) -> tuple[float, float]:
    if not spec.ladder:
        return spec.ylim
    lo, hi = float(np.min(data)), float(np.max(data))
    for cand in spec.ladder:
        # 적분 잔차로 0 근처가 살짝 음수가 되는 경우가 있어 여유를 둔다.
        tol = (cand[1] - cand[0]) * 0.02
        if cand[0] - tol <= lo and hi <= cand[1] + tol:
            return cand
    return spec.ladder[-1]


def _axes_rect(plot_box: dict) -> list[float]:
    """템플릿 픽셀 좌표 -> matplotlib figure fraction [left, bottom, w, h]."""
    x_pt = plot_box["x"] * PT_PER_PX_X
    w_pt = plot_box["w"] * PT_PER_PX_X
    h_pt = plot_box["h"] * PT_PER_PX_Y
    top_pt = plot_box["y"] * PT_PER_PX_Y
    bottom_pt = PAGE_H_PT - (top_pt + h_pt)
    return [x_pt / PAGE_W_PT, bottom_pt / PAGE_H_PT, w_pt / PAGE_W_PT, h_pt / PAGE_H_PT]


def render_chart_page(out_path: str,
                      t: np.ndarray,
                      series: dict[str, np.ndarray],
                      channels: Sequence[str],
                      slots: Sequence[dict],
                      font: Optional[FontProperties] = None,
                      annotations: Optional[dict[str, str]] = None) -> str:
    """A4 크기 투명 배경 차트 PDF 를 만든다."""
    fig = plt.figure(figsize=(PAGE_W_PT / 72.0, PAGE_H_PT / 72.0))
    fig.patch.set_alpha(0.0)

    annotations = annotations or {}

    for ch, slot in zip(channels, slots):
        spec = AXES[ch]
        data = series.get(ch)
        ax = fig.add_axes(_axes_rect(slot["plot_box"]))
        ax.patch.set_alpha(0.0)

        if data is None or not len(data):
            ax.set_ylim(*spec.ylim)
        else:
            ax.plot(t, data, lw=0.35, color="#0000CC", solid_joinstyle="miter")
            ax.set_ylim(*_resolve_ylim(spec, data))

        ax.set_xlim(0, max(1.0, float(t[-1]) * 1.02) if len(t) else 1.0)
        if spec.yticks:
            ax.set_yticks(spec.yticks)

        ax.set_ylabel(spec.ylabel, fontsize=5.6, labelpad=2.5)
        ax.set_xlabel("Time (s)", fontsize=5.6, labelpad=2)
        ax.grid(True, which="major", ls="--", lw=0.3, color="#555555", alpha=0.9)
        ax.tick_params(labelsize=5.0, width=0.35, length=2.0, pad=1.5)
        for s in ax.spines.values():
            s.set_linewidth(0.4)

        note = annotations.get(ch)
        if note and data is not None and len(data):
            i = int(np.argmax(np.abs(data)))
            ax.annotate(note, xy=(t[i], data[i]), fontsize=5.2,
                        color="#111111", ha="center", va="bottom",
                        xytext=(0, 3), textcoords="offset points")
            ax.plot([t[i]], [data[i]], "o", ms=1.6, color="#E03030")

    fig.savefig(out_path, format="pdf", transparent=True)
    plt.close(fig)
    return out_path
