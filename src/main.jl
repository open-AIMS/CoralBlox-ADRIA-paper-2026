using Revise
using Infiltrator
using CairoMakie
using Typst_jll
using GeoMakie
using GeoMakie.GO
using ADRIA
using ADRIA: RESULTS
using NetCDF
using YAXArrays
using TOML

using CoralBloxCalib
using CoralBloxCalib.common
using CoralBloxCalib.calibration
using CoralBloxCalib.viz
using CoralBloxCalib.viz: COLORS, taxa_props_legend_elements

# * Units relative to 1 CSS px
inch = 96
pt = 4 / 3
cm = inch / 2.54

fig_path::String = dirname(@__DIR__) .* "/figures"

# * Load calibration domain, observations and calibrated model run
# Config is owned by this repo (not CoralBloxCalib's own config.toml) so the
# visualized result set is pinned here, independent of the calibration repo's state.
config_path = joinpath(dirname(@__DIR__), "config.toml")
config = load_config(config_path)

# CalibrationConfig has no fields for the calibration products, so read them straight from
# this repo's config.toml.
products = TOML.parsefile(config_path)["calibration"]["products"]
CALIB_PARAMS_FN = products["calib_params"]
INIT_COVER_FN = products["init_cover"]
for fn in (CALIB_PARAMS_FN, INIT_COVER_FN)
    isfile(fn) || error("Missing calibration product $fn - run the calibration first.")
end

# ADRIA folds calibrated_params.nc into the domain's model spec, so param_table returns the
# calibrated scenario directly - no results.dat and no setup_run needed here.
dom = load_domain(config; calib_params_fn=CALIB_PARAMS_FN)

init_cover_da = open_dataset(INIT_COVER_FN).init_coral_cover
@assert size(init_cover_da) == size(dom.init_coral_cover) (
    "$INIT_COVER_FN is $(size(init_cover_da)) but the domain expects " *
    "$(size(dom.init_coral_cover)) - it was written for a different domain."
)
dom.init_coral_cover .= Array(init_cover_da)

calib_data = build_calibration_data(
    dom,
    config.ltmp_reef_data_path, config.composition_path
)
TEST_STORE = calib_data.test_store
CALIBRATION_STORE = calib_data.calibration_store

scen = ADRIA.param_table(dom)
rs_raw = ADRIA.run_model(dom, scen[1, :]; apply_allee_effect=false)

# * Single reef scale: model vs observed
# ** Sort reefs by SRCC
test_error_stats = collect_error_stats(rs_raw.raw, dom; observations=TEST_STORE)
srcc_sortperm = sortperm(test_error_stats.srcc)
reefs_sorted_by_srcc = TEST_STORE.ltmp_unique_ids[srcc_sortperm]

# ** Sort reefs by RMSE
rmse_sortperm = sortperm(test_error_stats.rmse_model)
reefs_sorted_by_rmse = TEST_STORE.ltmp_unique_ids[rmse_sortperm]

# ** Setup
# * Metrics map
t_ltmp_uids = TEST_STORE.ltmp_unique_ids
c_ltmp_uids = CALIBRATION_STORE.ltmp_unique_ids

# Per-reef bootstrap CIs (block bootstrap over years, n>=5; iid, n=4 - see
# CoralBloxCalib.common._per_reef_bootstrap_stats) rather than plain point estimates, to
# match the methodology now used by CoralBlox-params-calibration/scripts/plot/viz_results.jl.
t_rmse_stats = rmse_diff_stats(rs_raw.raw, TEST_STORE, dom)
c_rmse_stats = rmse_diff_stats(rs_raw.raw, CALIBRATION_STORE, dom)

t_corr_stats = correlation_stats(rs_raw.raw, TEST_STORE, dom; correlation_metric=:spearman)
c_corr_stats = correlation_stats(rs_raw.raw, CALIBRATION_STORE, dom; correlation_metric=:spearman)

t_rmse_diffs = t_rmse_stats.diff
c_rmse_diffs = c_rmse_stats.diff

# ** Sort reefs by ΔRMSE (benchmark - model; low/negative = model underperforms benchmark)
rmse_diff_sortperm = sortperm(t_rmse_diffs)
reefs_sorted_by_rmse_diff = TEST_STORE.ltmp_unique_ids[rmse_diff_sortperm]

t_srcc_ = t_corr_stats.corr
c_srcc_ = c_corr_stats.corr

# A reef's estimate is "significant" if its 95% bootstrap CI excludes zero.
t_rmse_significant = (t_rmse_stats.ci_lo .> 0) .| (t_rmse_stats.ci_hi .< 0)
c_rmse_significant = (c_rmse_stats.ci_lo .> 0) .| (c_rmse_stats.ci_hi .< 0)
t_srcc_significant = (t_corr_stats.ci_lo .> 0) .| (t_corr_stats.ci_hi .< 0)
c_srcc_significant = (c_corr_stats.ci_lo .> 0) .| (c_corr_stats.ci_hi .< 0)

domain_gpkg = TEST_STORE.domain_gpkg
geometries = domain_gpkg.geometry
geometries = simplify.(geometries; ratio=0.5)

t_ltmp_idx = [findfirst(domain_gpkg.UNIQUE_ID .== uid) for uid in t_ltmp_uids]
c_ltmp_idx = [findfirst(domain_gpkg.UNIQUE_ID .== uid) for uid in c_ltmp_uids]

t_lon = domain_gpkg[t_ltmp_idx, :].LON
t_lat = domain_gpkg[t_ltmp_idx, :].LAT

c_lon = domain_gpkg[c_ltmp_idx, :].LON
c_lat = domain_gpkg[c_ltmp_idx, :].LAT

include("./01_plot_performance_metrics.jl")
include("./02_plot_reef_groups.jl")
include("./03_plot_reefs_comparison.jl")
include("./04_plot_dhw.jl")
include("./supplementary_figures/effective_dhw_depth_attenuation.jl")
