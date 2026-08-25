# * Reef groups scale
# * Spatial Grouping
spatial_groups = unique(domain_gpkg.CB_CALIB_GROUPS)
spatial_group_masks = [domain_gpkg.CB_CALIB_GROUPS .== g for g in spatial_groups]

spatial_group_stats_calib = region_stats(
    Symbol.("Group " .* string.(spatial_groups)),
    spatial_group_masks,
    rs_raw.raw,
    dom;
    observations=CALIBRATION_STORE
)
spatial_group_stats_test = region_stats(
    Symbol.("Group " .* string.(spatial_groups)),
    spatial_group_masks,
    rs_raw.raw,
    dom;
    observations=TEST_STORE
)

# Plot just test or calib.
data = [spatial_group_stats_calib, spatial_group_stats_test]
reef_group_type = ["calibration", "test"]

xticks_labels = string.(START_YEAR:END_YEAR)
year_labels = string.(Base.union(collect(START_YEAR:5:END_YEAR), [END_YEAR]))
xticks_labels[xticks_labels.∉Ref(year_labels)] .= ""
xticks = (START_YEAR:END_YEAR, xticks_labels)

yticknumbers = collect(0.0:0.2:1.0)
yticktext = getindex.(split.(string.(round.(yticknumbers .* 100)), "."), 1) .* "%"
ytick_labels = (yticknumbers, yticktext)

GeoMakie.GO.simplify.(geometries, ratio=0.5)

fig_base_number = 2
for (idx_d, d) in enumerate(data)
    keys_sort = sortperm(collect(parse.(Int, getindex.(split.(string.(keys(d)), " "), 2))))

    fig_reef_groups = plot_regional_comparison(
        d,
        keys(d)[keys_sort];
        opts=Dict{Symbol,Any}(
            :show_title => false,
            :titlesize => 11pt,
            :textlabelsize => 9pt,
            :textlabelbackground => "#ededeb",
            :showtextlabel => false
        ),
        fig_opts=Dict{Symbol,Any}(:size => (650, 600)),
        axis_opts=Dict{Symbol,Any}(
            :titlesize => 9pt,
            :xlabelsize => 9pt,
            :ylabelsize => 9pt,
            :xticklabelsize => 9pt,
            :yticklabelsize => 9pt,
            :xticklabelrotation => 0,
            :xticks => xticks,
            :yticks => ytick_labels,
            :titlealign => :left,
            :xgridvisible => false,
            :ygridvisible => false
        ),
        legend_opts=Dict{Symbol,Any}(:labelsize => 9pt, :framevisible => false),
    )

    filename = "0$(fig_base_number+idx_d)_reef_groups_$(reef_group_type[idx_d])"

    save(
        fig_path * "/$filename.png",
        fig_reef_groups;
        px_per_unit=(300 / inch)
    )
end
