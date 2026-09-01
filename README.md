# CoralBlox-ADRIA paper (2026)

This repo supports the paper "CoralBlox: A computationally efficient coral model for decision support". It contains the code to generate the manuscript (`paper/`) and all plots (`src/`).

Depends on `CoralBloxCalib` (from the
[`CoralBlox-params-calibration`](https://github.com/open-AIMS/CoralBlox-params-calibration)
repo) for its domain-loading and scoring helpers. Domain, dataset and calibration-product
paths are read from **this repo's own** `config.toml` (git-ignored — copy
`config.toml.example`), not the calibration repo's.

## Structure

```
CoralBlox-ADRIA-paper-2026/
├─ src/
│  ├─ main.jl                  # loads the calibrated domain, runs the model once, then
│  │                            # includes every figures/ script below
│  ├─ figures/                 # numbered plotting scripts (figure number in the manuscript),
│  │                            # writing figures/NN_*.png - run via main.jl
│  ├─ outcomes/                 # manual, not run via main.jl: computes the calibration/
│  │                            # performance metrics and single-run timing quoted inline in
│  │                            # paper.qmd, merging into outputs/manuscript_metrics_data.jl
│  └─ sensitivity_analysis/     # manual, not run via main.jl: runs the Shapley-effect global
│                                # sensitivity analysis and aggregates its results - see
│                                # "Sensitivity analysis" below
├─ figures/    # manuscript figures (committed); src/figures/ regenerates all but the two
│               # static images, 01_coralblox_processes.png and S01_reef_groups_map.png
├─ outputs/    # generated non-figure data (committed - e.g. manuscript_metrics_data.jl,
│               # sensitivity_analysis_shapley_effects.parq, sensitivity_analysis_convergence.parq)
├─ paper/      # reproducible Quarto manuscript (paper.qmd), targeting Science Advances
├─ config.toml.example  # copy to config.toml (git-ignored) and set local paths
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

Output styling comes from `paper/style/style-reference.docx` (`reference-doc:` in `paper.qmd`
and `variable_list.qmd`), which sets Times New Roman 12 pt, Science Advances page margins, and
continuous line numbering. It is generated — regenerate it with:

```shell
python paper/style/make-style-reference.py
```

The journal's own `.docx` templates cannot be used directly here: they define none of the style
names Pandoc writes to (`Title`, `Author`, `Heading 1`, ...), so the script patches Pandoc's
default template instead. Edit `make-style-reference.py`, not the `.docx`. See
`paper/style/README.md` for how the `reference-doc` mechanism works.

### References

`paper/references.bib` holds the cited entries. It is maintained directly — edit it by
hand. Citation formatting comes from `science-advances.csl`, a local fork of `science.csl` with the in-text citation numbers de-italicised: *Science* uses `(1)` in italics, *Science Advances* does not.

`paper.qmd` uses Quarto's native Julia engine (`engine: julia`), executing code cells against this repo's own `Project.toml`/`Manifest.toml` (`exeflags: ["--project=."]`). A hidden setup chunk near the top of the Results section `include`s `outputs/manuscript_metrics_data.jl`, a generated data file holding every hand-typed calibration/test/timing number quoted inline elsewhere in the document (Figure 2's caption, Table S1, Table S2, single-run timing). That file is shared by two independent scripts, each merging its own keys into it rather than overwriting the other's:

`src/outcomes/calibration_scores.jl` loads the domain and runs the model to compute
  performance/skill metrics - run it manually (`julia --project=. src/outcomes/calibration_scores.jl`) whenever the calibration outputs change.

`src/outcomes/single_run_timing.jl` times a single forward simulation of the full domain, single-core and single-threaded - run it manually (`julia --project=. -t 1 src/outcomes/single_run_timing.jl`) whenever that estimate needs refreshing.

A separate setup chunk (in the "Coral survival under high DHW varies with depth"
section) `include`s `outputs/sensitivity_analysis_factors_data.jl`. Written by
`src/outcomes/sensitivity_analysis_factors.jl`, which mirrors
`src/sensitivity_analysis/01_run_sa.jl`'s domain setup and reads the real bounds off
`ADRIA.model_spec(dom)`/`SAConfig` rather than having them hand-typed. Run it manually
(`julia --project=. src/outcomes/sensitivity_analysis_factors.jl`) whenever `SAConfig` or the underlying model's factor bounds change.

`quarto render` only reads the frozen result, so it stays fast and doesn't re-run the model on every render. Quarto manages its own Julia notebook-runner environment separately and bootstraps it automatically the first time you render.

## Generating figures

Every manuscript figure is committed under `figures/`. Two are static images drawn outside
this repo — Figure 1 (`01_coralblox_processes.png`, the process schematic) and Figure S1
(`S01_reef_groups_map.png`, the reef-group map) — and nothing here regenerates them. The
rest are produced by scripts in `src/figures/`.

### Quick path: regenerate from committed data

```shell
julia --project=. src/main.jl
```

Loads the calibrated domain, runs the model once, and rebuilds Figures 2–6 and S2–S8 from
that run plus the data already committed in `outputs/`. This needs `config.toml` with
`[calibration.domains]`, `[calibration.geospatial]` and `[calibration.products]` set (copy
`config.toml.example` and fill in the paths). It does **not** re-run the calibration or the
sensitivity analysis — both are covered separately below.

`src/generate_figures.jl` is the same include list without the one-off model run, for
iterating on a single plot in an already-warm session.

### Figure → script

| Figure | Script (`src/figures/`) | Reads |
| --- | --- | --- |
| 1 | — (static image) | `figures/01_coralblox_processes.png` |
| 2 | `02_plot_performance_metrics.jl` | calibrated domain run + `outputs/manuscript_metrics_data.jl` |
| 3, 4 | `03_plot_reef_groups.jl` | calibrated domain run (calibration + test splits) |
| 5 | `05_plot_reefs_comparison.jl` | calibrated domain run + LTMP disturbance data |
| 6 | `06_plot_sensitivity_analysis.jl` | `outputs/sensitivity_analysis_shapley_effects.parq` |
| S1 | — (static image) | `figures/S01_reef_groups_map.png` |
| S2 | `s02_plot_dhw.jl` | calibrated domain run (historical DHW) |
| S3 | `s03_effective_dhw_depth_attenuation.jl` | `calibrated_params.nc` |
| S4 | `s04_plot_convergence_analysis.jl` | `outputs/sensitivity_analysis_convergence.parq` |
| S5, S6 | `s05_rmse_diff_calibration.jl`, `s06_rmse_diff_test.jl` | calibrated domain run (bootstrap CIs) |
| S7, S8 | `s07_srcc_calibration.jl`, `s08_srcc_test.jl` | calibrated domain run (bootstrap CIs) |

The quick path is enough unless the calibration or the sensitivity-analysis inputs
themselves change. The two sections below cover regenerating those.

### Calibration

The calibration is **not run in this repo** — it lives in the separate
[`CoralBlox-params-calibration`](https://github.com/open-AIMS/CoralBlox-params-calibration)
repo, which writes two products this repo consumes: `calibrated_params.nc` and
`historic_init_cover.nc`. Point `config.toml`'s `[calibration.products].calib_params` and
`.init_cover` at them. This repo never re-fits parameters.

After a recalibration, refresh the numbers quoted inline in the manuscript (Figure 2
caption, Table S1, single-run timing) by running `src/outcomes/calibration_scores.jl` and
`src/outcomes/single_run_timing.jl` — see [References](#references) above. Figures 2–5 and
S2–S8 pick up the new calibration on the next `src/main.jl`.

### Sensitivity analysis

Figure 6 (Shapley effects) and Figure S4 (convergence analysis) come from a variance-based
global sensitivity analysis (GSA) on a synthetic single reef. Unlike every other figure in
this repo it is a three-stage pipeline rather than a single script, because the first stage
is expensive (tens of thousands of model runs) and shouldn't be re-run just to tweak a plot.

Stages 1–2 need `config.toml` with `[calibration.domains].rme_domain` and
`[calibration.products].calib_params` set (as for the quick path), plus a
`[sensitivity_analysis]` section:

```toml
[sensitivity_analysis]
n_samples = 1000    # total ADRIA runs per DHW range = n_samples * (n_factors + 1), ~218 factors
n_cores = 6          # optional, defaults to 1; runs via Distributed.jl with n_cores - 1 workers
raw_data_dir = "C:/path/to/external/raw_results"   # external, multi-GB, created if missing
```

Stage 3 reads only the two committed `outputs/*.parq` files, so it needs no
`[sensitivity_analysis]` config — it runs on a fresh clone with nothing in `config.toml`
beyond what the quick path already needs.

1. **Run** — `julia --project=. src/sensitivity_analysis/01_run_sa.jl`. Samples ~218 model
   factors and runs ADRIA once per sample per DHW range (total runs ≈
   `n_samples * (n_factors + 1)` per range), against this repo's own pinned RME domain and
   calibrated params (`config.toml`'s `[calibration.domains].rme_domain` /
   `[calibration.products].calib_params`), not a separately-configured domain. Writes raw
   per-sample results to `[sensitivity_analysis].raw_data_dir` — an EXTERNAL, multi-GB,
   git-ignored directory, mirroring `[calibration.outputs].out_dir`'s pattern. `n_samples`
   is the main runtime driver; `n_cores` runs it via `Distributed.jl` with `n_cores - 1`
   workers when > 1. Skip this step unless you actually need fresh raw results — it can take
   hours.
2. **Aggregate** — `julia --project=. src/sensitivity_analysis/02_aggregate_results.jl`.
   Reads `raw_data_dir`, computes Shapley effects and convergence diagnostics, and writes
   the two small, tidy, **committed** Parquet files:
   `outputs/sensitivity_analysis_shapley_effects.parq` and
   `outputs/sensitivity_analysis_convergence.parq`. Fast (no model runs) — safe to re-run
   whenever the raw results change.
3. **Plot** — `06_plot_sensitivity_analysis.jl` and `s04_plot_convergence_analysis.jl` read
   those two committed Parquet files and write `figures/06_sensitivity_analysis.png` /
   `figures/S04_convergence_analysis.png`. Both are in the `src/main.jl` include list, so
   the quick path already regenerates them from whatever is committed in `outputs/` — no
   raw data needed.

In short: stages 1–2 are for whoever needs to regenerate the underlying analysis (e.g.
after a recalibration); stage 3 is what runs by default.
