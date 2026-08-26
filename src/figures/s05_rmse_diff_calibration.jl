isdefined(Main, :fig_path) || include(joinpath(@__DIR__, "..", "common.jl"))
ensure_domain_context!()
isdefined(Main, :plot_bootstrap_metric_scatter) || include(joinpath(@__DIR__, "_bootstrap_metric_scatter.jl"))

fig_rmse_diff_calibration = plot_bootstrap_metric_scatter(
    c_rmse_stats.diff, c_rmse_stats.ci_lo, c_rmse_stats.ci_hi, c_rmse_stats.block_eligible,
    c_rmse_stats.median, c_rmse_stats.median_lo, c_rmse_stats.median_hi, c_reef_ids;
    title_main="Benchmark − Model (RMSE)", title_sub="Calibration data",
    ylabel="RMSE Difference", metric_label="RMSE Diff",
)

save(fig_path * "/S05_rmse_diff_calibration.png", fig_rmse_diff_calibration; px_per_unit=(300 / inch))
