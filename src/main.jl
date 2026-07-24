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
using Serialization

using CoralBloxCalib
using CoralBloxCalib.common
using CoralBloxCalib.calibration
using CoralBloxCalib.viz
using CoralBloxCalib.viz: plot_metric_map!, COLORS, taxa_props_legend_elements

# * Units relative to 1 CSS px
inch = 96
pt = 4 / 3
cm = inch / 2.54

fig_path::String = dirname(@__DIR__) .* "/figures"

# * Load calibration domain, observations and calibrated model run
# Config is owned by this repo (not CoralBloxCalib's own config.toml) so the
# visualized result set is pinned here, independent of the calibration repo's state.
config = load_config(joinpath(dirname(@__DIR__), "config.toml"))
dom = load_domain(config)
location_classification = load_location_classification(config.loc_class_path)

cfg = CalibConfig(dom)
calib_data = build_calibration_data(
    dom,
    config.ltmp_reef_data_path, config.composition_path
)
VALIDATION_STORE = calib_data.validation_store
CALIBRATION_STORE = calib_data.calibration_store

init_cover = deserialize(config.init_cover_path)
construct_cover!(dom, init_cover, location_classification.consecutive_classification)

calibrated_params = deserialize(joinpath(config.out_dir, "results.dat"))
dom, scen = setup_run(
    dom,
    calibrated_params;
    param_names=cfg.coral_param_names,
    growth_accel_names=cfg.growth_accel_names,
    dist_std_group_cols=cfg.dist_std_group_cols,
    param_idxs=cfg.param_idxs,
    observations=calib_data.combined_store,
    biogroup_ord=cfg.biogroups_ordering,
)
rs_raw = ADRIA.run_model(dom, scen[1, :])

# * Single reef scale: model vs observed
# ** Sort reefs by SRCC
validation_error_stats = collect_error_stats(rs_raw.raw, dom; observations=VALIDATION_STORE)
srcc_sortperm = sortperm(validation_error_stats.srcc)
reefs_sorted_by_srcc = VALIDATION_STORE.ltmp_unique_ids[srcc_sortperm]

# ** Sort reefs by RMSE
rmse_sortperm = sortperm(validation_error_stats.rmse_model)
reefs_sorted_by_rmse = VALIDATION_STORE.ltmp_unique_ids[rmse_sortperm]

# ** Setup
# * Metrics map
v_ltmp_uids = VALIDATION_STORE.ltmp_unique_ids
c_ltmp_uids = CALIBRATION_STORE.ltmp_unique_ids
v_n_obs = length(v_ltmp_uids)
c_n_obs = length(c_ltmp_uids)

v_error_stats =
    collect_error_stats.(
        Ref(rs_raw.raw), collect(1:v_n_obs), Ref(dom);
        observations=VALIDATION_STORE
    )
c_error_stats =
    collect_error_stats.(
        Ref(rs_raw.raw), collect(1:c_n_obs), Ref(dom);
        observations=CALIBRATION_STORE
    )

v_rmse_ = getproperty.(v_error_stats, :rmse_model)
v_benchmark_ = getproperty.(v_error_stats, :rmse_benchmark)
v_srcc_ = getproperty.(v_error_stats, :srcc)

c_rmse_ = getproperty.(c_error_stats, :rmse_model)
c_benchmark_ = getproperty.(c_error_stats, :rmse_benchmark)
c_srcc_ = getproperty.(c_error_stats, :srcc)

v_rmse_diffs = v_benchmark_ .- v_rmse_
c_rmse_diffs = c_benchmark_ .- c_rmse_

domain_gpkg = VALIDATION_STORE.domain_gpkg
geometries = domain_gpkg.geometry
geometries = simplify.(geometries; ratio=0.5)

v_ltmp_idx = [findfirst(domain_gpkg.UNIQUE_ID .== uid) for uid in v_ltmp_uids]
c_ltmp_idx = [findfirst(domain_gpkg.UNIQUE_ID .== uid) for uid in c_ltmp_uids]

v_lon = domain_gpkg[v_ltmp_idx, :].LON
v_lat = domain_gpkg[v_ltmp_idx, :].LAT

c_lon = domain_gpkg[c_ltmp_idx, :].LON
c_lat = domain_gpkg[c_ltmp_idx, :].LAT

include("./01_plot_performance_metrics.jl")
include("./02_plot_reef_groups.jl")
include("./03_plot_reefs_comparison.jl")
include("./04_plot_dhw.jl")
