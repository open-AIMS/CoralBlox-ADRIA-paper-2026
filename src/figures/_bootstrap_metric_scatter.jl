"""
    plot_bootstrap_metric_scatter(estimate, ci_lo, ci_hi, block_eligible, median_val,
                                   median_lo, median_hi, reef_ids; title_main, title_sub,
                                   ylabel, metric_label)

Per-reef bootstrap-CI metric scatter plot (one dot per reef, sorted by value, with a solid
error bar for block-bootstrap reefs (n≥5 yrs) and a dashed one for iid reefs (n=4 yrs)),
styled to match the rest of this paper's figures: legend below with no border, no
gridlines, reef GBRMPA IDs on the x-axis (rotated), left-aligned title, and a single
consistent font size throughout.

The title is built as three lines: `title_main`, `title_sub` (e.g. "Calibration data"), and
a summary line giving the count/percentage of reefs with a positive point estimate and the
aggregate median with its 95% CI - matching the reference plots this recreates.

Colors are Okabe-Ito (colorblind-safe): blue `#0072B2` / orange `#E69F00` for the two
bootstrap types. The aggregate median uses black rather than Okabe-Ito's bluish-green, since
green sits close to blue for some color-vision deficiencies and this plot already uses blue
for one of the two per-reef series.
"""
function plot_bootstrap_metric_scatter(
    estimate::Vector{Float64},
    ci_lo::Vector{Float64},
    ci_hi::Vector{Float64},
    block_eligible::BitVector,
    median_val::Float64,
    median_lo::Float64,
    median_hi::Float64,
    reef_ids::Vector{String};
    title_main::String,
    title_sub::String,
    ylabel::String,
    metric_label::String,
)::Figure
    order = sortperm(estimate)
    estimate = estimate[order]
    ci_lo = ci_lo[order]
    ci_hi = ci_hi[order]
    block_eligible = block_eligible[order]
    reef_ids = reef_ids[order]

    block_color = "#0072B2"
    iid_color = "#E69F00"
    median_color = "#000000"

    x = collect(1:length(estimate))
    iid_mask = .!block_eligible

    n_eligible = sum(block_eligible)
    n_positive = sum(estimate[block_eligible] .> 0)
    pct_positive = round(100 * n_positive / n_eligible; digits=1)
    summary_line = "# > 0: $n_positive ($(pct_positive)%) | Median: $(trunc(median_val; digits=3))" *
                    " [$(trunc(median_lo; digits=3)), $(trunc(median_hi; digits=3))]"
    title = title_main * "\n" * title_sub * "\n" * summary_line

    fig = Figure(; size=(max(900, 12 * length(x)), 600), fontsize=AXIS_LABEL_SIZE)
    ax = Axis(
        fig[1, 1];
        title=title,
        titlealign=:left,
        titlesize=TITLE_SIZE,
        xlabel="Reef ID",
        ylabel=ylabel,
        xlabelsize=AXIS_LABEL_SIZE,
        ylabelsize=AXIS_LABEL_SIZE,
        xticks=(x, reef_ids),
        xticklabelrotation=pi / 3,
        # Deliberately below TICK_LABEL_SIZE: many crowded, rotated reef ID labels on this
        # axis specifically - the standard size overlaps here.
        xticklabelsize=7pt,
        yticklabelsize=TICK_LABEL_SIZE,
        xgridvisible=false,
        ygridvisible=false,
    )

    hlines!(ax, [0.0]; color=:gray, linestyle=:solid, linewidth=1)

    scatter!(ax, x[block_eligible], estimate[block_eligible]; color=block_color)
    scatter!(ax, x[iid_mask], estimate[iid_mask]; color=iid_color)

    rangebars!(
        ax, x[block_eligible], ci_lo[block_eligible], ci_hi[block_eligible];
        color=block_color, linestyle=:solid
    )
    rangebars!(
        ax, x[iid_mask], ci_lo[iid_mask], ci_hi[iid_mask];
        color=iid_color, linestyle=:dash
    )

    hlines!(ax, [median_val]; color=median_color, linestyle=:solid, linewidth=2)
    hlines!(ax, [median_lo, median_hi]; color=(median_color, 0.6), linestyle=:dash)

    legend_els = [
        MarkerElement(color=block_color, marker=:circle),
        MarkerElement(color=iid_color, marker=:circle),
        LineElement(color=median_color, linestyle=:solid),
    ]
    legend_labels = [
        "$metric_label (block bootstrap, n≥5 yrs)",
        "$metric_label (iid bootstrap, n=4 yrs)",
        "Median [95% CI]",
    ]

    Legend(
        fig[2, 1], legend_els, legend_labels;
        orientation=:horizontal, framevisible=false, labelsize=AXIS_LABEL_SIZE,
        tellwidth=false, tellheight=true
    )
    rowsize!(fig.layout, 2, Auto())

    return fig
end
