"""작업자 명단 엑셀을 앱 자산(assets/workers/workers.json)으로 바꾼다.

OTIS 가 준 "설치 업체 List_YYMMDD.xlsx" 의 첫 시트를 읽는다. 열 차례는
사번 · 성명 · 업체명 · 관리팀이다. 앱은 이 JSON 만 읽고 엑셀은 저장소에
두지 않는다(.gitignore). 명단이 바뀌면 이 스크립트를 다시 돌려 JSON 을
갈아 끼우고 앱을 새로 빌드한다.

    python tool/import_workers.py "설치 업체 List_261012.xlsx" assets/workers/workers.json

openpyxl 이 필요하다(아나콘다 기본 포함).
"""

import json
import sys
from pathlib import Path

import openpyxl

# 머리줄 열 이름. 엑셀이 셀 안 줄바꿈을 "_x000D_\n" 로 남긴 칸이 있어
# 앞부분만 대조한다
EXPECTED_HEADER = ("사번", "성명", "업체명", "관리팀")


def clean(value):
    """셀 값을 앞뒤 공백 · 엑셀 줄바꿈 표시 없는 문자열로 바꾼다. 빈 칸은 None."""
    if value is None:
        return None
    text = str(value).replace("_x000D_", "").strip()
    return text or None


def main(src, dst):
    sheet = openpyxl.load_workbook(src, read_only=True, data_only=True).worksheets[0]
    rows = sheet.iter_rows(values_only=True)
    header = tuple(clean(v) for v in next(rows)[:4])
    if header != EXPECTED_HEADER:
        sys.exit(f"머리줄이 {EXPECTED_HEADER} 가 아니다: {header}")

    workers = []
    seen = set()
    for line, row in enumerate(rows, start=2):
        employee_id, name, company, team = (clean(v) for v in row[:4])
        if employee_id is None and name is None:
            continue  # 끝의 빈 줄
        if employee_id is None or name is None:
            sys.exit(f"{line}행: 사번 · 성명 중 빈 칸이 있다: {row}")
        # 앱은 사번을 대문자로 맞춰 대조한다(worker_directory.dart)
        employee_id = employee_id.upper()
        if employee_id in seen:
            sys.exit(f"{line}행: 사번 {employee_id} 가 겹친다")
        seen.add(employee_id)
        workers.append(
            {"id": employee_id, "name": name, "company": company, "team": team}
        )

    # 작업자 한 명을 한 줄에 둔다. 명단이 바뀌었을 때 git diff 가 사람
    # 단위로 보인다
    lines = [json.dumps(w, ensure_ascii=False) for w in workers]
    source = json.dumps(Path(src).name, ensure_ascii=False)
    text = '{"source": ' + source + ', "workers": [\n'
    text += ",\n".join(lines) + "\n]}\n"
    json.loads(text)  # 손으로 이은 문자열이 올바른 JSON 인지 확인
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    Path(dst).write_text(text, encoding="utf-8")
    print(f"{len(workers)}명 → {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
