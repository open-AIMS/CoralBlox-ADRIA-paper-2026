fig_rmse_diff_test = plot_bootstrap_metric_scatter(
    t_rmse_stats.diff, t_rmse_stats.ci_lo, t_rmse_stats.ci_hi, t_rmse_stats.block_eligible,
    t_rmse_stats.median, t_rmse_stats.median_lo, t_rmse_stats.median_hi, t_reef_ids;
    title_main="Benchmark − Model (RMSE)", title_sub="Test data",
    ylabel="RMSE Difference", metric_label="RMSE Diff",
)

save(fig_path * "/S06_rmse_diff_test.png", fig_rmse_diff_test; px_per_unit=(300 / inch))
