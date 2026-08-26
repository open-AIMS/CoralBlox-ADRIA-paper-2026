isdefined(Main, :fig_path) || include(joinpath(@__DIR__, "..", "common.jl"))
ensure_domain_context!()
isdefined(Main, :plot_bootstrap_metric_scatter) || include(joinpath(@__DIR__, "_bootstrap_metric_scatter.jl"))

fig_srcc_calibration = plot_bootstrap_metric_scatter(
    c_corr_stats.corr, c_corr_stats.ci_lo, c_corr_stats.ci_hi, c_corr_stats.block_eligible,
    c_corr_stats.median, c_corr_stats.median_lo, c_corr_stats.median_hi, c_reef_ids;
    title_main="SRCC", title_sub="Calibration data", ylabel="SRCC", metric_label="SRCC",
)

save(fig_path * "/S07_srcc_calibration.png", fig_srcc_calibration; px_per_unit=(300 / inch))
