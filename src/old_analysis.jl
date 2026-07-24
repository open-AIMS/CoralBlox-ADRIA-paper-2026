# Comparison of distance calculation methods:
# Method 1: Point-to-segment (current implementation)
# Method 2: Point-to-vertex only (simpler approach)

using Statistics, ArchGDAL

# Reuse the existing data
dom_gpkg = dom.loc_data

# Get linear ring of mainland boundary
mainland_ring = ArchGDAL.getgeom(GBRMPA_MAINLAND_GPKG.geometry[1], 0)

n_points = ArchGDAL.ngeom(mainland_ring)
mainland_coords = [
    (ArchGDAL.getpoint(mainland_ring, i - 1)[2],
        ArchGDAL.getpoint(mainland_ring, i - 1)[1])
    for i in 1:n_points
]

# Method 1: Point-to-segment (current implementation)
reef_dists_segment = map(1:length(dom_gpkg.LAT)) do i
    reef_point = (dom_gpkg.LAT[i], dom_gpkg.LON[i])

    # Find closest vertex on mainland
    vertex_dists = [haversine(reef_point, mainland_coords[j], 6371.0) for j in 1:n_points]
    closest_idx = argmin(vertex_dists)

    # Check only the 2 segments connected to the closest vertex
    dist1 = haversine_point_to_segment(
        reef_point,
        mainland_coords[mod1(closest_idx - 1, n_points)],
        mainland_coords[closest_idx];
        radius=6371.0)

    dist2 = haversine_point_to_segment(
        reef_point,
        mainland_coords[closest_idx],
        mainland_coords[mod1(closest_idx + 1, n_points)];
        radius=6371.0)

    min(dist1, dist2)
end

# Method 2: Point-to-vertex only (simpler approach)
reef_dists_vertex = map(1:length(dom_gpkg.LAT)) do i
    reef_point = (dom_gpkg.LAT[i], dom_gpkg.LON[i])

    # Just find minimum distance to any vertex
    vertex_dists = [haversine(reef_point, mainland_coords[j], 6371.0) for j in 1:n_points]
    minimum(vertex_dists)
end

# Calculate differences
distance_differences = reef_dists_vertex .- reef_dists_segment
relative_differences = distance_differences ./ reef_dists_segment .* 100  # as percentage

# Summary statistics
println("="^80)
println("COMPARISON: Point-to-Segment vs Point-to-Vertex Distance Calculation")
println("="^80)
println()

println("Number of reefs analyzed: ", length(dom_gpkg.LAT))
println("Number of mainland boundary vertices: ", n_points)
println()

println("Distance Statistics (km):")
println("-"^80)
println("                          Segment Method    Vertex Method")
println("Mean distance:           ", round(mean(reef_dists_segment), digits=2), " km           ",
    round(mean(reef_dists_vertex), digits=2), " km")
println("Median distance:         ", round(median(reef_dists_segment), digits=2), " km           ",
    round(median(reef_dists_vertex), digits=2), " km")
println("Min distance:            ", round(minimum(reef_dists_segment), digits=2), " km           ",
    round(minimum(reef_dists_vertex), digits=2), " km")
println("Max distance:            ", round(maximum(reef_dists_segment), digits=2), " km          ",
    round(maximum(reef_dists_vertex), digits=2), " km")
println()

println("Accuracy Gain Analysis:")
println("-"^80)
println("Mean absolute difference:     ", round(mean(abs.(distance_differences)), digits=3), " km")
println("Median absolute difference:   ", round(median(abs.(distance_differences)), digits=3), " km")
println("Max absolute difference:      ", round(maximum(abs.(distance_differences)), digits=3), " km")
println("Std dev of differences:       ", round(std(distance_differences), digits=3), " km")
println()

println("Relative Differences (%):")
println("-"^80)
println("Mean relative error:          ", round(mean(abs.(relative_differences)), digits=2), "%")
println("Median relative error:        ", round(median(abs.(relative_differences)), digits=2), "%")
println("Max relative error:           ", round(maximum(abs.(relative_differences)), digits=2), "%")
println()

# Count how many reefs have meaningful differences
threshold_km = 0.1  # 100 meters
n_affected = sum(abs.(distance_differences) .> threshold_km)
pct_affected = n_affected / length(dom_gpkg.LAT) * 100

println("Reefs with >$(threshold_km) km difference: ", n_affected, " (", round(pct_affected, digits=1), "%)")
println()

# Show some example cases
println("Example Cases (showing reefs with largest differences):")
println("-"^80)
sorted_idx = sortperm(abs.(distance_differences), rev=true)
for i in 1:min(5, length(sorted_idx))
    idx = sorted_idx[i]
    println("Reef #$idx:")
    println("  Segment method: ", round(reef_dists_segment[idx], digits=3), " km")
    println("  Vertex method:  ", round(reef_dists_vertex[idx], digits=3), " km")
    println("  Difference:     ", round(distance_differences[idx], digits=3), " km (",
        round(relative_differences[idx], digits=2), "%)")
    println()
end

println("="^80)
println("Conclusion:")
println("The segment method is more accurate when reefs are close to the perpendicular")
println("of a coastline segment rather than near vertices. The relative improvement")
println("depends on the geometry of the coastline and reef positions.")
println("="^80)
