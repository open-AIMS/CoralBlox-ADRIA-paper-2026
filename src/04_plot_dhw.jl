dom_gpkg = dom.loc_data
cb_calib_groups = sort(unique(dom_gpkg.CB_CALIB_GROUPS))

loc_dhw = dom.dhw_scens[:, :, 1]
max_dhw = ceil(maximum(loc_dhw))
loc_ids = collect(loc_dhw.locs.val)

x_tsteps = collect(loc_dhw.timesteps.val)

fig_dhw = Figure(; size=(800, 600))
for g in cb_calib_groups
    row = Int(ceil(g / 4))
    col = ((g - 1) % 4) + 1
    ax = Axis(
        fig_dhw[row, col],
        limits=(nothing, (0, max_dhw)),
        xticks=(collect(1:2:15), string.(x_tsteps)[1:2:15]),
        xticklabelsvisible=row == 3 ? true : false,
        xlabelvisible=row == 3 ? true : false,
        titlesize=9pt,
        xticklabelsize=9pt,
        yticklabelsize=9pt,
        yticklabelsvisible=col == 1 ? true : false,
        ylabelvisible=col == 1 ? true : false,
        xticklabelrotation=π / 4,
        title="Reef group $g",
    )
    data = @views loc_dhw[locs=loc_ids .∈ Ref(dom_gpkg[dom_gpkg.CB_CALIB_GROUPS.==g, :GBRMPA_ID])]

    # lines!.(ax, x_tsteps, eachcol(data))
    series!(ax, read(data'), solid_color=(:orange, 0.05))
end
Label(fig_dhw[0, :], "Observed maximum DHW values per reef group", fontsize=12pt)
Label(fig_dhw[4, :], "Year", fontsize=10pt)
Label(fig_dhw[1:3, 0], "DHW", fontsize=10pt, rotation=π / 2)
fig_dhw

save(fig_path * "/S02_dhw_per_reef_group.png", fig_dhw; px_per_unit=(300 / inch))