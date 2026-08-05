"""회의용 PPT — 핵심 코드 4개 + 간단 설명"""

from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Inches, Pt

OUT = Path("docs") / "회의자료_원시센서데이터_v5.pptx"

NAVY = RGBColor(0x1F, 0x38, 0x64)
GRAY = RGBColor(0x33, 0x33, 0x33)
SUB = RGBColor(0x55, 0x55, 0x55)
CODE_BG = RGBColor(0xF4, 0xF6, 0xF8)


def set_run(run, size=18, bold=False, color=GRAY):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    run.font.name = "맑은 고딕"


def add_title_slide(prs, title, subtitle):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    box = slide.shapes.add_textbox(Inches(0.7), Inches(2.2), Inches(8.6), Inches(1.2))
    tf = box.text_frame
    p = tf.paragraphs[0]
    p.text = title
    set_run(p.runs[0], 32, True, NAVY)

    box2 = slide.shapes.add_textbox(Inches(0.7), Inches(3.5), Inches(8.6), Inches(1.5))
    tf2 = box2.text_frame
    tf2.word_wrap = True
    for i, line in enumerate(subtitle.split("\n")):
        para = tf2.paragraphs[0] if i == 0 else tf2.add_paragraph()
        para.text = line if line else " "
        if para.runs:
            set_run(para.runs[0], 16, False, SUB)
    return slide


def add_bullets_slide(prs, title, bullets, footer=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    tbox = slide.shapes.add_textbox(Inches(0.6), Inches(0.35), Inches(8.8), Inches(0.7))
    tp = tbox.text_frame.paragraphs[0]
    tp.text = title
    set_run(tp.runs[0], 26, True, NAVY)

    body = slide.shapes.add_textbox(Inches(0.7), Inches(1.2), Inches(8.6), Inches(5.5))
    tf = body.text_frame
    tf.word_wrap = True
    for i, b in enumerate(bullets):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        para.text = f"• {b}"
        para.space_after = Pt(8)
        set_run(para.runs[0], 17, False, GRAY)

    if footer:
        fbox = slide.shapes.add_textbox(Inches(0.7), Inches(6.7), Inches(8.6), Inches(0.4))
        fp = fbox.text_frame.paragraphs[0]
        fp.text = footer
        set_run(fp.runs[0], 12, False, SUB)
    return slide


def add_code_slide(prs, title, why, code_lines, footer=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    tbox = slide.shapes.add_textbox(Inches(0.6), Inches(0.3), Inches(8.8), Inches(0.55))
    tp = tbox.text_frame.paragraphs[0]
    tp.text = title
    set_run(tp.runs[0], 22, True, NAVY)

    wbox = slide.shapes.add_textbox(Inches(0.6), Inches(0.9), Inches(8.8), Inches(0.7))
    wp = wbox.text_frame.paragraphs[0]
    wp.text = why
    wbox.text_frame.word_wrap = True
    if wp.runs:
        set_run(wp.runs[0], 14, False, SUB)

    shape = slide.shapes.add_shape(1, Inches(0.55), Inches(1.65), Inches(8.9), Inches(4.8))
    shape.fill.solid()
    shape.fill.fore_color.rgb = CODE_BG
    shape.line.color.rgb = RGBColor(0xD0, 0xD0, 0xD0)

    cbox = slide.shapes.add_textbox(Inches(0.75), Inches(1.8), Inches(8.5), Inches(4.5))
    tf = cbox.text_frame
    tf.word_wrap = True
    for i, line in enumerate(code_lines):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        para.text = line if line else " "
        para.space_after = Pt(2)
        if para.runs:
            set_run(para.runs[0], 12, False, GRAY)
            para.runs[0].font.name = "Consolas"

    if footer:
        fbox = slide.shapes.add_textbox(Inches(0.7), Inches(6.65), Inches(8.6), Inches(0.4))
        fp = fbox.text_frame.paragraphs[0]
        fp.text = footer
        set_run(fp.runs[0], 12, False, SUB)
    return slide


def main():
    prs = Presentation()
    prs.slide_width = Inches(10)
    prs.slide_height = Inches(7.5)

    add_title_slide(
        prs,
        "OTIS 센서 원본(raw) — 핵심 코드",
        "Galaxy S22 측정\n"
        "수집 → 저장 → motion → 적분",
    )

    add_bullets_slide(
        prs,
        "1. raw.txt 구성",
        [
            "S22 센서가 1초에 256번 찍은 기록 파일",
            "한 줄 = 시간 + linear + 소음 + raw + gravity",
            "linear → 진동 계산용 / raw·gravity → 거리·속도 계산용",
            "※ 거리(m), 속도(m/s)는 파일에 없음 → 앱이 계산",
        ],
        footer="raw_summary.txt = 위 파일의 통계 요약본",
    )

    add_code_slide(
        prs,
        "2. 수집 코드 — SensorStreamHandler.kt",
        "설명: S22에서 raw·gravity·linear·소음을 1초에 256번 읽어 앱으로 보냄",
        [
            "when (event.sensor.type) {",
            "  TYPE_ACCELEROMETER ->",
            "      rawSample.push(ts, x, y, z)       // raw",
            "  TYPE_GRAVITY ->",
            "      gravitySample.push(ts, x, y, z)   // gravity",
            "  TYPE_LINEAR_ACCELERATION ->",
            "      linearSample.push(ts, x, y, z)    // linear",
            "      // linear 시각 기준 256Hz 리샘플",
            "}",
            "",
            "// Flutter로 전달:",
            "// tsUs, linearX/Y/Z, rawX/Y/Z,",
            "// gravityX/Y/Z, noiseDba",
        ],
        footer="파일: android/.../SensorStreamHandler.kt",
    )

    add_code_slide(
        prs,
        "3. 저장 코드 — parse_raw.dart",
        "설명: 측정이 끝나면 센서 기록 전체를 raw.txt 파일로 저장",
        [
            "// EVIMP1 형식",
            "EVIMP1",
            "256",
            "# tsUs linearX Y Z noise rawX Y Z gravityX Y Z",
            "",
            "for (final s in samples) {",
            "  write(s.tsUs, s.x, s.y, s.z, s.noiseDba,",
            "        s.rawX, s.rawY, s.rawZ,",
            "        s.gravityX, s.gravityY, s.gravityZ);",
            "}",
        ],
        footer="파일: lib/domain/parse_raw.dart, measurement_repository.dart",
    )

    add_bullets_slide(
        prs,
        "4. motion — 왜 gravity를 빼나?",
        [
            "raw = 중력 + 엘리베이터 움직임 (합쳐진 값)",
            "gravity = Android가 '중력만' 추정한 값 (우리가 정하는 숫자 아님)",
            "motion = raw − gravity → 중력 빼고 움직임만 남김",
            "가만히 있을 때: raw ≈ gravity → motion ≈ 0",
            "motion을 적분해야 거리·속도가 나옴",
        ],
        footer="gravity Z ≈ 1000mg (1g) — 휴대폰 세워두었을 때",
    )

    add_code_slide(
        prs,
        "5. motion 코드 — sensor_sample.dart",
        "설명: 매 순간 raw에서 gravity를 빼서 motion(실제 움직임)을 만듦",
        [
            "double get motionX =>",
            "    rawX != null && gravityX != null",
            "        ? rawX! - gravityX!",
            "        : x;",
            "",
            "double get motionY => rawY! - gravityY!;  // Y도 동일",
            "double get motionZ => rawZ! - gravityZ!;  // Z도 동일",
            "",
            "// motion = raw - gravity",
            "// 거리·속도는 motionZ를 적분해서 계산",
        ],
        footer="파일: lib/domain/measure/sensor_sample.dart",
    )

    add_code_slide(
        prs,
        "6. 적분 코드 — motion_integrator.dart",
        "설명: motionZ(움직임)를 두 번 적분 → 속도 → 거리",
        [
            "// 1) mg → m/s²",
            "accel[i] = motionZ[i] * 0.00980665;",
            "",
            "// 2) 속도 적분",
            "speed[i] = speed[i-1] + accel[i] * dt;",
            "maxSpeed = max(|speed|);",
            "",
            "// 3) 거리 적분",
            "pos[i] = pos[i-1] + speed[i] * dt;",
            "distance = |pos[last]|;",
        ],
        footer="파일: lib/domain/measure/motion_integrator.dart",
    )

    add_bullets_slide(
        prs,
        "7. 전체 흐름",
        [
            "① S22 센서 수집 (256Hz) → raw·gravity·linear",
            "② raw.txt 저장",
            "③ motion = raw − gravity",
            "④ motionZ 적분 → 속도·거리",
            "⑤ 진동 X/Y/Z는 linear로 따로 계산 (적분과 별개)",
        ],
    )

    add_title_slide(
        prs,
        "정리",
        "raw.txt = 센서 원본\n"
        "motion = raw − gravity\n"
        "거리·속도 = motion 적분",
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    prs.save(OUT)
    print(f"Wrote {OUT.resolve()}")


if __name__ == "__main__":
    main()
