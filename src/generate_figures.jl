# Generates every figure in the manuscript. Each script guards its own setup (see
# common.jl), so this file is just the include list - run via main.jl, or standalone with
# `julia --project=. src/generate_figures.jl`.
include("./figures/02_plot_performance_metrics.jl")
include("./figures/03_plot_reef_groups.jl")
include("./figures/05_plot_reefs_comparison.jl")
include("./figures/s02_plot_dhw.jl")
include("./figures/s03_effective_dhw_depth_attenuation.jl")
include("./figures/_bootstrap_metric_scatter.jl")
include("./figures/s05_rmse_diff_calibration.jl")
include("./figures/s06_rmse_diff_test.jl")
include("./figures/s07_srcc_calibration.jl")
include("./figures/s08_srcc_test.jl")
include("./figures/06_plot_sensitivity_analysis.jl")
include("./figures/s04_plot_convergence_analysis.jl")
