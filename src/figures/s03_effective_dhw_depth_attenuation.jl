calib_params_ds = open_dataset(CALIB_PARAMS_FN)
κ_base = calib_params_ds.depth_attenuation[1]
mixing_scale = calib_params_ds.depth_attenuation[2]

dhw_surface = 0:0.5:80
depths = [2.0, 5.0, 10.0, 20.0]

fig_eff_dhw = Figure(; size=(800, 600))
ax = Axis(
    fig_eff_dhw[1, 1];
    title="Effective DHW vs surface DHW (η_base=$(round(κ_base; digits=3)), " *
        "η_mix=$(round(mixing_scale; digits=3)))",
    titlesize=TITLE_SIZE,
    xlabel="Surface DHW",
    ylabel="Effective DHW at depth",
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    xticklabelsize=TICK_LABEL_SIZE,
    yticklabelsize=TICK_LABEL_SIZE,
    xgridvisible=false,
    ygridvisible=false
)

lines!(ax, dhw_surface, dhw_surface; color=:black, linestyle=:dot, label="1:1 (surface)")
for depth in depths
    eff_dhw = [
        ADRIA.effective_dhw_at_depth(Float64(dhw), depth; κ_base, mixing_scale)
        for dhw in dhw_surface
    ]
    lines!(ax, dhw_surface, eff_dhw; linewidth=2.5, label="$(depth) m")
end

axislegend(ax; position=:lt, labelsize=AXIS_LABEL_SIZE)

fig_eff_dhw

save(fig_path * "/S03_effective_dhw_depth_attenuation.png", fig_eff_dhw; px_per_unit=(300 / inch))
