"""Generate docs/prd/PRD.md (+ docs/prd/figures/) from the canonical PRD docx.

The docx stays the source of truth. Never edit PRD.md by hand: edit the docx, then run

    python tools/prd_to_md.py

and commit the docx, the re-exported pdf and the regenerated PRD.md together (sync rule in CLAUDE.md).
"""

import re
import sys
from pathlib import Path

import docx
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "prd" / "PRD_Kelompok5_Jelajah_Taman.docx"
OUT = ROOT / "docs" / "prd" / "PRD.md"
FIG_DIR = ROOT / "docs" / "prd" / "figures"

doc = docx.Document(SRC)
FIG_DIR.mkdir(parents=True, exist_ok=True)
for old in FIG_DIR.glob("prd_fig_*"):
    old.unlink()

lines: list[str] = []
fig_no = 0


def md_escape(text: str) -> str:
    # Escape characters that would start unintended markdown (keep it readable otherwise).
    return text.replace("*", r"\*").replace("_", r"\_")


def inline(p: Paragraph) -> str:
    """Paragraph text with bold runs as **bold** (adjacent bold runs merged)."""
    parts: list[tuple[bool, str]] = []
    for r in p.runs:
        if not r.text:
            continue
        bold = bool(r.bold)
        if parts and parts[-1][0] == bold:
            parts[-1] = (bold, parts[-1][1] + r.text)
        else:
            parts.append((bold, r.text))
    out = []
    for bold, text in parts:
        t = md_escape(text)
        if bold and t.strip():
            lead = t[: len(t) - len(t.lstrip())]
            trail = t[len(t.rstrip()):]
            out.append(f"{lead}**{t.strip()}**{trail}")
        else:
            out.append(t)
    return "".join(out).strip()


def is_code(p: Paragraph) -> bool:
    fonts = {r.font.name for r in p.runs if r.text.strip()}
    return bool(fonts) and fonts <= {"Consolas", "Courier New"}


def images_in(p: Paragraph) -> list[str]:
    global fig_no
    paths = []
    for blip in p._p.iter(qn("a:blip")):
        rid = blip.get(qn("r:embed"))
        part = doc.part.related_parts.get(rid)
        if part is None:
            continue
        fig_no += 1
        ext = Path(part.partname).suffix or ".png"
        name = f"prd_fig_{fig_no:02d}{ext}"
        (FIG_DIR / name).write_bytes(part.blob)
        paths.append(f"figures/{name}")
    return paths


def cell_text(cell) -> str:
    texts = [inline(p) for p in cell.paragraphs if p.text.strip()]
    return "<br>".join(texts).replace("|", r"\|")


def table_md(t: Table) -> list[str]:
    rows = []
    for row in t.rows:
        seen, cells = set(), []
        for c in row.cells:
            if id(c._tc) in seen:
                continue
            seen.add(id(c._tc))
            cells.append(cell_text(c))
        rows.append(cells)
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    out = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * width]
    out += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return out + [""]


code_buffer: list[str] = []
before_first_heading = True
cover_line = 0


def flush_code():
    if code_buffer:
        lines.extend(["```json", *code_buffer, "```", ""])
        code_buffer.clear()


lines += [
    "<!-- GENERATED from docs/prd/PRD_Kelompok5_Jelajah_Taman.docx by tools/prd_to_md.py.",
    "     Do not edit by hand: edit the docx, then rerun the script. -->",
    "",
]

for el in doc.element.body.iterchildren():
    tag = el.tag.split("}")[1]
    if tag == "tbl":
        flush_code()
        lines += table_md(Table(el, doc))
        continue
    if tag != "p":
        continue
    p = Paragraph(el, doc)
    style = p.style.name if p.style is not None else ""

    imgs = images_in(p)
    if imgs:
        flush_code()
        for path in imgs:
            lines += [f"![]({path})", ""]
    if not p.text.strip():
        continue
    if is_code(p):
        code_buffer.append(p.text)
        continue
    flush_code()

    text = inline(p)
    if style == "Heading 1":
        before_first_heading = False
        lines += [f"## {p.text.strip()}", ""]
    elif style == "Heading 2":
        lines += [f"### {p.text.strip()}", ""]
    elif before_first_heading:
        cover_line += 1
        lines += [f"# {p.text.strip()}" if cover_line == 1 else f"**{p.text.strip()}**", ""]
    elif re.match(r"^Gambar \d", p.text.strip()):
        lines += [f"*{p.text.strip()}*", ""]
    else:
        lines += [text, ""]

flush_code()
OUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8", newline="\n")  # LF on every OS (CI diff)
print(f"wrote {OUT.relative_to(ROOT)} ({len(lines)} lines, {fig_no} figures)")
sys.exit(0)
