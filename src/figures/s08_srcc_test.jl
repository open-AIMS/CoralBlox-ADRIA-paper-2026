fig_srcc_test = plot_bootstrap_metric_scatter(
    t_corr_stats.corr, t_corr_stats.ci_lo, t_corr_stats.ci_hi, t_corr_stats.block_eligible,
    t_corr_stats.median, t_corr_stats.median_lo, t_corr_stats.median_hi, t_reef_ids;
    title_main="SRCC", title_sub="Test data", ylabel="SRCC", metric_label="SRCC",
)

save(fig_path * "/S08_srcc_test.png", fig_srcc_test; px_per_unit=(300 / inch))
