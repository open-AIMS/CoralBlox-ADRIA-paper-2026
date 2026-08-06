# CoralBlox (2026) paper plots

This repo supports the paper "CoralBlox: A computationally efficient coral model for decision support". It contains the code to generate the manuscript (`paper/`) and all plots (`src/`).

Depends on `CoralBloxCalib` (dev'd from the `CoralBlox-params-calibration` repo) and reads
its `config.toml` for domain/dataset paths — see that repo's config for calibration output
locations (`out_dir`, `results.dat`, etc.).

## Structure

```
paper_plots_2026_coralblox/
├─ src/        # numbered plotting scripts, run via main.jl
├─ figures/    # generated figures
├─ paper/      # reproducible Quarto manuscript (paper.qmd), targeting Science Advances
├─ config.toml
├─ Project.toml
└─ Manifest.toml
```

## Rendering the paper

Requires [Quarto](https://quarto.org/docs/get-started/) installed in addition to Julia. From
the repo root:

```shell
quarto render paper/paper.qmd
```

or, while writing, for a live-reloading preview:

```shell
quarto preview paper/paper.qmd
```

### Word styling

Output styling comes from `paper/reference.docx` (`reference-doc:` in `paper.qmd`), which sets
Times New Roman 12 pt, Science Advances page margins, and continuous line numbering. It is
generated — regenerate it with:

```shell
python paper/make-reference-doc.py
```

The journal's own `.docx` templates cannot be used directly here: they define none of the style
names Pandoc writes to (`Title`, `Author`, `Heading 1`, ...), so the script patches Pandoc's
default template instead. Edit `make-reference-doc.py`, not the `.docx`.

### References

`paper/references.bib` holds the 81 cited entries, filtered out of a larger Zotero library
(`ADRIA-mod.bib`) during the migration from Word. It is now maintained directly — edit it by
hand. Citation formatting comes from `science-advances.csl`, a local fork of `science.csl` with
the in-text citation numbers de-italicised: *Science* uses `(1)` in italics, *Science Advances*
does not.

`paper/TO-FIX-zotero.md` lists corrections that were applied to the exported `.bib` but not to
the Zotero library itself — only relevant if the library is ever re-exported over these files.

`paper.qmd` uses Quarto's native Julia engine (`engine: julia`), executing code cells against
this repo's own `Project.toml`/`Manifest.toml` (`exeflags: ["--project=."]`) — no extra Julia
packages are required beyond what the plotting scripts already use. Quarto manages its own
Julia notebook-runner environment separately and bootstraps it automatically the first time
you render.
