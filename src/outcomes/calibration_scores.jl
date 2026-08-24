using ADRIA
using ADRIA: GDF
using ArchGDAL
using Bootstrap
using Distances
using NetCDF
using StatsBase
using TOML
using YAXArrays

using CoralBloxCalib
using CoralBloxCalib.common
using CoralBloxCalib.calibration
using CoralBloxCalib.viz

# * Load calibration domain, observations and calibrated model run
# Mirrors src/main.jl's setup (kept separate rather than `include`d so this script stays
# a lightweight stats-only entry point for paper.qmd, without main.jl's plotting side effects).
config_path = joinpath(dirname(dirname(@__DIR__)), "config.toml")
config = load_config(config_path)

products = TOML.parsefile(config_path)["calibration"]["products"]
CALIB_PARAMS_FN = products["calib_params"]
INIT_COVER_FN = products["init_cover"]
for fn in (CALIB_PARAMS_FN, INIT_COVER_FN)
    isfile(fn) || error("Missing calibration product $fn - run the calibration first.")
end

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

# * Per-reef bootstrap CIs and bootstrapped aggregate medians, via CoralBloxCalib.common's
# own bootstrap machinery - see CoralBloxCalib.common._per_reef_bootstrap_stats.
calib_rmse_stats = rmse_diff_stats(rs_raw.raw, CALIBRATION_STORE, dom)
test_rmse_stats = rmse_diff_stats(rs_raw.raw, TEST_STORE, dom)

calib_corr_stats = correlation_stats(rs_raw.raw, CALIBRATION_STORE, dom; correlation_metric=:spearman)
test_corr_stats = correlation_stats(rs_raw.raw, TEST_STORE, dom; correlation_metric=:spearman)

calib_bias_stats = bias_stats(rs_raw.raw, CALIBRATION_STORE, dom)
test_bias_stats = bias_stats(rs_raw.raw, TEST_STORE, dom)

# * Figure 2 caption: reefs where the model outperforms the benchmark (ΔRMSE > 0)
n_outperform_calib = sum(calib_rmse_stats.diff .> 0)
n_reefs_calib = length(calib_rmse_stats.diff)
n_outperform_test = sum(test_rmse_stats.diff .> 0)
n_reefs_test = length(test_rmse_stats.diff)

# * Table S1: bootstrapped median performance metrics per reef set.
# ΔRMSE, SRCC and bias reuse the same bootstrapped medians as Figure 2 (computed over the
# block-bootstrap-eligible reefs, n_years >= 5 - see CoralBloxCalib.common.rmse_diff_stats/
# bias_stats). Absolute RMSE has no equivalent package function, so its per-reef point
# estimates (restricted to the same block-eligible reef set) are aggregated with the
# package's own `bootstrap_median_ci`, for consistency with the ΔRMSE/SRCC/bias rows.
# Median |bias| is reported alongside the signed median bias: the signed median can be near
# zero purely from roughly-as-many-reefs-over-as-underpredicting, so it alone doesn't show
# how far off a typical individual reef is - see bias_stats' docstring.
calib_error_stats = collect_error_stats(rs_raw.raw, dom; observations=CALIBRATION_STORE)
test_error_stats = collect_error_stats(rs_raw.raw, dom; observations=TEST_STORE)

# * Figure 5: two worst and two best test reefs by ΔRMSE (benchmark - model), matching
# src/03_plot_reefs_comparison.jl's reef selection exactly (low/negative ΔRMSE = model
# underperforms the benchmark, high ΔRMSE = model substantially beats it).
fig5_reefs_sorted = TEST_STORE.ltmp_unique_ids[sortperm(test_rmse_stats.diff)]
fig5_reef_ids = vcat(fig5_reefs_sorted[1:2], fig5_reefs_sorted[end-1:end])
fig5_idx = [findfirst(TEST_STORE.ltmp_unique_ids .== loc) for loc in fig5_reef_ids]
fig5_names = [TEST_STORE.domain_gpkg[TEST_STORE.domain_gpkg.RME_UNIQUE_ID.==l, :cluster_id][1] for l in fig5_reef_ids]

fig5_rmse = round.(test_error_stats.rmse_model[fig5_idx]; digits=2)
fig5_rmse_benchmark = round.(test_error_stats.rmse_benchmark[fig5_idx]; digits=2)
fig5_rmse_diff = round.(test_rmse_stats.diff[fig5_idx]; digits=2)
fig5_srcc = round.(test_error_stats.srcc[fig5_idx]; digits=2)
fig5_bias = round.(test_error_stats.bias[fig5_idx]; digits=2)

calib_rmse_median_stats = bootstrap_median_ci(
    calib_error_stats.rmse_model[calib_rmse_stats.block_eligible]
)
test_rmse_median_stats = bootstrap_median_ci(
    test_error_stats.rmse_model[test_rmse_stats.block_eligible]
)

# * Table S2: bootstrapped SRCC between reef position/max DHW and each performance metric.
# Point-estimate (non-bootstrapped) per-reef ΔRMSE/SRCC correlated against position and
# heat stress via Bootstrap.jl's `bootstrap(corr_boot, ..., BalancedSampling(1000))`.
function calculate_along(lats::AbstractVector{<:Real})
    lat_north = maximum(lats)
    lat_south = minimum(lats)
    return (lat_north .- lats) ./ (lat_north .- lat_south)
end

dom_gpkg = dom.loc_data

# Read fresh rather than reaching into CoralBloxCalib.viz's cached GBRMPA_MAINLAND_GPKG -
# that constant's ArchGDAL geometry pointers go stale once its GDAL layer closes (see
# viz.jl's own comment on GBRMPA_MAINLAND_POLYS), and by the time this script runs it has
# long since closed.
mainland_gpkg = GDF.read(CoralBloxCalib.viz.GBRMPA_MAINLAND_PATH)
mainland_ring = ArchGDAL.getgeom(mainland_gpkg.geometry[1], 0)
n_mainland_points = ArchGDAL.ngeom(mainland_ring)
mainland_coords = [
    (
        ArchGDAL.getpoint(mainland_ring, i - 1)[2],
        ArchGDAL.getpoint(mainland_ring, i - 1)[1]
    )
    for i in 1:n_mainland_points
]

reef_dists = map(1:length(dom_gpkg.LAT)) do i
    reef_point = (dom_gpkg.LAT[i], dom_gpkg.LON[i])
    vertex_dists = [haversine(reef_point, mainland_coords[j], 6371.0) for j in 1:n_mainland_points]
    minimum(vertex_dists)
end

across = reef_dists
along = calculate_along(dom_gpkg.LAT)

Δrmse_calib = calib_error_stats.rmse_benchmark .- calib_error_stats.rmse_model
Δrmse_test = test_error_stats.rmse_benchmark .- test_error_stats.rmse_model
srcc_calib = calib_error_stats.srcc
srcc_test = test_error_stats.srcc

calib_idx = [findfirst(dom_gpkg.RME_UNIQUE_ID .== uid) for uid in CALIBRATION_STORE.ltmp_unique_ids]
test_idx = [findfirst(dom_gpkg.RME_UNIQUE_ID .== uid) for uid in TEST_STORE.ltmp_unique_ids]

across_calib = across[calib_idx]
across_test = across[test_idx]
along_calib = along[calib_idx]
along_test = along[test_idx]

# `dom.dhw_scens` dims are (timesteps, locations, scenarios); indexed positionally since
# `calib_idx`/`test_idx` are row positions into `dom.loc_data`, which lines up 1:1 with the
# `locations` dimension - `locations=idx` silently no-ops because that dimension's labels
# are location IDs, not plain integers.
max_dhw_calib = [maximum(dom.dhw_scens[:, idx, 1]) for idx in calib_idx]
max_dhw_test = [maximum(dom.dhw_scens[:, idx, 1]) for idx in test_idx]

n_boot = 1000
# A degenerate resample (e.g. all-identical resampled x or y) makes corspearman's
# zero-variance denominator undefined; treated as zero correlation rather than crashing
# the CI's quantile computation, same rationale as the degenerate-resample handling in
# CoralBloxCalib.common's newer per-reef bootstrap (_bootstrap_replicates), though this
# legacy Bootstrap.jl/BalancedSampling code substitutes 0.0 rather than rejecting and
# redrawing the replicate.
corr_boot = x -> begin
    c = corspearman(x[:, 1], x[:, 2])
    isnan(c) ? 0.0 : c
end
bs = BalancedSampling(n_boot)
cil = 0.95

"""
    spearman_ci(x, y)

Bootstrapped Spearman correlation between `x` and `y` with a 95% CI, via Bootstrap.jl's
`BalancedSampling`. Reefs with a `NaN` in either `x` or `y` (e.g. `collect_error_stats`
returns `NaN` for a reef with no non-missing observations) are dropped from the pair
before bootstrapping, since `corspearman`/`quantile` are undefined in their presence.
"""
function spearman_ci(x::AbstractVector, y::AbstractVector)
    finite = (!).(isnan.(x)) .& (!).(isnan.(y))
    boot = bootstrap(corr_boot, hcat(x[finite], y[finite]), bs)
    point, lo, hi = confint(boot, BasicConfInt(cil))[1]
    return (point=point, lo=lo, hi=hi)
end

s1_Δrmse_calib_along = spearman_ci(along_calib, Δrmse_calib)
s1_Δrmse_test_along = spearman_ci(along_test, Δrmse_test)
s1_srcc_calib_along = spearman_ci(along_calib, srcc_calib)
s1_srcc_test_along = spearman_ci(along_test, srcc_test)

s1_Δrmse_calib_across = spearman_ci(across_calib, Δrmse_calib)
s1_Δrmse_test_across = spearman_ci(across_test, Δrmse_test)
s1_srcc_calib_across = spearman_ci(across_calib, srcc_calib)
s1_srcc_test_across = spearman_ci(across_test, srcc_test)

s1_Δrmse_calib_dhw = spearman_ci(max_dhw_calib, Δrmse_calib)
s1_Δrmse_test_dhw = spearman_ci(max_dhw_test, Δrmse_test)
s1_srcc_calib_dhw = spearman_ci(max_dhw_calib, srcc_calib)
s1_srcc_test_dhw = spearman_ci(max_dhw_test, srcc_test)

# * Write out [point, lo, hi] triples for paper.qmd to read without re-running the model.
# Regenerate this file (`julia --project=. src/outcomes/calibration_scores.jl`) whenever
# the calibration outputs change - paper.qmd only reads it, it never runs the model itself.
triple(nt) = [nt.point, nt.lo, nt.hi]
triple(point, lo, hi) = [point, lo, hi]

scores = Dict{String,Any}(
    "n_outperform_calib" => n_outperform_calib,
    "n_reefs_calib" => n_reefs_calib,
    "n_outperform_test" => n_outperform_test,
    "n_reefs_test" => n_reefs_test,
    "rmse_diff_calib_median" => triple(calib_rmse_stats.median, calib_rmse_stats.median_lo, calib_rmse_stats.median_hi),
    "rmse_diff_test_median" => triple(test_rmse_stats.median, test_rmse_stats.median_lo, test_rmse_stats.median_hi),
    "srcc_calib_median" => triple(calib_corr_stats.median, calib_corr_stats.median_lo, calib_corr_stats.median_hi),
    "srcc_test_median" => triple(test_corr_stats.median, test_corr_stats.median_lo, test_corr_stats.median_hi),
    "bias_calib_median" => triple(calib_bias_stats.median, calib_bias_stats.median_lo, calib_bias_stats.median_hi),
    "bias_test_median" => triple(test_bias_stats.median, test_bias_stats.median_lo, test_bias_stats.median_hi),
    "bias_calib_median_abs" => triple(calib_bias_stats.median_abs_bias, calib_bias_stats.median_abs_bias_lo, calib_bias_stats.median_abs_bias_hi),
    "bias_test_median_abs" => triple(test_bias_stats.median_abs_bias, test_bias_stats.median_abs_bias_lo, test_bias_stats.median_abs_bias_hi),
    "rmse_calib_median" => triple(calib_rmse_median_stats.median, calib_rmse_median_stats.lo, calib_rmse_median_stats.hi),
    "rmse_test_median" => triple(test_rmse_median_stats.median, test_rmse_median_stats.lo, test_rmse_median_stats.hi),
    "s1_rmse_diff_calib_along" => triple(s1_Δrmse_calib_along),
    "s1_rmse_diff_test_along" => triple(s1_Δrmse_test_along),
    "s1_rmse_diff_calib_across" => triple(s1_Δrmse_calib_across),
    "s1_rmse_diff_test_across" => triple(s1_Δrmse_test_across),
    "s1_rmse_diff_calib_dhw" => triple(s1_Δrmse_calib_dhw),
    "s1_rmse_diff_test_dhw" => triple(s1_Δrmse_test_dhw),
    "s1_srcc_calib_along" => triple(s1_srcc_calib_along),
    "s1_srcc_test_along" => triple(s1_srcc_test_along),
    "s1_srcc_calib_across" => triple(s1_srcc_calib_across),
    "s1_srcc_test_across" => triple(s1_srcc_test_across),
    "s1_srcc_calib_dhw" => triple(s1_srcc_calib_dhw),
    "s1_srcc_test_dhw" => triple(s1_srcc_test_dhw),
)

for (i, letter) in enumerate(["a", "b", "c", "d"])
    scores["fig5_$(letter)_name"] = fig5_names[i]
    scores["fig5_$(letter)_rmse"] = fig5_rmse[i]
    scores["fig5_$(letter)_rmse_benchmark"] = fig5_rmse_benchmark[i]
    scores["fig5_$(letter)_rmse_diff"] = fig5_rmse_diff[i]
    scores["fig5_$(letter)_srcc"] = fig5_srcc[i]
    scores["fig5_$(letter)_bias"] = fig5_bias[i]
end

scores_path = joinpath(dirname(dirname(@__DIR__)), "outputs", "calibration_scores_data.jl")
open(scores_path, "w") do io
    println(io, "# Generated by src/outcomes/calibration_scores.jl - do not edit by hand.")
    println(io, "scores = Dict{String,Any}(")
    for (k, v) in sort(collect(scores); by=first)
        println(io, "    \"$k\" => $(repr(v)),")
    end
    println(io, ")")
end
@info "Wrote $scores_path"
