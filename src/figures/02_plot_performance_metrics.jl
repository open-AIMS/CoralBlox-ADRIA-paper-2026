isdefined(Main, :fig_path) || include(joinpath(@__DIR__, "..", "common.jl"))
ensure_domain_context!()

"""
    plot_metric_map_ci!(g, metric, significant, geometries, lon_valid, lat_valid; axis_opts, opts)

Same rendering as `CoralBloxCalib.viz.plot_metric_map!`, but reefs whose 95% bootstrap CI
includes zero (`significant[i] == false`) are drawn at reduced opacity (`opts[:alpha_nonsignificant]`,
default 0.25) instead of the normal `opts[:alpha]`, so non-significant per-reef estimates
are visually de-emphasised without being dropped from the map.
"""
function plot_metric_map_ci!(
    g::Union{GridPosition,GridLayout},
    metric::Vector{Float64},
    significant::BitVector,
    geometries::Vector,
    lon_valid::Vector{Float64},
    lat_valid::Vector{Float64};
    axis_opts::Dict{Symbol,Any}=Dict{Symbol,Any}(),
    opts::Dict{Symbol,Any}=Dict{Symbol,Any}(),
)::Nothing
    axis_opts = merge(
        Dict(
            :xlabel => get(axis_opts, :xlabel, "Longitude"),
            :ylabel => get(axis_opts, :ylabel, "Latitude"),
            :title => get(axis_opts, :title, "Benchmark RMSE - Model RMSE"),
            :dest => "+proj=latlong +datum=WGS84",
        ),
        axis_opts
    )
    ax = GeoAxis(g[1, 1], ; axis_opts...)

    poly!(ax, geometries, color=:gray)
    poly!(ax, CoralBloxCalib.viz.GBRMPA_MAINLAND_POLYS, color="#121212")

    max_val, min_val = extrema(metric)
    up_limit = maximum(abs.((max_val, min_val)))
    lower_limit = -up_limit

    colormap = get(opts, :colormap, :bam)
    colorrange = get(opts, :colorrange, (lower_limit, up_limit))
    alpha_significant = get(opts, :alpha, 0.8)
    alpha_nonsignificant = get(opts, :alpha_nonsignificant, 0.25)
    strokewidth = get(opts, :strokewidth, 1)
    strokecolor = get(opts, :strokecolor, (:gray, 0.1))
    markersize = get(opts, :markersize, 35)

    for (sig, alpha) in ((true, alpha_significant), (false, alpha_nonsignificant))
        mask = significant .== sig
        any(mask) || continue

        high_mask = mask .& (metric .> 0)
        low_mask = mask .& (metric .<= 0)

        scatter!(ax, lon_valid[low_mask], lat_valid[low_mask];
            colormap=colormap,
            colorrange=colorrange,
            color=metric[low_mask],
            alpha=alpha,
            marker=:circle,
            strokewidth=strokewidth,
            strokecolor=strokecolor,
            markersize=markersize,
        )

        scatter!(ax, lon_valid[high_mask], lat_valid[high_mask];
            colormap=colormap,
            colorrange=colorrange,
            color=metric[high_mask],
            alpha=alpha,
            marker=:star5,
            strokewidth=strokewidth,
            strokecolor=strokecolor,
            markersize=markersize,
        )
    end

    if get(opts, :colorbar_visible, true)
        colorbar_label = get(opts, :colorbar_label, "Benchmark RMSE - Model RMSE")
        colorbar_ticklabelsize = get(opts, :colorbar_ticklabelsize, TICK_LABEL_SIZE)
        colorbar_ticks = get(opts, :colorbar_ticks, automatic)
        colorbar_vertical = get(opts, :colorbar_vertical, true)
        position = colorbar_vertical ? (1, 2) : (2, 1)
        Colorbar(
            g[position...];
            colorrange=colorrange,
            colormap=colormap,
            ticks=colorbar_ticks,
            label=colorbar_label,
            ticklabelsize=colorbar_ticklabelsize,
            vertical=colorbar_vertical
        )
    end

    return nothing
end

metric_map_fig = begin
    fig = Figure(; size=(550, 650), fontsize=AXIS_LABEL_SIZE)

    markersize = 15
    strokewidth = 0.7
    strokecolor = (:black, 0.4)
    grid_color = RGBAf(0, 0, 0, 0.10)

    min_x, max_x = extrema(c_lon)
    min_x = floor(min_x)
    max_x = ceil(max_x)

    min_y, max_y = extrema(c_lat)
    min_y = floor(min_y) - 1
    max_y = ceil(max_y)

    limits = ((min_x, max_x), (min_y, max_y))

    rmse_colormap = :thermal # :roma
    srcc_colormap = :cool

    srcc_colorrange = (-1, 1)
    srcc_ticks_range = srcc_colorrange[1]:0.5:srcc_colorrange[2]
    srcc_colorbar_ticks = (srcc_ticks_range, string.(srcc_ticks_range))

    rmse_colorrange = (-0.2, 0.2)
    rmse_ticks_range = rmse_colorrange[1]:0.1:rmse_colorrange[2]
    rmse_colorbar_ticks = (rmse_ticks_range, string.(rmse_ticks_range))

    g0 = fig[1, 1:2] = GridLayout()
    g1 = fig[3, 1:2] = GridLayout()
    g11 = g1[1, 1] = GridLayout()
    g12 = g1[1, 2] = GridLayout()
    gr2 = fig[4, 1:2] = GridLayout()
    g21 = gr2[1, 1] = GridLayout()
    g22 = gr2[1, 2] = GridLayout()

    plot_metric_map_ci!(
        g11,
        c_rmse_diffs,
        c_rmse_significant,
        geometries,
        c_lon,
        c_lat;
        axis_opts=Dict(
            :title => "",
            :titlesize => TITLE_SIZE,
            :xlabelsize => AXIS_LABEL_SIZE,
            :ylabelsize => AXIS_LABEL_SIZE,
            :yticks => min_y:1:max_y,
            :yticklabelsize => TICK_LABEL_SIZE,
            :xticklabelsize => TICK_LABEL_SIZE,
            :xgridcolor => grid_color,
            :ygridcolor => grid_color,
            :xgridvisible => false,
            :ygridvisible => false,
            :xticklabelsvisible => false,
            :limits => limits
        ),
        opts=Dict(
            :colorrange => (-0.2, 0.2),
            :colorbar_label => "",
            :colorbar_ticklabelsize => TICK_LABEL_SIZE,
            :colorbar_ticks => rmse_colorbar_ticks,
            :markersize => markersize,
            :alpha => 0.8,
            :strokewidth => strokewidth,
            :strokecolor => strokecolor,
            :colormap => rmse_colormap,
            :colorbar_visible => false,
        )
    )

    # ylims!(g11, (-24, -14))

    plot_metric_map_ci!(
        g12,
        collect(c_srcc_),
        c_srcc_significant,
        geometries,
        c_lon,
        c_lat;
        axis_opts=Dict(
            :title => "",
            :titlesize => TITLE_SIZE,
            :xlabelsize => AXIS_LABEL_SIZE,
            :ylabelsize => AXIS_LABEL_SIZE,
            :yticklabelsize => TICK_LABEL_SIZE,
            :xticklabelsize => TICK_LABEL_SIZE,
            :xgridcolor => grid_color,
            :ygridcolor => grid_color,
            :xgridvisible => false,
            :ygridvisible => false,
            :xticklabelsvisible => false,
            :yticklabelsvisible => false,
            :limits => limits
        ),
        opts=Dict(
            :colorbar_label => "",
            :colorbar_ticklabelsize => TICK_LABEL_SIZE,
            :colorbar_ticks => srcc_colorbar_ticks,
            :markersize => markersize,
            :alpha => 0.6,
            :strokewidth => strokewidth,
            :strokecolor => strokecolor,
            :colormap => srcc_colormap,
            :colorbar_visible => false,
        )
    )

    plot_metric_map_ci!(
        g21,
        t_rmse_diffs,
        t_rmse_significant,
        geometries,
        t_lon,
        t_lat;
        axis_opts=Dict(
            :title => "",
            :titlesize => TITLE_SIZE,
            :xlabelsize => AXIS_LABEL_SIZE,
            :ylabelsize => AXIS_LABEL_SIZE,
            :yticklabelsize => TICK_LABEL_SIZE,
            :xticklabelsize => TICK_LABEL_SIZE,
            :xgridcolor => grid_color,
            :ygridcolor => grid_color,
            :xgridvisible => false,
            :ygridvisible => false,
            :valign => :top,
            :limits => limits
        ),
        opts=Dict(
            :colorrange => rmse_colorrange,
            :colorbar_label => "",
            :colorbar_ticklabelsize => TICK_LABEL_SIZE,
            :colorbar_ticks => rmse_colorbar_ticks,
            :markersize => markersize,
            :alpha => 0.8,
            :strokewidth => strokewidth,
            :strokecolor => strokecolor,
            :colormap => rmse_colormap,
            :colorbar_visible => false,
        )
    )

    plot_metric_map_ci!(
        g22,
        collect(t_srcc_),
        t_srcc_significant,
        geometries,
        t_lon,
        t_lat;
        axis_opts=Dict(
            :title => "",
            :titlesize => TITLE_SIZE,
            :xlabelsize => AXIS_LABEL_SIZE,
            :ylabelsize => AXIS_LABEL_SIZE,
            :yticklabelsize => TICK_LABEL_SIZE,
            :xticklabelsize => TICK_LABEL_SIZE,
            :xgridcolor => grid_color,
            :ygridcolor => grid_color,
            :xgridvisible => false,
            :ygridvisible => false,
            :valign => :top,
            :yticklabelsvisible => false,
            :limits => limits
        ),
        opts=Dict(
            :colormap => srcc_colormap,
            :colorbar_label => "",
            :colorbar_ticklabelsize => TICK_LABEL_SIZE,
            :colorbar_ticks => srcc_colorbar_ticks,
            :markersize => markersize,
            :alpha => 0.6,
            :strokewidth => strokewidth,
            :strokecolor => strokecolor,
            :colorbar_visible => false,
        )
    )

    # Plot compass and N
    cx, cy = max_x - 0.5, max_y - 1.5  # center position
    poly!(
        content(g12[1, 1]),
        Point2f[(cx - 0.20, cy), (cx, cy + 0.7), (cx + 0.20, cy), (cx, cy - 0.3)],
        color=:black
    )
    text!(content(g12[1, 1]), cx, cy + 0.75; text="N", fontsize=15, align=(:center, :bottom), color=:black)

    lon_padding = (0, 0, 0, 25)
    lat_padding = (0, -20, 0, 0)
    left_label_padding = (0, 20, 0, 0)
    top_label_padding = (0, 0, 60, -30)

    gcb1 = g0[1, 1] = GridLayout()
    gcb2 = g0[1, 2] = GridLayout()
    cb_rmse = Colorbar(
        gcb1[1, 1];
        colorrange=rmse_colorrange,
        colormap=rmse_colormap,
        ticks=rmse_colorbar_ticks,
        ticklabelsize=TICK_LABEL_SIZE,
    )
    Label(gcb1[1, 1], "ΔRMSE (Benchmark - Model) ", padding=(0, 0, 60, -30), fontsize=HEADER_LABEL_SIZE, justification=:center, halign=:center)

    cb_srcc = Colorbar(
        gcb2[1, 1];
        colorrange=srcc_colorrange,
        colormap=srcc_colormap,
        ticks=srcc_colorbar_ticks,
        ticklabelsize=TICK_LABEL_SIZE,)
    Label(gcb2[1, 1], "SRCC", padding=(0, 0, 60, -30), fontsize=HEADER_LABEL_SIZE, justification=:center, halign=:center)

    Label(g21[1, 1, Bottom()], "Longitude", padding=lon_padding, fontsize=AXIS_LABEL_SIZE)
    Label(g22[1, 1, Bottom()], "Longitude", padding=lon_padding, fontsize=AXIS_LABEL_SIZE)

    Label(g11[1, 1, Left()], "Latitude", rotation=π / 2, padding=lat_padding, fontsize=AXIS_LABEL_SIZE, tellwidth=false)
    Label(g21[1, 1, Left()], "Latitude", rotation=π / 2, padding=lat_padding, fontsize=AXIS_LABEL_SIZE, tellwidth=false)

    Label(g11[1, 1, Left()], "Calibration reefs", rotation=π / 2, padding=left_label_padding, fontsize=HEADER_LABEL_SIZE,)
    Label(g21[1, 1, Left()], "Test reefs", rotation=π / 2, padding=left_label_padding, fontsize=HEADER_LABEL_SIZE,)

    # Marker-shape legend: star5 = value > 0, circle = value <= 0 (see plot_metric_map_ci!'s
    # high_mask/low_mask split above). Colour is irrelevant to this legend - it only conveys
    # shape - so a neutral grey stands in for the colormap-driven marker colours.
    legend_elements = [
        MarkerElement(marker=:star5, color=:gray20, markersize=15, strokewidth=strokewidth, strokecolor=strokecolor),
        MarkerElement(marker=:circle, color=:gray20, markersize=15, strokewidth=strokewidth, strokecolor=strokecolor),
    ]
    Legend(
        fig[2, 1:2],
        legend_elements,
        ["Value > 0", "Value ≤ 0"];
        orientation=:horizontal,
        framevisible=false,
        labelsize=AXIS_LABEL_SIZE,
        tellheight=true,
        tellwidth=false,
    )

    colgap!(g0, 32)
    colgap!(g1, -60)
    colgap!(gr2, -60)
    rowgap!(fig.layout, 1, 0)
    rowgap!(fig.layout, 2, 0)
    rowgap!(fig.layout, 3, -10)

    cb_srcc.vertical, cb_rmse.vertical = false, false
    cb_srcc.labelvisible, cb_rmse.labelvisible = false, false
    cb_srcc.width, cb_rmse.width = 180, 180

    resize_to_layout!(fig)
    fig
end
save(fig_path * "/02_performance_metrics.png", metric_map_fig; px_per_unit=(300 / inch))
