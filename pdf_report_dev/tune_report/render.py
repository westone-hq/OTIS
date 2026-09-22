"""배경 + 플레이스홀더 + 차트 합성.

배경 이미지를 깔고 layout.json 좌표에 텍스트/신호등을 찍은 다음,
charts.py 가 만든 벡터 차트 페이지를 위에 겹친다.

debug=True 로 부르면 모든 플레이스홀더 위치에 마젠타 십자와 키 이름을 찍는다.
좌표 검증용이며, 실제 산출물에서는 반드시 False.
"""

from __future__ import annotations

import io
import json
import os
from typing import Optional

from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

from . import charts
from .metrics import ReportMetrics

# reportlab 은 CFF(포스트스크립트 아웃라인) OTF/TTC 를 임베드하지 못한다.
# 시스템 Noto Sans CJK 는 CFF 라 쓸 수 없어 TrueType 한글 폰트를 동봉한다.
# 앱(Dart)으로 이식할 때는 프로젝트에서 쓰는 폰트로 교체할 것.
FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", "assets", "fonts")
KR_REG_TTF = os.path.join(FONT_DIR, "NanumGothic-Regular.ttf")
KR_BOLD_TTF = os.path.join(FONT_DIR, "NanumGothic-Bold.ttf")

FONT_REG = "KR"
FONT_BOLD = "KR-Bold"

_VERDICT_COLOR = {
    "green": "judge_green",
    "red": "judge_red",
    "unknown": "judge_unknown",   # 값 미확정 -> 회색
    "none": None,                 # 기준 없음 -> 원 없음
}


def register_fonts() -> None:
    if FONT_REG in pdfmetrics.getRegisteredFontNames():
        return
    pdfmetrics.registerFont(TTFont(FONT_REG, KR_REG_TTF))
    pdfmetrics.registerFont(TTFont(FONT_BOLD, KR_BOLD_TTF))


class ReportRenderer:
    def __init__(self, layout_path: str, debug: bool = False):
        with open(layout_path, encoding="utf-8") as fh:
            self.L = json.load(fh)
        self.root = os.path.dirname(os.path.abspath(layout_path))
        self.debug = debug
        self.W = self.L["page"]["width_pt"]
        self.H = self.L["page"]["height_pt"]
        # 서식 비율이 A4 와 미세하게 달라 축별 계수를 쓴다. 배경을 A4 전면에
        # 늘려 깔기 때문에 좌표도 같은 배율을 따라가야 한다.
        self.kx = self.L["page"]["pt_per_px_x"]
        self.ky = self.L["page"]["pt_per_px_y"]
        self.k = self.kx          # 글자 크기 등 길이 환산용
        register_fonts()

    # ---------------------------------------------------------- 좌표 변환

    def px(self, v: float) -> float:
        return v * self.k

    def xy(self, x_px: float, y_px: float) -> tuple[float, float]:
        """템플릿 픽셀(좌상단 원점) -> PDF 포인트(좌하단 원점)."""
        return x_px * self.kx, self.H - y_px * self.ky

    def color(self, name: str) -> HexColor:
        return HexColor(self.L["colors"].get(name, name))

    # ---------------------------------------------------------- 프리미티브

    def _text(self, c, x_px, y_px, text, size_px, align="left",
              weight="regular", color="text", key=None):
        if text is None:
            text = ""
        x, y = self.xy(x_px, y_px)
        size = self.px(size_px)
        font = FONT_BOLD if weight == "bold" else FONT_REG
        c.setFont(font, size)
        c.setFillColor(self.color(color))
        # y 는 텍스트의 수직 중심이므로 baseline 으로 내린다
        y -= size * 0.36
        if align == "right":
            c.drawRightString(x, y, str(text))
        elif align == "center":
            c.drawCentredString(x, y, str(text))
        else:
            c.drawString(x, y, str(text))
        if self.debug:
            self._debug_mark(c, x_px, y_px, key or str(text)[:14])

    def _dot(self, c, cx_px, cy_px, d_px, color_name):
        cx, cy = self.xy(cx_px, cy_px)
        r = self.px(d_px) / 2.0
        c.setFillColor(self.color(color_name))
        c.setStrokeColor(self.color(color_name))
        c.circle(cx, cy, r, stroke=0, fill=1)

    def _debug_mark(self, c, x_px, y_px, label):
        x, y = self.xy(x_px, y_px)
        c.saveState()
        c.setStrokeColor(HexColor("#FF00AA"))
        c.setLineWidth(0.3)
        c.line(x - 4, y, x + 4, y)
        c.line(x, y - 4, x, y + 4)
        c.setFont(FONT_REG, 3.6)
        c.setFillColor(HexColor("#FF00AA"))
        c.drawString(x + 5, y + 1.5, label)
        c.restoreState()

    def _background(self, c, rel_path):
        img = ImageReader(os.path.join(self.root, rel_path))
        c.drawImage(img, 0, 0, width=self.W, height=self.H,
                    preserveAspectRatio=False, mask=None)

    # ---------------------------------------------------------- 페이지 1

    def draw_page1(self, c, meta: dict, rm: ReportMetrics):
        P = self.L["page1"]
        self._background(c, P["background"])

        for f in P["fields"]:
            self._text(c, f["x"], f["y"], meta.get(f["key"], ""), f["size"],
                       f.get("align", "left"), f.get("weight", "regular"),
                       f.get("color", "text"), key=f["key"])

        mt = P["metrics_table"]
        col = mt["col"]
        vsize = mt.get("value_size", 28)
        tsize = mt.get("threshold_size", 28)
        stripes = mt.get("stripes", ["stripe_odd", "stripe_even"])
        for ri, row in enumerate(mt["rows"]):
            m = rm[row["key"]]
            y = row["y"]
            stripe = stripes[ri % 2]

            # 템플릿 1행에 지워지다 만 원이 흐리게 남아 있다. 먼저 덮는다.
            d = mt["dot"]["diameter"]
            self._erase(c, mt["dot"]["cx"] - d, y - d, d * 2, d * 2, stripe)
            dot_color = _VERDICT_COLOR.get(m.verdict)
            if dot_color:
                self._dot(c, mt["dot"]["cx"], y, d, dot_color)

            x_val = col["value"] if row["has_label"] else col["value_no_label"]
            self._text(c, x_val, y, m.format_value(), vsize, "left", "regular",
                       "text", key=row["key"])

            # 황색/적색 임계값. 적색은 템플릿에 남아 있으나 기준이 바뀔 수 있어
            # 코드에서 덮어쓴다. 덮기 전에 흰 박스로 지운다.
            # 템플릿에는 적색 컬럼 전체와 마지막 두 행의 황색 "0" 이 찍혀 있다.
            # 요구사항에 황색 단계가 없으므로 황색은 덮고 비운다. 적색은 기준이
            # 있는 행만 다시 찍는다.
            er = mt.get("erase_red", {"w": 150, "h": 46})
            for colname in ("yellow", "red"):
                cx = col[colname]
                self._erase(c, cx - er["w"] / 2, y - er["h"] / 2,
                            er["w"], er["h"], stripe)
            self._text(c, col["red"], y, m.format_red(), tsize, "center",
                       "regular", "text", key=f"{row['key']}.red")

        at = P["analysis_table"]
        asize = at.get("description_size", 28)
        astripes = at.get("stripes", ["stripe_odd", "stripe_even"])
        for ri, row in enumerate(at["rows"]):
            desc = rm.analysis.get(row["key"], "")
            # 7개 진단 항목은 요구사항에 없고 앱이 판정할 근거도 없다.
            # 녹색으로 찍으면 "이상 없음"을 확인한 것처럼 읽히므로 회색으로 둔다.
            d = at["dot"]["diameter"]
            self._erase(c, at["dot"]["cx"] - d, row["y"] - d, d * 2, d * 2,
                        astripes[ri % 2])
            self._dot(c, at["dot"]["cx"], row["y"], d, "judge_unknown")
            if desc:
                self._text(c, at["col"]["description"], row["y"], desc, asize,
                           "left", "regular", "text", key=row["key"])
            elif self.debug:
                self._debug_mark(c, at["col"]["description"], row["y"], row["key"])

    def _erase(self, c, x_px, y_px, w_px, h_px, stripe):
        """템플릿에 박힌 값을 덮는다. 표 줄무늬 색으로 칠해야 티가 안 난다."""
        x, y = self.xy(x_px, y_px + h_px)
        c.saveState()
        c.setFillColor(self.color(stripe))
        c.rect(x, y, self.px(w_px), self.px(h_px), stroke=0, fill=1)
        c.restoreState()

    # ---------------------------------------------------------- 차트 페이지

    def draw_chart_page(self, c, meta: dict, page_number: int):
        P = self.L["chart_page"]
        self._background(c, P["background"])
        t = P["title"]
        self._text(c, t["x"], t["y"], "데이터 차트", t["size"], t["align"],
                   t.get("weight", "regular"), t["color"], key="title")
        vals = dict(meta)
        vals["page_number"] = str(page_number)
        for f in P["fields"]:
            self._text(c, f["x"], f["y"], vals.get(f["key"], ""), f["size"],
                       f.get("align", "left"), f.get("weight", "regular"),
                       f.get("color", "text"), key=f["key"])
        if self.debug:
            for slot in P["slots"]:
                b = slot["plot_box"]
                x, y = self.xy(b["x"], b["y"] + b["h"])
                c.saveState()
                c.setStrokeColor(HexColor("#FF00AA"))
                c.setLineWidth(0.4)
                c.rect(x, y, self.px(b["w"]), self.px(b["h"]), stroke=1, fill=0)
                c.restoreState()

    # ---------------------------------------------------------- 조립

    def build(self, out_path: str, meta: dict, rm: ReportMetrics,
              signals=None) -> str:
        buf = io.BytesIO()
        c = canvas.Canvas(buf, pagesize=(self.W, self.H))

        self.draw_page1(c, meta, rm)
        c.showPage()
        self.draw_chart_page(c, meta, 2)
        c.showPage()
        self.draw_chart_page(c, meta, 3)
        c.showPage()
        c.save()
        buf.seek(0)

        base = PdfReader(buf)
        writer = PdfWriter()
        writer.add_page(base.pages[0])

        if signals is not None:
            slots = self.L["chart_page"]["slots"]
            p2 = charts.render_chart_page(
                "/tmp/_charts_p2.pdf", signals.t,
                {"x": signals.x, "y": signals.y, "z": signals.z,
                 "noise": signals.noise},
                charts.PAGE2_CHANNELS, slots)
            p3 = charts.render_chart_page(
                "/tmp/_charts_p3.pdf", signals.t,
                {"pos": signals.position, "vel": signals.velocity,
                 "acc": signals.accel, "jerk": signals.jerk},
                charts.PAGE3_CHANNELS, slots)
            for idx, chart_pdf in ((1, p2), (2, p3)):
                page = base.pages[idx]
                overlay = PdfReader(chart_pdf).pages[0]
                page.merge_page(overlay)
                writer.add_page(page)
        else:
            writer.add_page(base.pages[1])
            writer.add_page(base.pages[2])

        with open(out_path, "wb") as fh:
            writer.write(fh)
        return out_path


def _fmt_threshold(v: float) -> str:
    if v is None:
        return ""
    return f"{v:g}"
