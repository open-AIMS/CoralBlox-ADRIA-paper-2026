#!/usr/bin/env python3
"""Generate style-reference.docx: Pandoc's default Word styles, restyled for Science Advances.

This is the `reference-doc` for paper.qmd and variable_list.qmd (named to avoid confusion
with references.bib, which is unrelated). Pandoc's built-in template renders the title in
Aptos Display 28pt. The journal templates cannot be used directly as `reference-doc`
because they define none of the style names Pandoc writes to (Title, Author, Heading 1,
Body Text, ...), so we patch Pandoc's own template instead.

Usage:  python paper/style/make-style-reference.py
"""

import re
import shutil
import subprocess
import zipfile
from pathlib import Path

OUT = Path(__file__).parent / "style-reference.docx"

FONT = "Times New Roman"
PT = 2  # Word stores font sizes in half-points

# Page setup measured from advances_ms_template_2022.docx (twips; 1440 = 1 inch)
PG_SZ = 'w:w="12240" w:h="15840"'
PG_MAR = ('w:top="994" w:right="1987" w:bottom="806" w:left="806" '
          'w:header="432" w:footer="259" w:gutter="0"')
LN_NUM = 'w:countBy="1" w:restart="continuous"'

# Body paragraphs carry a 0.5" first-line indent, matching the journal template's
# "Paragraph" style. Headings and the first paragraph after one stay flush left.
FIRST_LINE_INDENT = 720

# styleId -> (size_pt, bold, italic). None leaves the existing value alone.
# Heading levels follow Science's stated scheme: bold / bold-italic / italic.
STYLES = {
    # The journal template sets the title at 12pt bold, identical to the author line.
    # 14pt keeps the hierarchy readable and stays within "no required format for initial
    # submission"; set back to 12 for a template-faithful version.
    "Title": (14, True, False),
    "TitleChar": (14, True, False),
    "Subtitle": (12, False, True),
    "SubtitleChar": (12, False, True),
    "Author": (12, False, False),
    "Date": (12, False, False),
    "Abstract": (12, False, False),
    "AbstractTitle": (12, True, False),
    "Heading1": (12, True, False),
    "Heading1Char": (12, True, False),
    "Heading2": (12, True, True),
    "Heading2Char": (12, True, True),
    "Heading3": (12, False, True),
    "Heading3Char": (12, False, True),
    "Heading4": (12, False, True),
    "Heading4Char": (12, False, True),
    "Bibliography": (12, False, False),
    "Caption": (12, False, False),
    "ImageCaption": (12, False, False),
    "TableCaption": (12, False, False),
    "BodyText": (12, False, False),
    "FirstParagraph": (12, False, False),
    "Compact": (12, False, False),
}

RFONTS = f'<w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}" w:cs="{FONT}"/>'

# Word renders line numbers in the "line number" character style, which inherits Normal.
# Pandoc's template has no such style, so they would come out at the 12pt body size; the
# journal template leaves Normal unsized and so gets Word's smaller default.
LINE_NUMBER_STYLE = (
    '<w:style w:type="character" w:styleId="LineNumber">'
    '<w:name w:val="line number"/>'
    '<w:basedOn w:val="DefaultParagraphFont"/>'
    f'<w:rPr>{RFONTS}<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>'
    "</w:style>"
)


def set_rpr(block: str, size, bold, italic) -> str:
    m = re.search(r"(?s)<w:rPr>.*?</w:rPr>", block)
    if m:
        rpr = m.group(0)
        inner = rpr[len("<w:rPr>"):-len("</w:rPr>")]
        inner = re.sub(r"(?s)<w:rFonts[^>]*/>", "", inner)
        inner = re.sub(r"(?s)<w:sz[^>]*/>|<w:szCs[^>]*/>", "", inner)
        inner = re.sub(r"(?s)<w:b\s*/>|<w:bCs\s*/>", "", inner)
        inner = re.sub(r"(?s)<w:i\s*/>|<w:iCs\s*/>", "", inner)
    else:
        rpr, inner = None, ""

    new = RFONTS
    if bold:
        new += "<w:b/>"
    if italic:
        new += "<w:i/>"
    if size is not None:
        new += f'<w:sz w:val="{size * PT}"/><w:szCs w:val="{size * PT}"/>'
    new = f"<w:rPr>{new}{inner}</w:rPr>"

    if rpr:
        return block.replace(rpr, new, 1)
    if "</w:pPr>" in block:
        return block.replace("</w:pPr>", "</w:pPr>" + new, 1)
    return block + new


def patch_styles(xml: str) -> str:
    # Document-wide default: explicit Times New Roman 12pt, single spacing.
    xml = re.sub(
        r"(?s)(<w:rPrDefault>\s*<w:rPr>)<w:rFonts[^>]*/>",
        r"\1" + RFONTS,
        xml,
        count=1,
    )
    xml = re.sub(
        r'(?s)(<w:pPrDefault>\s*<w:pPr>)<w:spacing[^>]*/>',
        r'\1<w:spacing w:after="200" w:line="240" w:lineRule="auto"/>',
        xml,
        count=1,
    )

    for sid, (size, bold, italic) in STYLES.items():
        pat = re.compile(
            r'(?s)(<w:style [^>]*w:styleId="' + re.escape(sid) + r'"[^>]*>)(.*?)(</w:style>)'
        )
        m = pat.search(xml)
        if not m:
            print(f"  ! style not found, skipped: {sid}")
            continue
        xml = xml[: m.start()] + m.group(1) + set_rpr(m.group(2), size, bold, italic) + m.group(3) + xml[m.end():]

    def set_ind(style_id, twips):
        nonlocal xml
        pat = re.compile(r'(?s)(<w:style [^>]*w:styleId="' + style_id + r'"[^>]*>)(.*?)(</w:style>)')
        m = pat.search(xml)
        if not m:
            return
        body = re.sub(r"(?s)<w:ind[^>]*/>", "", m.group(2))
        ind = f'<w:ind w:firstLine="{twips}"/>'
        if "<w:pPr>" in body:
            body = body.replace("<w:pPr>", "<w:pPr>" + ind, 1)
        else:
            body = "<w:pPr>" + ind + "</w:pPr>" + body
        xml = xml[: m.start()] + m.group(1) + body + m.group(3) + xml[m.end():]

    set_ind("BodyText", FIRST_LINE_INDENT)
    # Compact is what Pandoc puts inside table cells and tight lists. It inherits from
    # BodyText, and a 0.5" first line indent inside a 0.5"-wide cell pushes the text out
    # of view, so it must opt out explicitly.
    set_ind("Compact", 0)
    # FirstParagraph also inherits BodyText. Typographically the first paragraph after a
    # heading is not indented, and the affiliations arrive as one paragraph split by line
    # breaks -- so an indent here would offset only the first affiliation.
    set_ind("FirstParagraph", 0)
    print(f"  BodyText first-line indent: {FIRST_LINE_INDENT} twips (Compact/FirstParagraph: 0)")

    # Vertically centre table cell content so equation numbers line up with the equation.
    # Pandoc's template colours headings with the Office theme accent (dark blue) and
    # links blue; a submitted manuscript should be entirely black.
    black = [f"Heading{i}" for i in range(1, 10)]
    black += [f"Heading{i}Char" for i in range(1, 10)]
    black += ["Title", "TitleChar", "Subtitle", "SubtitleChar",
              "TOCHeading", "Hyperlink", "FollowedHyperlink"]
    recoloured = 0
    for sid in black:
        pat = re.compile(r'(?s)(<w:style [^>]*w:styleId="' + sid + r'"[^>]*>)(.*?)(</w:style>)')
        m = pat.search(xml)
        if not m or "<w:color" not in m.group(2):
            continue
        body = re.sub(r"(?s)<w:color[^>]*/>", '<w:color w:val="000000"/>', m.group(2))
        xml = xml[: m.start()] + m.group(1) + body + m.group(3) + xml[m.end():]
        recoloured += 1
    print(f"  recoloured to black: {recoloured} styles")

    # Centre figures. These styles inherit BodyText, so they also need the first-line
    # indent cleared or the image sits 0.5" off-centre.
    for sid in ("Figure", "CaptionedFigure"):
        pat = re.compile(r'(?s)(<w:style [^>]*w:styleId="' + sid + r'"[^>]*>)(.*?)(</w:style>)')
        m = pat.search(xml)
        if not m:
            continue
        body = re.sub(r"(?s)<w:ind[^>]*/>|<w:jc[^>]*/>", "", m.group(2))
        props = '<w:ind w:firstLine="0"/><w:jc w:val="center"/>'
        if "<w:pPr>" in body:
            body = body.replace("<w:pPr>", "<w:pPr>" + props, 1)
        else:
            body = "<w:pPr>" + props + "</w:pPr>" + body
        xml = xml[: m.start()] + m.group(1) + body + m.group(3) + xml[m.end():]
        print(f"  {sid}: centred")

    # The style already carries a <w:vAlign> inside its conditional <w:tblStylePr> blocks,
    # so insert into the style's own <w:tcPr>, before the first conditional block.
    pat = re.compile(r'(?s)(<w:style [^>]*w:styleId="Table"[^>]*>)(.*?)(</w:style>)')
    m = pat.search(xml)
    body = m.group(2)
    valign = '<w:tcPr><w:vAlign w:val="center"/></w:tcPr>'
    anchor = body.find("<w:tblStylePr")
    body = (body[:anchor] + valign + body[anchor:]) if anchor != -1 else body + valign
    xml = xml[: m.start()] + m.group(1) + body + m.group(3) + xml[m.end():]
    print("  Table style: cell vertical alignment centre")

    if 'w:styleId="LineNumber"' not in xml:
        xml = xml.replace("</w:styles>", LINE_NUMBER_STYLE + "</w:styles>", 1)
        print("  added LineNumber style (9pt)")
    return xml


def patch_theme(xml: str) -> str:
    for slot in ("majorFont", "minorFont"):
        xml = re.sub(
            r'(?s)(<a:' + slot + r'>\s*<a:latin typeface=")[^"]*"',
            r'\g<1>' + FONT + '"',
            xml,
            count=1,
        )
    return xml


def patch_document(xml: str) -> str:
    sect = (
        "<w:sectPr>"
        "<w:footnotePr><w:numRestart w:val=\"eachSect\"/></w:footnotePr>"
        f"<w:pgSz {PG_SZ}/>"
        f"<w:pgMar {PG_MAR}/>"
        f"<w:lnNumType {LN_NUM}/>"
        "<w:cols w:space=\"720\"/>"
        "</w:sectPr>"
    )
    return re.sub(r"(?s)<w:sectPr>.*?</w:sectPr>", sect, xml, count=1)


PATCHES = {
    "word/styles.xml": patch_styles,
    "word/theme/theme1.xml": patch_theme,
    "word/document.xml": patch_document,
}


def main() -> None:
    base = OUT.with_suffix(".base.docx")
    with base.open("wb") as fh:
        # "reference.docx" here is Pandoc's own bundled data file, not our output.
        subprocess.run(
            ["quarto", "pandoc", "--print-default-data-file", "reference.docx"],
            stdout=fh,
            check=True,
        )

    src = zipfile.ZipFile(base)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item.filename)
            fn = PATCHES.get(item.filename)
            if fn:
                data = fn(data.decode("utf-8")).encode("utf-8")
                print(f"  patched {item.filename}")
            dst.writestr(item, data)
    src.close()
    base.unlink()
    print(f"\nWrote {OUT}")


if __name__ == "__main__":
    main()
