# CoralBlox-ADRIA paper (2026)

This repo supports the paper "CoralBlox: A computationally efficient coral model for decision support". It contains the code to generate the manuscript (`paper/`) and all plots (`src/`).

Depends on `CoralBloxCalib` (dev'd from the `CoralBlox-params-calibration` repo) and reads
its `config.toml` for domain/dataset paths — see that repo's config for calibration output
locations (`out_dir`, `results.dat`, etc.).

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
│                                # "Running the sensitivity analysis" below
├─ figures/    # generated figures (committed)
├─ outputs/    # generated non-figure data (committed - e.g. manuscript_metrics_data.jl,
│               # sensitivity_analysis_shapley_effects.parq, sensitivity_analysis_convergence.parq)
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
this repo's own `Project.toml`/`Manifest.toml` (`exeflags: ["--project=."]`). A hidden setup
chunk near the top of the Results section `include`s `outputs/manuscript_metrics_data.jl`, a
generated data file holding every hand-typed calibration/test/timing number quoted inline
elsewhere in the document (Figure 2's caption, Table S1, Table S2, single-run timing). That
file is shared by two independent scripts, each merging its own keys into it rather than
overwriting the other's:

- `src/outcomes/calibration_scores.jl` loads the domain and runs the model to compute
  performance/skill metrics - run it manually
  (`julia --project=. src/outcomes/calibration_scores.jl`) whenever the calibration outputs
  change.
- `src/outcomes/single_run_timing.jl` times a single forward simulation of the full domain,
  single-core and single-threaded - run it manually
  (`julia --project=. -t 1 src/outcomes/single_run_timing.jl`) whenever that estimate needs
  refreshing.

A separate hidden setup chunk (in the "Coral survival under high DHW varies with depth"
section) `include`s `outputs/sensitivity_analysis_factors_data.jl` instead - kept apart from
`manuscript_metrics_data.jl` since it describes a different thing (Table S11's literal-numeric
sensitivity-analysis sampling bounds, not calibration/test performance). Written by
`src/outcomes/sensitivity_analysis_factors.jl`, which mirrors
`src/sensitivity_analysis/01_run_sa.jl`'s domain setup and reads the real bounds off
`ADRIA.model_spec(dom)`/`SAConfig` rather than having them hand-typed (and liable to drift, as
happened at least twice already) - run it manually
(`julia --project=. src/outcomes/sensitivity_analysis_factors.jl`) whenever `SAConfig` or the
underlying model's factor bounds change.

`quarto render` only reads the frozen result, so it stays fast and doesn't re-run the model on
every render. Quarto manages its own Julia notebook-runner environment separately and
bootstraps it automatically the first time you render.

## Running the sensitivity analysis

Figure 6 (Shapley effects) and Figure S4 (convergence analysis) are generated from a
variance-based global sensitivity analysis (GSA) on a synthetic single reef, migrated from
the standalone `Analysis_CoralBlox_Shapley-Effect` repo. Unlike every other figure in this
repo, it is a three-stage pipeline rather than a single script, because the first stage is
expensive (tens of thousands of model runs) and shouldn't be re-run just to tweak a plot.

`config.toml` is git-ignored (no committed example file), so a fresh clone needs it created
by hand before steps 1-2 will run. It must already have `[calibration.domains].rme_domain`
and `[calibration.products].calib_params` set (steps 1-2 read these directly - see "Model
calibration and testing" above for what they point to), plus a `[sensitivity_analysis]`
section:

```toml
[sensitivity_analysis]
n_samples = 1000    # total ADRIA runs per DHW range = n_samples * (n_factors + 1), ~218 factors
n_cores = 6          # optional, defaults to 1; runs via Distributed.jl with n_cores - 1 workers
raw_data_dir = "C:/path/to/external/raw_results"   # external, multi-GB, created if missing
```

Step 3 only reads the two committed `outputs/*.parq` files, so it needs no
`[sensitivity_analysis]` config at all - it'll run on a fresh clone with no `config.toml`
changes beyond what `main.jl` already needs.

1. **Run** — `julia --project=. src/sensitivity_analysis/01_run_sa.jl`. Samples ~218 model
   factors and runs ADRIA once per sample per DHW range (total runs ≈
   `n_samples * (n_factors + 1)` per range), using THIS repo's own pinned RME domain and
   calibrated params (`config.toml`'s `[calibration.domains].rme_domain` /
   `[calibration.products].calib_params`), not a separately-configured domain. Writes raw
   per-sample results to `config.toml`'s `[sensitivity_analysis].raw_data_dir` — an
   EXTERNAL, multi-GB, git-ignored directory, mirroring `[calibration.outputs].out_dir`'s
   pattern. Controlled by `[sensitivity_analysis]`'s `n_samples` (the main runtime driver)
   and `n_cores` (runs via `Distributed.jl` with `n_cores - 1` worker processes when > 1).
   This is the step to skip unless you actually need fresh raw results — it can take hours.
2. **Aggregate** — `julia --project=. src/sensitivity_analysis/02_aggregate_results.jl`.
   Reads `raw_data_dir`, computes Shapley effects and convergence diagnostics, and writes
   the two small, tidy, COMMITTED Parquet files: `outputs/sensitivity_analysis_shapley_effects.parq`
   and `outputs/sensitivity_analysis_convergence.parq`. Fast (no model runs) — safe to
   re-run whenever the raw results change.
3. **Plot** — `src/figures/06_plot_sensitivity_analysis.jl` and
   `src/figures/s04_plot_convergence_analysis.jl` read those two committed Parquet files and
   write `figures/06_sensitivity_analysis.png` / `figures/S04_convergence_analysis.png`,
   which `paper.qmd` references directly. Unlike steps 1-2, these two ARE included by
   `main.jl`, so a normal `julia --project=. src/main.jl` regenerates them from whatever is
   already committed in `outputs/` without touching the raw data at all.

In short: steps 1-2 are for whoever needs to regenerate the underlying sensitivity analysis
(e.g. after a recalibration); step 3 is what runs by default, and only needs the two
committed Parquet files to already exist.
