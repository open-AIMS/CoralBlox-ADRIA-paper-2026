# ! Using Distances.jl for geodesic distance calculations with Haversine formula
using ArchGDAL
using Distances

"""
    calculate_along(lats)

Calculates the normalized position along the GBR from north to south.

# Arguments
- `lats`: Vector of latitudes for each reef

# Returns
Vector of "along" values in [0, 1] where:
- 0 = at the northern end of the GBR
- 1 = at the southern end of the GBR
- 0.5 = midway between north and south

# Formula
along = d_north / (d_north + d_south)

where distances are calculated as latitude differences from the extremes.
"""
function calculate_along(lats::AbstractVector{<:Real})
    # Find the northern and southern ends
    lat_north = maximum(lats)  # Northernmost (highest latitude, less negative)
    lat_south = minimum(lats)  # Southernmost (lowest latitude, more negative)

    # Calculate "along"
    return (lat_north .- lats) ./ (lat_north .- lat_south)
end

## Latitudes
dom_gpkg = dom.loc_data

# Get linear ring of mainland boundary
mainland_ring = ArchGDAL.getgeom(GBRMPA_MAINLAND_GPKG.geometry[1], 0)

# Extract mainland boundary vertices for distance calculations
n_points = ArchGDAL.ngeom(mainland_ring)
mainland_coords = [
    (
        ArchGDAL.getpoint(mainland_ring, i - 1)[2],
        ArchGDAL.getpoint(mainland_ring, i - 1)[1]
    )
    for i in 1:n_points
]

# ! Calculate minimum geodesic distance from each reef to the mainland boundary
# ! Using Haversine formula for accurate spherical distance calculations
reef_dists = map(1:length(dom_gpkg.LAT)) do i
    reef_point = (dom_gpkg.LAT[i], dom_gpkg.LON[i])

    # Calculate distance to all mainland vertices and find minimum
    vertex_dists = [haversine(reef_point, mainland_coords[j], 6371.0) for j in 1:n_points]
    minimum(vertex_dists)
end

# Step 3
across = reef_dists
along = calculate_along(dom_gpkg.LAT)

# * Corr analysis

# ! Calculate error statistics for calibration and validation stores
stats_calib = collect_error_stats(rs_raw.raw; observations=CALIBRATION_STORE)
stats_valid = collect_error_stats(rs_raw.raw; observations=VALIDATION_STORE)

# ! Extract RMSE differences (benchmark - model) and Spearman correlation coefficients
Δrmse_calib = stats_calib.rmse_benchmark .- stats_calib.rmse_model
Δrmse_valid = stats_valid.rmse_benchmark .- stats_valid.rmse_model
srcc_calib = stats_calib.srcc
srcc_valid = stats_valid.srcc

valid_idx = [
    findfirst(dom_gpkg.RME_UNIQUE_ID .== vid) for vid in VALIDATION_STORE.ltmp_unique_ids
]
calib_idx = [
    findfirst(dom_gpkg.RME_UNIQUE_ID .== vid) for vid in CALIBRATION_STORE.ltmp_unique_ids
]

across_valid = across[valid_idx]
across_calib = across[calib_idx]

along_valid = along[valid_idx]
along_calib = along[calib_idx]

using Bootstrap
n_boot = 1000

corr_boot = x -> corspearman(x[:, 1], x[:, 2])
bs = BalancedSampling(n_boot)
cil = 0.95

# * Along
Δrmse_c_along_boot = bootstrap(corr_boot, hcat(along_calib, Δrmse_calib), bs)
confint_Δrmse_c_along_boot =
    round.(confint(Δrmse_c_along_boot, BasicConfInt(cil))..., digits=2)

Δrmse_v_along_boot = bootstrap(corr_boot, hcat(along_valid, Δrmse_valid), bs)
confint_Δrmse_v_along_boot =
    round.(confint(Δrmse_v_along_boot, BasicConfInt(cil))..., digits=2)

srcc_c_along_boot = bootstrap(corr_boot, hcat(along_calib, srcc_calib), bs)
confint_srcc_c_along_boot =
    round.(confint(srcc_c_along_boot, BasicConfInt(cil))..., digits=2)

srcc_v_along_boot = bootstrap(corr_boot, hcat(along_valid, srcc_valid), bs)
confint_srcc_v_along_boot =
    round.(confint(srcc_v_along_boot, BasicConfInt(cil))..., digits=2)

# * Across
Δrmse_c_across_boot = bootstrap(corr_boot, hcat(across_calib, Δrmse_calib), bs)
confint_Δrmse_c_across_boot =
    round.(confint(Δrmse_c_across_boot, BasicConfInt(cil))..., digits=2)

Δrmse_v_across_boot = bootstrap(corr_boot, hcat(across_valid, Δrmse_valid), bs)
confint_Δrmse_v_across_boot =
    round.(confint(Δrmse_v_across_boot, BasicConfInt(cil))..., digits=2)

srcc_c_across_boot = bootstrap(corr_boot, hcat(across_calib, srcc_calib), bs)
confint_srcc_c_across_boot =
    round.(confint(srcc_c_across_boot, BasicConfInt(cil))..., digits=2)

srcc_v_across_boot = bootstrap(corr_boot, hcat(across_valid, srcc_valid), bs)
confint_srcc_v_across_boot =
    round.(confint(srcc_v_across_boot, BasicConfInt(cil))..., digits=2)

# * Maximum temperature
max_temps_valid = [maximum(dom.dhw_scens[locs=vid, scenarios=1]) for vid in valid_idx]
max_temps_calib = [maximum(dom.dhw_scens[locs=vid, scenarios=1]) for vid in calib_idx]

Δrmse_c_temp_boot = bootstrap(corr_boot, hcat(max_temps_calib, Δrmse_calib), bs)
confint_Δrmse_c_temp_boot =
    round.(confint(Δrmse_c_temp_boot, BasicConfInt(cil))..., digits=2)

Δrmse_v_temp_boot = bootstrap(corr_boot, hcat(max_temps_valid, Δrmse_valid), bs)
confint_Δrmse_v_temp_boot =
    round.(confint(Δrmse_v_temp_boot, BasicConfInt(cil))..., digits=2)

srcc_c_temp_boot = bootstrap(corr_boot, hcat(max_temps_calib, srcc_calib), bs)
confint_srcc_c_temp_boot = round.(confint(srcc_c_temp_boot, BasicConfInt(cil))..., digits=2)

srcc_v_temp_boot = bootstrap(corr_boot, hcat(max_temps_valid, srcc_valid), bs)
confint_srcc_v_temp_boot = round.(confint(srcc_v_temp_boot, BasicConfInt(cil))..., digits=2)



using Bootstrap

# * Bootstrap setup
n_boot = 1000
bs = BalancedSampling(n_boot)
cil = 0.95

# * Bootstrapped performance metrics aggregates

# ** Calib

stats_calib = collect_error_stats(rs_raw.raw; observations=CALIBRATION_STORE)

rmse_model_c = stats_calib.rmse_model
rmse_benchmark_c = stats_calib.rmse_benchmark
Δrmse_c = rmse_benchmark_c .- rmse_model_c
srcc_model_c = stats_calib.srcc

# median_rmse_c_boot = bootstrap(median, rmse_model_c, bs)
# confint_rmse_c_boot = round.(confint(median_rmse_c_boot, BasicConfInt(cil))..., digits=3)

median_Δrmse_c_boot = bootstrap(median, Δrmse_c, bs)
confint_Δrmse_c_boot = round.(confint(median_Δrmse_c_boot, BasicConfInt(cil))..., digits=2)

median_srcc_c_boot = bootstrap(median, srcc_model_c, bs)
confint_srcc_c_boot = round.(confint(median_srcc_c_boot, BasicConfInt(cil))..., digits=2)

# ** Valid
stats_valid = collect_error_stats(rs_raw.raw; observations=VALIDATION_STORE)
rmse_model_v = stats_valid.rmse_model
rmse_benchmark_v = stats_valid.rmse_benchmark
Δrmse_v = rmse_benchmark_v .- rmse_model_v
srcc_model_v = stats_valid.srcc

# mean_rmse_v_boot = bootstrap(mean, rmse_model_v, bs)
# confint_rmse_v_boot = round.(confint(mean_rmse_v_boot, BasicConfInt(cil))..., digits=3)

mean_Δrmse_v_boot = bootstrap(mean, Δrmse_v, bs)
confint_Δrmse_v_boot = round.(confint(mean_Δrmse_v_boot, BasicConfInt(cil))..., digits=2)

mean_srcc_v_boot = bootstrap(mean, srcc_model_v, bs)
confint_srcc_v_boot = round.(confint(mean_srcc_v_boot, BasicConfInt(cil))..., digits=2)
