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

`paper.qmd` uses Quarto's native Julia engine (`engine: julia`), executing code cells against
this repo's own `Project.toml`/`Manifest.toml` (`exeflags: ["--project=."]`) — no extra Julia
packages are required beyond what the plotting scripts already use. Quarto manages its own
Julia notebook-runner environment separately and bootstraps it automatically the first time
you render.
