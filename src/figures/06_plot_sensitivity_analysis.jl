isdefined(Main, :fig_path) || include(joinpath(@__DIR__, "..", "common.jl"))

# Figure 6: normalized Shapley effects for driving factors, per metric and DHW range.
# Reads the committed outputs/sensitivity_analysis_shapley_effects.parq (already collapsed
# via 02_aggregate_results.jl's group_factors) and writes figures/06_sensitivity_analysis.png.
#
# Plotting code ported from Analysis_CoralBlox_Shapley-Effect's src/plots/normalized_se.jl.
using Parquet2, DataFrames
using YAXArrays

include("./_sensitivity_analysis_helpers.jl")

const OPTS_TYPE = Dict{Symbol,Any}
const OPTS_DEFAULT = Dict{Symbol,Any}()

sa_repo_root = dirname(dirname(@__DIR__))
shapley_effects_path = joinpath(sa_repo_root, "outputs", "sensitivity_analysis_shapley_effects.parq")
shapley_effects_df = DataFrame(Parquet2.Dataset(shapley_effects_path))

# * Reconstruct the (type, factors, metrics, dhw_ranges) YAXArray the ported plotting code
# expects, from the tidy long-format table written by 02_aggregate_results.jl.
sa_factors = unique(shapley_effects_df.factor)
sa_metrics = unique(shapley_effects_df.metric)
sa_dhw_ranges = unique(shapley_effects_df.dhw_range)
sa_n_samples = try
    convergence_path = joinpath(sa_repo_root, "outputs", "sensitivity_analysis_convergence.parq")
    maximum(DataFrame(Parquet2.Dataset(convergence_path)).n_samples)
catch
    nothing
end

g_se_data = zeros(Float64, 3, length(sa_factors), length(sa_metrics), length(sa_dhw_ranges))
factor_idx = Dict(f => i for (i, f) in enumerate(sa_factors))
metric_idx = Dict(m => i for (i, m) in enumerate(sa_metrics))
dhw_idx = Dict(d => i for (i, d) in enumerate(sa_dhw_ranges))
for row in eachrow(shapley_effects_df)
    i_f, i_m, i_d = factor_idx[row.factor], metric_idx[row.metric], dhw_idx[row.dhw_range]
    g_se_data[1, i_f, i_m, i_d] = row.se_value
    g_se_data[2, i_f, i_m, i_d] = row.se_lower
    g_se_data[3, i_f, i_m, i_d] = row.se_upper
end
g_se = YAXArray(
    (
        Dim{:type}(["value", "lower_bound", "upper_bound"]),
        Dim{:factors}(sa_factors),
        Dim{:metrics}(sa_metrics),
        Dim{:dhw_ranges}(sa_dhw_ranges),
    ),
    g_se_data
)

function plot_normalized_se(
    shapley_effect::YAXArray{Float64,4};
    metric_by_dhw::Bool=true,
    fig_opts::OPTS_TYPE=OPTS_DEFAULT,
    axis_opts::OPTS_TYPE=OPTS_DEFAULT,
    opts::OPTS_TYPE=OPTS_DEFAULT
)
    fig_size = pop!(fig_opts, :size, (1600, 1200))
    fig = Figure(; size=fig_size, fig_opts...)

    g = fig[1, 1] = GridLayout()
    plot_normalized_se!(g, shapley_effect; metric_by_dhw=metric_by_dhw, axis_opts=axis_opts, opts=opts)

    return fig
end
function plot_normalized_se!(
    g::Union{GridLayout,GridPosition},
    shapley_effect::YAXArray{Float64,4};
    metric_by_dhw::Bool=true,
    axis_opts::OPTS_TYPE=OPTS_DEFAULT,
    opts::OPTS_TYPE=OPTS_DEFAULT
)::Nothing
    factors, metrics, dhw_ranges = Vector{String}.(getproperty.(shapley_effect.axes[2:end], :val))

    _dhw_labels = dhw_labels(dhw_ranges)
    metric_labels = _metric_readable[Symbol.(metrics)]

    _xticks = nothing
    for (idx_dhw, dhw_range) in enumerate(dhw_ranges)
        for (idx_metric, metric) in enumerate(metrics)
            # * Shapley Effects and respective confidence intervals for each factor
            @views t_Φ = shapley_effect[metrics=At(metric), dhw_ranges=At(dhw_range)]
            Φ = t_Φ[type=At("value")]
            Φlb = t_Φ[type=At("lower_bound")]
            Φub = t_Φ[type=At("upper_bound")]

            # * Normalized Shapley Effects for driving factors (above threshold)
            Φ_driv, Φ_driv_lb, Φ_driv_ub, f_driv_names =
                driving_factors(Φ, Φlb, Φub, factors)
            Φ_driv_norm, Φ_driv_lb_norm, Φ_driv_ub_norm =
                normalized_factors(Φ_driv, Φ_driv_lb, Φ_driv_ub)

            plot_coord = metric_by_dhw ? [idx_metric + 1, idx_dhw] : [idx_dhw + 1, idx_metric]

            _xticks = (1:length(Φ_driv_norm), human_readable_factors(f_driv_names))
            _xlabelvisible = (plot_coord[1] == length(metric_by_dhw ? metrics : dhw_ranges) + 1)
            _ylabelvisible = (plot_coord[2] == 1)
            base_ylabel = metric_by_dhw ? metric_labels[idx_metric] : _dhw_labels[idx_dhw]

            # Don't change axis_opts since it's used for all plots but the xticks are different
            _axis_opts = merge(
                Dict{Symbol,Any}(
                    :title => "",
                    :xticks => _xticks,
                    :xticklabelrotation => π / 4,
                    :xlabelvisible => _xlabelvisible,
                    :ylabelvisible => _ylabelvisible,
                    :yticklabelsvisible => _ylabelvisible,
                    :ylabel => base_ylabel
                ),
                axis_opts
            )

            ax = Axis(g[plot_coord...]; _axis_opts...)

            plot_normalized_se!(ax, Φ_driv_norm, Φ_driv_lb_norm, Φ_driv_ub_norm; opts=opts)
        end
    end

    # Panel letters match paper.qmd's Figure 6 caption/in-text references (Figure 6A-E),
    # which are keyed to column position - only meaningful while columns are DHW ranges.
    _panel_letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
    for (idx, val) in enumerate(metric_by_dhw ? _dhw_labels : _xticks)
        col_label_size = get(opts, :col_label_size, HEADER_LABEL_SIZE)
        label = metric_by_dhw ? "($(_panel_letters[idx])) $(val)" : val
        Label(g[1, idx], label, fontsize=col_label_size, tellwidth=false)
    end

    if get(opts, :title_visible, true)
        title_suffix = isnothing(sa_n_samples) ? "" : "\n$(sa_n_samples) samples"
        Label(
            g[0, :],
            "Normalized Shapley Effects for influential factors$(title_suffix)";
            fontsize=get(opts, :title_size, HEADER_LABEL_SIZE), tellwidth=false
        )
    end

    return nothing
end
function plot_normalized_se!(
    ax::Axis, _Φ::Vector{Float64}, _Φlb::Vector{Float64}, _Φub::Vector{Float64};
    opts::OPTS_TYPE=OPTS_DEFAULT
)::Axis
    factor_idx = collect(1:length(_Φ))
    color = get(opts, :color, :blue)
    barplot!(ax, factor_idx, _Φ; color=color)
    errorbars!(ax, factor_idx, _Φ, _Φlb .- _Φub; whiskerwidth=10, color=:black)
    return ax
end
function plot_normalized_se!(
    ax::Axis, _Φ::YAXArray{Float64,1}, _Φlb::YAXArray{Float64,1}, _Φub::YAXArray{Float64,1};
    opts::OPTS_TYPE=OPTS_DEFAULT
)::Axis
    return plot_normalized_se!(ax, _Φ.data, _Φlb.data, _Φub.data; opts=opts)
end

fig_norm_se = plot_normalized_se(
    g_se;
    fig_opts=Dict{Symbol,Any}(:size => (800, 900)),
    axis_opts=Dict{Symbol,Any}(
        :ylabelsize => AXIS_LABEL_SIZE,
        :xticklabelsize => TICK_LABEL_SIZE,
        :yticklabelsize => TICK_LABEL_SIZE,
        :yticks => (0:0.2:1, string.(0:0.2:1)),
        :xticklabelrotation => π / 4,
        :limits => (nothing, (0, 1.1)),
        :xgridvisible => false
    ),
    opts=Dict{Symbol,Any}(
        :title_size => HEADER_LABEL_SIZE,
        :col_label_size => HEADER_LABEL_SIZE,
        :color => "#b52482"
    )
)
Label(fig_norm_se[end+1, :], "Factors"; fontsize=AXIS_LABEL_SIZE, tellwidth=false)

save(fig_path * "/06_sensitivity_analysis.png", fig_norm_se; px_per_unit=(300 / inch))
