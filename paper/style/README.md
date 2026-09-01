# Manuscript Word styling

`style-reference.docx` is the Pandoc **`reference-doc`** for `paper.qmd` and
`variable_list.qmd` — a style donor, not content. When Quarto renders those documents to
`.docx`, Pandoc copies the named Word styles (`Title`, `Heading 1`, `Body Text`, `Image
Caption`, `Bibliography`, …) plus the page size, margins and section properties (line
numbering lives there) out of this file and applies them to the generated manuscript. It is
used **only** because each `.qmd` declares `reference-doc: style/style-reference.docx` in
its YAML (resolved relative to the `.qmd`); there is no magic by filename. Without it,
Pandoc falls back to its built-in default (Aptos Display 28 pt title, blue headings, no line
numbers) — not a submittable manuscript. This is unrelated to `references.bib`, which is the
bibliography.

`style-reference.docx` is generated: run `python paper/style/make-style-reference.py` to
rebuild it from Pandoc's default template restyled for Science Advances (Times New Roman
12 pt, journal margins, continuous line numbering, black headings). Edit the script, never
the `.docx`.
