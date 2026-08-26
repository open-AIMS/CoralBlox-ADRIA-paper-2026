# Manual entry point (NOT included by main.jl): reads the raw per-sample SA results from
# the EXTERNAL directory configured via config.toml's [sensitivity_analysis].raw_data_dir,
# computes Shapley effects/convergence diagnostics, and writes the two small tidy Parquet
# files this repo commits to git (outputs/sensitivity_analysis_shapley_effects.parq and
# outputs/sensitivity_analysis_convergence.parq).
#
#   julia --project=. src/sensitivity_analysis/02_aggregate_results.jl
#
# Merges Analysis_CoralBlox_Shapley-Effect's src/02_a_result_loading.jl (find results on
# disk, load into YAXArrays) and src/02_b_process_data.jl (cum_var/cum_se_sum/
# shapley_effects/group_factors) into a single script, since both stages exist only to feed
# the aggregation below - there is no reason for this repo to keep them separate scripts.
using Parquet2, DataFrames
using TOML
using YAXArrays
using SAShE
using Statistics

const SRC_DIR = @__DIR__
isdefined(@__MODULE__, :SAConfig) || include(joinpath(SRC_DIR, "common.jl"))

CONFIG_PATH = joinpath(dirname(dirname(SRC_DIR)), "config.toml")
CONFIG::Dict{String,Any} = TOML.parsefile(CONFIG_PATH)
SA_CONFIG_SECTION = CONFIG["sensitivity_analysis"]

results_dir = SA_CONFIG_SECTION["raw_data_dir"]
sa_config = SAConfig()

# Folder names are "dhw_<lo>_<hi>__<n_samples>__<metric>" (see dhw_range_label), but the
# regex below - unchanged from Analysis_CoralBlox_Shapley-Effect's 02_a_result_loading.jl -
# captures the range without its "dhw_" prefix, so DHW_RANGES is stripped to match.
DHW_RANGES = [dhw_range_label(r)[(length("dhw_")+1):end] for r in sa_config.dhw_ranges]
N_DHW_RANGES = length(DHW_RANGES)

# Result folders are named dhw_<lo>_<hi>__<n_samples>__<metric>. Everything except the
# DHW ranges above is read off what is on disk rather than assumed.
_result_dirs = filter(
    name -> isdir(joinpath(results_dir, name)) && !isnothing(match(r"^dhw_(.+)__(\d+)__(.+)$", name)),
    readdir(results_dir)
)
_parsed = map(_result_dirs) do name
    matched = match(r"^dhw_(.+)__(\d+)__(.+)$", name)
    (name=name, dhw_range=matched[1], n_samples=parse(Int64, matched[2]), metric=matched[3])
end
_found = filter(e -> e.dhw_range in DHW_RANGES, _parsed)

isempty(_found) && error("No results for $(join(DHW_RANGES, ", ")) in $(results_dir)")

_n_samples_found = unique(getproperty.(_found, :n_samples))
length(_n_samples_found) == 1 || error(
    "$(results_dir) holds results for several sample sizes ($(join(sort(_n_samples_found), ", "))). " *
    "Keep only one."
)
N_SAMPLES::Int64 = _n_samples_found[1]

# Every DHW range must be present: the result arrays are dense, so a missing range has no
# representation
_dirs_by_range = Dict(r => filter(e -> e.dhw_range == r, _found) for r in DHW_RANGES)
_missing_ranges = filter(r -> isempty(_dirs_by_range[r]), DHW_RANGES)
isempty(_missing_ranges) || error(
    "No results for DHW range(s) $(join(_missing_ranges, ", ")) in $(results_dir). " *
    "Run 01_run_sa.jl for them first."
)

_missing_metadata = filter(e -> !isfile(joinpath(results_dir, e.name, SA_METADATA_FILE)), _found)
isempty(_missing_metadata) || error(
    "Missing $(SA_METADATA_FILE) in: $(join(getproperty.(_missing_metadata, :name), ", ")). " *
    "Re-run 01_run_sa.jl for those ranges."
)

_metadata_of(dhw_range::String) = TOML.parsefile(
    joinpath(results_dir, first(_dirs_by_range[dhw_range]).name, SA_METADATA_FILE)
)

METRICS = Vector{String}(_metadata_of(DHW_RANGES[1])["config"]["metrics"])
N_METRICS = length(METRICS)

_incomplete = [
    "$(r) [$(join(setdiff(METRICS, getproperty.(_dirs_by_range[r], :metric)), ", "))]"
    for r in DHW_RANGES if !isempty(setdiff(METRICS, getproperty.(_dirs_by_range[r], :metric)))
]
isempty(_incomplete) || error("Missing metric results for: $(join(_incomplete, "; "))")

report_provenance([
    (dhw_range=parse.(Int64, split(r, "_")), metadata=_metadata_of(r)) for r in DHW_RANGES
])

@info "Loading $(N_DHW_RANGES) DHW ranges x $(N_METRICS) metrics " *
      "($(N_SAMPLES) samples) from $(results_dir)"

metric_path(metric::String, dhw_range::String) = joinpath(results_dir, "dhw_$(dhw_range)__$(N_SAMPLES)__$(metric)")
result_path(metric::String, dhw_range::String, filename::String) = joinpath(metric_path(metric, dhw_range), filename)

# * Load metric results
m_results_df(metric::String, dhw_range::String) = DataFrame(Parquet2.Dataset(result_path(metric, dhw_range, "m_results.parq")))
m_results(metric::String, dhw_range::String) = dropdims(Matrix(m_results_df(metric, dhw_range)), dims=2)

function outcomes(;
    metrics::Vector{String}=METRICS,
    dhw_ranges::Vector{String}=DHW_RANGES,
    n_samples::Int64=N_SAMPLES
)::YAXArray{Float64,3}
    n_metrics = length(metrics)
    n_dhw_ranges = length(dhw_ranges)

    outcomes = zeros(n_samples, n_metrics, n_dhw_ranges)
    for (idx_range, dhw_range) in enumerate(dhw_ranges)
        for (idx_metric, metric) in enumerate(metrics)
            outcomes[:, idx_metric, idx_range] .= m_results(metric, dhw_range)
        end
    end

    ax_list = (Dim{:samples}(1:n_samples), Dim{:metrics}(metrics), Dim{:dhw_ranges}(dhw_ranges))
    return YAXArray(ax_list, outcomes)
end

# * Load Shapley Effect increments
ϕ_df(metric::String, dhw_range::String) = DataFrame(Parquet2.Dataset(result_path(metric, dhw_range, "se_increments.parq")))

# * Load Shapley Effect squared increments (used to calculate confints)
ϕ²_df(metric::String, dhw_range::String) = DataFrame(Parquet2.Dataset(result_path(metric, dhw_range, "se2_increments.parq")))

function load_shapley_increments(;
    metrics=METRICS,
    dhw_ranges=DHW_RANGES,
    n_samples=N_SAMPLES,
    squared::Bool=false
)::YAXArray{Float64,4}
    load_fn = squared ? ϕ²_df : ϕ_df
    factors = names(ϕ_df(metrics[1], dhw_ranges[1]))
    n_factors = length(factors)
    n_metrics = length(metrics)
    n_dhw_ranges = length(dhw_ranges)

    se = zeros(n_samples, n_factors, n_metrics, n_dhw_ranges)
    for (idx_range, dhw_range) in enumerate(dhw_ranges)
        for (idx_metric, metric) in enumerate(metrics)
            se[:, :, idx_metric, idx_range] .= Matrix(load_fn(metric, dhw_range))
        end
    end
    ax_list = (
        Dim{:samples}(1:n_samples),
        Dim{:factors}(factors),
        Dim{:metrics}(metrics),
        Dim{:dhw_ranges}(dhw_ranges)
    )
    return YAXArray(ax_list, se)
end

# * Cumulative diagnostics (Analysis_CoralBlox_Shapley-Effect's 02_b_process_data.jl)
function cum_var(m_outcomes::YAXArray{Float64,3})
    samples, metrics, dhw_ranges = m_outcomes.axes
    n_samples, n_metrics, n_dhw_ranges = size(m_outcomes)

    m_results_var_cum = zeros(n_samples, n_metrics, n_dhw_ranges)
    for (idx_range, dhw_range) in enumerate(dhw_ranges)
        for (idx_metric, metric) in enumerate(metrics)
            target_outcomes = m_outcomes[metrics=At(metric), dhw_ranges=At(dhw_range)]
            m_results_var_cum[:, idx_metric, idx_range] .= map(x -> var(target_outcomes[1:x]), 1:N_SAMPLES)
        end
    end

    # Replace first element (which will always be NaN) by 0
    m_results_var_cum[1, :, :] .= 0.0
    return YAXArray(m_outcomes.axes, m_results_var_cum)
end

"""
    cum_se_sum(se::YAXArray{Float64,4})

The partial sum of all params' Shapley Effects after each sample is added.
If the Sensitivty Analysis has converged, it should approach m_results variance as more
samples are added.
"""
function cum_se_sum(se::YAXArray{Float64,4})
    n_samples, _, n_metrics, n_dhw_ranges = size(se)
    se_sum = dropdims(sum(se, dims=:factors), dims=:factors)
    scaling_factors = (n_samples ./ (1:n_samples))
    return YAXArray(se.axes[[1, 3, 4]], cumsum(se_sum; dims=:samples) .* scaling_factors)
end

function shapley_effects(se_increments::YAXArray{Float64,4}, se_increments_2::YAXArray{Float64,4})
    factors, metrics, dhw_ranges = Vector{String}.(getproperty.(se_increments.axes[2:end], :val))
    type = ["value", "lower_bound", "upper_bound"]

    # Lower bound, Shapley effect and upper bound for each factor, metric and dhw_range
    se = zeros(Float64, length(type), length(factors), length(metrics), length(dhw_ranges))

    for (idx_metric, metric) in enumerate(metrics)
        for (idx_dhw, dhw_range) in enumerate(dhw_ranges)
            t_se = collect(dropdims(
                se_increments[metrics=At([metric]), dhw_ranges=At([dhw_range])],
                dims=(:metrics, :dhw_ranges)
            )')
            t_se2 = collect(dropdims(
                se_increments_2[metrics=At([metric]), dhw_ranges=At([dhw_range])],
                dims=(:metrics, :dhw_ranges)
            )')

            se[:, :, idx_metric, idx_dhw] .= hcat(SAShE.shapley_effects(t_se, t_se2;)...)'
        end
    end

    ax_list = (Dim{:type}(type), Dim{:factors}(factors), Dim{:metrics}(metrics), Dim{:dhw_ranges}(dhw_ranges))

    return YAXArray(ax_list, se)
end

function group_factors(se::YAXArray{Float64,4}, to_group::Vector{String})
    _, _, metrics, dhw_ranges = se.axes

    return_se = deepcopy(se)
    tmp_se = zeros(Float64, 3, length(to_group), length(metrics), length(dhw_ranges))
    for (idx_group, group) in enumerate(to_group)
        g_factors = collect(return_se.factors.val)
        group_mask = occursin.(group, g_factors)

        g_val = return_se[type=At("value"), factors=At(g_factors[group_mask])]
        g_val = dropdims(sum(g_val, dims=:factors), dims=:factors)

        g_lb = return_se[type=At("lower_bound"), factors=At(g_factors[group_mask])]
        g_ub = return_se[type=At("upper_bound"), factors=At(g_factors[group_mask])]

        g_σ = (g_ub .- g_lb) ./ 3.92

        g_std = sqrt.(dropdims(sum(g_σ .^ 2, dims=:factors), dims=:factors))
        g_moe = 1.96 .* g_std

        tmp_se[1, idx_group, :, :] .= g_val
        tmp_se[2, idx_group, :, :] .= g_val .- g_moe
        tmp_se[3, idx_group, :, :] .= g_val .+ g_moe

        # Remove grouped factors from return_se
        return_se = return_se[factors=At(g_factors[.!group_mask])]
    end

    axlist = (
        Dim{:type}(["value", "lower_bound", "upper_bound"]),
        Dim{:factors}("group_" .* to_group),
        Dim{:metrics}(collect(metrics.val)),
        Dim{:dhw_ranges}(collect(dhw_ranges.val)),
    )
    groups_se = YAXArray(axlist, tmp_se)

    return cat(return_se, groups_se, dims=:factors)
end

# * Run the aggregation
se_increments = load_shapley_increments(;)
se_increments_2 = load_shapley_increments(; squared=true)
se_cs = cum_se_sum(se_increments)
out_cv = cum_var(outcomes(;))

se = shapley_effects(se_increments, se_increments_2)
factors_to_group = [
    "mean_colony_diameter_m",
    "linear_extension",
    "mb_rate",
    "dist_mean",
    "dist_std",
    "midpoint",
    "height",
    "steepness",
    "eff_dhw"
]
g_se = group_factors(se, factors_to_group)

# * Tidy long-format Shapley effects table (post group_factors collapsing)
factors_g, metrics_g, dhw_ranges_g = Vector{String}.(getproperty.(g_se.axes[2:end], :val))
val_arr = g_se[type=At("value")]
lb_arr = g_se[type=At("lower_bound")]
ub_arr = g_se[type=At("upper_bound")]

shapley_rows = NamedTuple[]
for (idx_dhw, dhw_range) in enumerate(dhw_ranges_g)
    for (idx_metric, metric) in enumerate(metrics_g)
        for (idx_factor, factor) in enumerate(factors_g)
            push!(shapley_rows, (
                factor=factor,
                metric=metric,
                dhw_range=dhw_range,
                se_value=val_arr[idx_factor, idx_metric, idx_dhw],
                se_lower=lb_arr[idx_factor, idx_metric, idx_dhw],
                se_upper=ub_arr[idx_factor, idx_metric, idx_dhw],
            ))
        end
    end
end
shapley_effects_df = DataFrame(shapley_rows)

# * Tidy long-format convergence table
metrics_c = Vector{String}(se_cs.metrics.val)
dhw_ranges_c = Vector{String}(se_cs.dhw_ranges.val)

convergence_rows = NamedTuple[]
for (idx_dhw, dhw_range) in enumerate(dhw_ranges_c)
    for (idx_metric, metric) in enumerate(metrics_c)
        for n in 1:N_SAMPLES
            push!(convergence_rows, (
                n_samples=n,
                metric=metric,
                dhw_range=dhw_range,
                cum_se_sum=se_cs[n, idx_metric, idx_dhw],
                cum_variance=out_cv[n, idx_metric, idx_dhw],
            ))
        end
    end
end
convergence_df = DataFrame(convergence_rows)

outputs_dir = joinpath(dirname(dirname(SRC_DIR)), "outputs")
mkpath(outputs_dir)

shapley_effects_path = joinpath(outputs_dir, "sensitivity_analysis_shapley_effects.parq")
convergence_path = joinpath(outputs_dir, "sensitivity_analysis_convergence.parq")

Parquet2.writefile(shapley_effects_path, shapley_effects_df)
Parquet2.writefile(convergence_path, convergence_df)

@info "Wrote $(shapley_effects_path)"
@info "Wrote $(convergence_path)"
