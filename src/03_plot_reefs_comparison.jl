# plot_locs = vcat(reefs_sorted_by_srcc[end-4:end][[1,5]], reefs_sorted_by_srcc[1:2])
plot_locs = vcat(reefs_sorted_by_rmse[end-1:end], reefs_sorted_by_rmse[1:2])

single_reef_fig = begin
    plot_locs_idx = [findfirst(TEST_STORE.ltmp_unique_ids .== loc) for loc in plot_locs]
    plot_loc_names = [TEST_STORE.domain_gpkg[TEST_STORE.domain_gpkg.RME_UNIQUE_ID.==l, :cluster_id][1] for l in plot_locs]
    # TEST_STORE.domain_gpkg[TEST_STORE.domain_gpkg.RME_UNIQUE_ID.∈Ref(plot_locs), :cluster_id]

    model_srcc = string.(round.(vcat(test_error_stats.srcc[plot_locs_idx]); digits=2))
    model_rmse = string.(round.(test_error_stats.rmse_model[plot_locs_idx], digits=2))
    benchmark_rmse = string.(round.(test_error_stats.rmse_benchmark[plot_locs_idx], digits=2))

    plot_labels = ["(A) ", "(B) ", "(C) ", "(D) "] .* plot_loc_names .* "\n"

    # print_metrics
    plot_labels = plot_labels .* (
        "RMSE: " .* model_rmse .* " | " .*
        "SRCC: " .* model_srcc)
    @info plot_labels .* "μRMSE:" .* string.(benchmark_rmse)

    plot_positions = [(1, 1), (1, 2), (2, 1), (2, 2)]

    disturbances_path = joinpath(pkgdir(CoralBloxCalib), "datasets", "ltmp_data", "disturbances.nc")
    ltmp_disturbances = open_dataset(disturbances_path).layer

    # ** Plot comparison
    fig = Figure(; size=(750, 650), fontsize=9pt)
    for (i, plot_idx) in enumerate(plot_locs_idx)
        # reef_idx = 1
        target_loc_data = dom.loc_data[dom.loc_data.RME_UNIQUE_ID.==plot_locs[i], :]
        # title = target_loc_data.cluster_id[1]

        plot_location_comparison!(
            fig[plot_positions[i]...],
            rs_raw.raw,
            plot_locs[i],
            dom.dhw_scens[scenarios=1],
            dom.cyclone_mortality_scens[scenarios=1],
            ltmp_disturbances;
            dom=dom,
            opts=Dict{Symbol,Any}(
                :show_ltmp_dist => false,
                :show_model_dist => true,
                :show_benthic_composition => true,
                :show_legends => false,
                :model_vs_obs_markersize => 10,
                :model_vs_obs_linewidth => 2.5,
                :benthic_linewidth => 2.5,
                :model_dist_linewidth => 2.5,
            ),
            axis_opts=Dict{Symbol,Any}(
                :xticklabelsvisible => plot_positions[i][1] == 2,
                :yticklabelsvisible => plot_positions[i][2] == 1,
                :xlabelvisible => plot_positions[i][1] == 2,
                :ylabelvisible => plot_positions[i][2] == 1,
                :model_vs_obs_yticks => ([0, 0.5, 1.0], ["0%", "50%", "100%"]),
                :model_vs_obs_yminorticksvisible => true,
                :model_vs_obs_yminorticks => collect(0.0:0.1:1.0),
                :model_vs_obs_limits => (nothing, (0.0, 1.0)),
                :model_vs_obs_ylabel => "Relative coral cover",
                :model_vs_obs_xticklabelsvisible => false,
                :model_dist_xticklabelsvisible => false,
                :model_dist_yticks => ([0, 5, 10]),
                :model_dist_yminorticksvisible => true,
                :model_dist_yminorticks => collect(0:1:10),
                :model_dist_limits => (nothing, (0.0, 10)),
                :benthic_yticks => ([0, 0.5, 1.0], ["0%", "50%", "100%"]),
                :benthic_yminorticksvisible => true,
                :benthic_yminorticks => collect(0.0:0.1:1.0),
                :benthic_limits => (nothing, (0.0, 1.0)),
                :benthic_ylabel => "Coral composition",
                :xticks => (2008:4:2022, string.(2008:4:2022)),
                :xminorticksvisible => true,
                :xminorticks => collect(2008:2022),
                :ylabelsize => 9pt,
                :xlabelsize => 9pt,
                :xticklabelsize => 9pt,
                :yticklabelsize => 9pt,
                :halign => :left,
                :xgridvisible => false,
                :ygridvisible => false,
            ),
            fig_opts=Dict{Symbol,Any}(
                :titlesize => 9pt,
                :title => plot_labels[i],
                :titlehalign => :left,
                :titlevalign => :bottom,
                :titlefont => :bold
            ),
            observations=TEST_STORE
        )
    end
    rowsize!.(contents(fig.layout), Ref(2), Ref(Relative(2 / 9)))
    rowsize!.(contents(fig.layout), Ref(3), Ref(Relative(3 / 9)))
    fig

    model_vs_obs_legend_els = [
        MarkerElement(color=COLORS[:model_vs_obs_color_obs], marker=:circle, markersize=10),
        LineElement(color=COLORS[:model_vs_obs_color_model], linewidth=2)
    ]

    model_dist_legend_els = [
        LineElement(linewidth=3, color=COLORS[:model_dist_color_dhw], linestyle=:dot),
        LineElement(linewidth=3, color=COLORS[:model_dist_color_dist], linestyle=:dash),
    ]

    benthic_legend_els = taxa_props_legend_elements()
    taxa = String.(ADRIA.functional_group_names())
    taxa_labels = titlecase.(join.(split.(taxa, "_"), " "))

    Legend(
        fig[:, 3],
        [model_vs_obs_legend_els, model_dist_legend_els, benthic_legend_els],
        [
            ["Observed", "Model"],
            ["DHW", "Cyclone/COTS"],
            taxa_labels
        ],
        ["Coral cover", "Disturbances", "Functional groups"];
        halign=:left, valign=:center, labelsize=9pt, titlesize=9pt, labelhalign=:left,
        gridshalign=:left, titlehalign=:left, framevisible=false
    )
    fig
end
save(fig_path * "/05_reefs_comparison.png", single_reef_fig; px_per_unit=(300 / inch))
