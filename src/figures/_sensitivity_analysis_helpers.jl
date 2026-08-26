# Presentation/plotting logic for the sensitivity analysis figures (06, S04), ported from
# Analysis_CoralBlox_Shapley-Effect's src/common.jl and src/plots/plots.jl. Kept separate
# from src/sensitivity_analysis/common.jl, which holds only the SAConfig/provenance
# machinery - these functions instead decide how driving factors are selected, normalized
# and human-readably labelled once the aggregation math is already done.

function dhw_labels(dhw_ranges::Vector{String})::Vector{String}
    _dhw_labels = split.(dhw_ranges, "_") .|> x -> "$(x[1]) ≦ DHW ≦ $(x[2])"

    # Replace labels of fixed DHW to "DHW = X"
    dhw_range_split = split.(dhw_ranges, "_")
    fixed_dhw_indexes = getindex.(dhw_range_split, 1) .== getindex.(dhw_range_split, 2)

    _dhw_labels[fixed_dhw_indexes] .= ("DHW = " .* dhw_ranges[fixed_dhw_indexes][1][1])

    return _dhw_labels
end

_metric_readable = (
    cc_delta="ΔCoral cover",
    sv_delta="ΔShelter volume",
    ev_delta="ΔEvenness",
    jv_delta="ΔJuveniles"
)

function top_n_factors(
    Φ::YAXArray{Float64,1},
    Φlb::YAXArray{Float64,1},
    Φub::YAXArray{Float64,1},
    factor_names::Vector{String};
    n::Int64=5
)
    sortperm_Φ_rev = sortperm(collect(Φ.data), rev=true)

    return (Φ[sortperm_Φ_rev][1:n],
        Φlb[sortperm_Φ_rev][1:n],
        Φub[sortperm_Φ_rev][1:n],
        factor_names[sortperm_Φ_rev][1:n])
end

function driving_factors(
    Φ::YAXArray{Float64,1},
    Φlb::YAXArray{Float64,1},
    Φub::YAXArray{Float64,1},
    factor_names::Vector{String};
    threshold::Float64=0.01
)
    # In the past we were using a threshold to filter the driving factors.
    # We don't do that anymore but I'm leaving this here for now to remember that this is
    # another possibility
    # driving_factors_mask = abs.(Φ) .> threshold

    # Ignore factors that are compatible with either the dummy factor or with zero
    dummy_lb = Φlb[factors=At(["dummy"])][1]
    dummy_ub = Φub[factors=At(["dummy"])][1]
    low_val_factors = (((dummy_lb .< Φub) .&& (Φlb .< dummy_ub)).data) .|| Φlb .< 0.0

    driving_factors_mask = .!low_val_factors
    Φ⁺ = Φ[driving_factors_mask]
    Φ⁺_sortperm = sortperm(Φ⁺; rev=true).data

    # Return
    Φ⁺ = Φ⁺[Φ⁺_sortperm]
    Φlb⁺ = Φlb[driving_factors_mask][Φ⁺_sortperm]
    Φub⁺ = Φub[driving_factors_mask][Φ⁺_sortperm]
    factor_names⁺ = factor_names[driving_factors_mask][Φ⁺_sortperm]

    return Φ⁺, Φlb⁺, Φub⁺, factor_names⁺
end

function normalized_factors(
    Φ::AbstractArray{Float64,1},
    Φlb⁺::AbstractArray{Float64,1},
    Φub⁺::AbstractArray{Float64,1}
)
    return Φ ./ sum(Φ), Φlb⁺ ./ sum(Φ), Φub⁺ ./ sum(Φ)
end

function human_readable_factors(factors::Vector{String})::Vector{String}
    # Don't change the input object
    _factors = copy(factors)

    icc_mask = occursin.("icc_", _factors)
    icc_factors = split.(_factors[icc_mask], "_")
    _factors[icc_mask] .= [
        "%" .* join(uppercase.(getindex.(icc_factor[2:end], 1))) .* " cover"
        for icc_factor in icc_factors
    ]

    _human_readable_group_factor!(_factors, "group_linear_extension", "Linear extension group")
    _human_readable_group_factor!(_factors, "dist_mean", "Dist. mean group")
    _human_readable_group_factor!(_factors, "midpoint", "Growth Acc. midpoint")
    _human_readable_group_factor!(_factors, "height", "Growth Acc. height")

    _human_readable_factors!(_factors, "dist_std", "Dist. Std.")
    _human_readable_factors!(_factors, "mb_rate", "Mortality rate")
    _human_readable_factors!(_factors, "mean_colony_diameter_m", "Colony diameter")
    _human_readable_factors!(_factors, "fecundity", "Fecundity")

    known_mappings = Dict(
        "dhw" => "DHW",
        "depth_med" => "Depth",
        "k_area" => "Hab. area",
        "initial_relative_cover" => "Initial Cover",
        "eff_dhw_base" => "Depth DHW att. base",
        "eff_dhw_mix" => "Depth DHW att. mix",
    )
    replace!(_factors, known_mappings...)

    return _factors
end

function _human_readable_factors!(
    factors::Vector{String}, search_pattern::String, label::String
)::Nothing
    dist_mask = occursin.(search_pattern, factors)
    dist_factors = split.(getindex.(split.(factors[dist_mask], "_$search_pattern"), 1), "_")
    dist_prefix = uppercase.([join(getindex.(f[1:end-2], 1)) for f in dist_factors])
    dist_size = getindex.(dist_factors, lastindex.(dist_factors))
    factors[dist_mask] .= strip.(label, '_') .* " " .* dist_prefix .* " " .* dist_size
    return nothing
end

function _human_readable_group_factor!(
    factors::Vector{String}, search_pattern::String, label::String
)::Nothing
    dist_mask = occursin.(search_pattern, factors)
    factors[dist_mask] .= label
    return nothing
end
