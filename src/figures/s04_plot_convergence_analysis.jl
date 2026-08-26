# Figure S4: convergence analysis (Shapley effect cumulative sum vs model cumulative
# variance) for each DHW range and metric. Reads the committed
# outputs/sensitivity_analysis_convergence.parq and writes figures/S04_convergence_analysis.png.
#
# Plotting code ported from Analysis_CoralBlox_Shapley-Effect's src/plots/convergence.jl.
using Parquet2, DataFrames
using YAXArrays

include("./_sensitivity_analysis_helpers.jl")

const OPTS_TYPE = Dict{Symbol,Any}
const OPTS_DEFAULT = Dict{Symbol,Any}()

sa_repo_root = dirname(dirname(@__DIR__))
convergence_path = joinpath(sa_repo_root, "outputs", "sensitivity_analysis_convergence.parq")
convergence_df = DataFrame(Parquet2.Dataset(convergence_path))

sa_metrics = unique(convergence_df.metric)
sa_dhw_ranges = unique(convergence_df.dhw_range)
sa_n_samples = maximum(convergence_df.n_samples)

se_cs_data = zeros(Float64, sa_n_samples, length(sa_metrics), length(sa_dhw_ranges))
out_cv_data = zeros(Float64, sa_n_samples, length(sa_metrics), length(sa_dhw_ranges))
metric_idx = Dict(m => i for (i, m) in enumerate(sa_metrics))
dhw_idx = Dict(d => i for (i, d) in enumerate(sa_dhw_ranges))
for row in eachrow(convergence_df)
    i_m, i_d = metric_idx[row.metric], dhw_idx[row.dhw_range]
    se_cs_data[row.n_samples, i_m, i_d] = row.cum_se_sum
    out_cv_data[row.n_samples, i_m, i_d] = row.cum_variance
end

axlist = (
    Dim{:samples}(1:sa_n_samples),
    Dim{:metrics}(sa_metrics),
    Dim{:dhw_ranges}(sa_dhw_ranges),
)
se_cs = YAXArray(axlist, se_cs_data)
out_cv = YAXArray(axlist, out_cv_data)

function plot_convergence(
    Φ_cum::YAXArray{Float64,3},
    m_results_var_cum::YAXArray{Float64,3};
    metric_by_dhw::Bool=true,
    fig_opts::OPTS_TYPE=OPTS_DEFAULT,
    axis_opts::OPTS_TYPE=OPTS_DEFAULT,
    opts::OPTS_TYPE=OPTS_DEFAULT
)::Figure
    fig_size = pop!(fig_opts, :size, (1600, 1200))
    fig = Figure(; size=fig_size, fig_opts...)

    g = fig[1, 1] = GridLayout()

    plot_convergence!(
        g, Φ_cum, m_results_var_cum;
        metric_by_dhw=metric_by_dhw, axis_opts=axis_opts, opts=opts
    )
    legend_convergence!(fig[end+1, :])

    return fig
end
function plot_convergence!(
    g::Union{GridLayout,GridPosition},
    Φ_cum::YAXArray{Float64,3},
    m_results_var_cum::YAXArray{Float64,3};
    metric_by_dhw::Bool=true,
    axis_opts::OPTS_TYPE=OPTS_DEFAULT,
    opts::OPTS_TYPE=OPTS_DEFAULT
)::Nothing
    dhw_ranges = Vector{String}(Φ_cum.dhw_ranges.val)
    metrics = Vector{String}(Φ_cum.metrics.val)

    _dhw_labels = dhw_labels(dhw_ranges)
    metric_labels = _metric_readable[Symbol.(metrics)]

    for (idx_dhw, dhw_range) in enumerate(dhw_ranges)
        for (idx_metric, metric) in enumerate(metrics)
            plot_coord = metric_by_dhw ? [idx_metric + 1, idx_dhw] : [idx_dhw + 1, idx_metric]
            render_ylabel = plot_coord[2] == 1
            base_ylabel = metric_by_dhw ? metric_labels[idx_metric] : _dhw_labels[idx_dhw]
            ylabel = render_ylabel ? base_ylabel : ""
            plot_convergence!(
                g[plot_coord...],
                Φ_cum[:, idx_metric, idx_dhw],
                m_results_var_cum[:, idx_metric, idx_dhw],
                axis_opts=Dict{Symbol,Any}(
                    :title => "",
                    :xscale => log10,
                    :ylabel => ylabel
                )
            )
        end
    end

    for (idx, val) in enumerate(metric_by_dhw ? _dhw_labels : metric_labels)
        Label(g[1, idx], val, fontsize=20, tellwidth=false)
    end
    Label(g[0, :], "Convergence analysis", fontsize=26)

    return nothing
end
function plot_convergence!(
    g::Union{GridLayout,GridPosition},
    Φ_cum::YAXArray{Float64,1},
    m_results_var_cum::YAXArray{Float64,1};
    axis_opts::OPTS_TYPE=OPTS_DEFAULT,
    opts::OPTS_TYPE=OPTS_DEFAULT,
)::Nothing
    get!(axis_opts, :title, "Analysis of convergence - Model Variance vs Sum of SE")
    get!(axis_opts, :xlabel, "N of samples")

    ax = Axis(g; axis_opts...)
    plot_convergence!(ax, Φ_cum, m_results_var_cum; opts=opts)

    return nothing
end
function plot_convergence!(
    ax::Axis,
    Φ_cum::YAXArray{Float64,1},
    m_results_var_cum::YAXArray{Float64,1};
    opts::OPTS_TYPE=OPTS_DEFAULT,
)::Nothing
    ms = get(opts, :markersize, 10)
    colors = get(opts, :colors, [:blue, :red])
    markers = get(opts, :markers, [:vline, :hline])

    scatter!(ax, collect(Φ_cum), color=colors[1], markersize=ms, marker=markers[1])
    scatter!(ax, collect(m_results_var_cum), color=colors[2], markersize=ms, marker=markers[2])

    return nothing
end

function legend_convergence!(gp::GridPosition; opts=Dict(), legend_opts=Dict())::Nothing
    colors = get(opts, :colors, [:blue, :red])
    markers = get(opts, :markers, (:vline, :hline))
    legend_elements = [MarkerElement(color=c, marker=m, markersize=20) for (c, m) in zip(colors, markers)]
    legend_labels = pop!(
        legend_opts,
        :labels,
        ["Shapley Effects cumulative sum", "Model cumulative variance"]
    )
    get!(legend_opts, :orientation, :horizontal)

    Legend(gp, legend_elements, legend_labels; legend_opts...)

    return nothing
end

fig_convergence = plot_convergence(
    se_cs,
    out_cv;
    fig_opts=Dict{Symbol,Any}(:size => (1400, 800)),
)

save(fig_path * "/S04_convergence_analysis.png", fig_convergence; px_per_unit=(300 / inch))
