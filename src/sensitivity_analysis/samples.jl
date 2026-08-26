# Ported as-is from Analysis_CoralBlox_Shapley-Effect's src/samples.jl - factor sampling
# helpers used by 01_run_sa.jl to add non-ADRIA-native factors (k_area, depth_med, dhw,
# initial cover/composition, dummy) to the Sobol'/Shapley sample matrices.

function add_k_area!(X1, X2, n_samples; bounds::Vector{Float64}=[0.0, 1.0])::Nothing
    k_area_distribution = ADRIA.Distributions.Uniform(bounds...)
    k_area_samples = rand(k_area_distribution, n_samples, 2)
    X1.k_area = k_area_samples[:, 1]
    X2.k_area = k_area_samples[:, 2]
    return nothing
end

function add_dummy_factor!(X1, X2, n_samples; bounds::Vector{Float64}=[0.0, 1.0])::Nothing
    dummy_distribution = ADRIA.Distributions.Uniform(bounds...)
    dummy_samples = rand(dummy_distribution, n_samples, 2)
    X1.dummy = dummy_samples[:, 1]
    X2.dummy = dummy_samples[:, 2]
    return nothing
end

"""
extrema(dom.loc_data.depth_med) = (0.23399999737739563, 23.789501190185547)
"""
function add_depth_med!(X1, X2, n_samples; bounds::Vector{Float64}=[0.0, 26.4])::Nothing
    depth_med_distribution = ADRIA.Distributions.Uniform(bounds...)
    depth_med_samples = rand(depth_med_distribution, n_samples, 2)
    X1.depth_med = depth_med_samples[:, 1]
    X2.depth_med = depth_med_samples[:, 2]
    return nothing
end

"""
    add_dhw!(X1, X2, n_samples; lower_bound::Float64=0.0, upper_bound::Float64=30.0)::Nothing

Samples DHW scenarios for two reefs. Upper and lower bounds were informed by the extreme
values of dhw_scenarios from RME (`extrema(dom.dhw_scens) ≈ (0.14, 26.68)`). Setting both
bounds to the same value holds DHW fixed at that value.
"""
function add_dhw!(X1, X2, n_samples; lower_bound::Float64=0.0, upper_bound::Float64=30.0)::Nothing
    if lower_bound == upper_bound >= 0.0
        # Draw and discard, so that a fixed DHW range consumes the same number of random
        # numbers as a sampled one and every range shares the factors drawn after this
        rand(ADRIA.Distributions.Uniform(0.0, 1.0), n_samples, 2)
        X1.dhw = fill(upper_bound, n_samples)
        X2.dhw = fill(upper_bound, n_samples)
        return nothing
    end

    dhw_distribution = ADRIA.Distributions.Uniform(lower_bound, upper_bound)
    dhw_samples = round.(rand(dhw_distribution, n_samples, 2), digits=2)
    X1.dhw = dhw_samples[:, 1]
    X2.dhw = dhw_samples[:, 2]
    return nothing
end

_icc_factor_names() = "icc_" .* string.(ADRIA.functional_group_names())

function add_initial_coral_composition!(
    X1::DataFrame,
    X2::DataFrame,
    n_samples::Int64,
    icc_scens
)::Nothing
    # Sample initial coral composition scenarios
    n_icc_scens = size(icc_scens, 1)
    icc_scens_distribution = ADRIA.Distributions.DiscreteUniform(1, n_icc_scens)
    icc_scens_samples = rand(icc_scens_distribution, n_samples, 2)

    icc_values_1 = icc_scens[icc_scens_samples[:, 1], :]
    icc_values_2 = icc_scens[icc_scens_samples[:, 2], :]

    # Column order must follow _icc_factor_names(): _sample_X2 maps icc column positions
    # onto icc_scens columns positionally, so a Dict's hash order would silently pair each
    # draw with the wrong functional group
    insertcols!(X1, (_icc_factor_names() .=> eachcol(icc_values_1))...)
    insertcols!(X2, (_icc_factor_names() .=> eachcol(icc_values_2))...)

    return nothing
end

function add_initial_cover!(X1::DataFrame, X2::DataFrame, n_samples::Int64; bounds::Vector{Float64}=[0.1, 0.9])::Nothing
    if bounds[1] == bounds[2] >= 0.0
        X1.initial_relative_cover = fill(bounds[1], n_samples)
        X2.initial_relative_cover = fill(bounds[1], n_samples)
        return nothing
    end

    # Sample initial coral cover
    init_cover_distribution = ADRIA.Distributions.Uniform(bounds...)
    init_cover_samples = round.(rand(init_cover_distribution, n_samples, 2), digits=2)
    X1.initial_relative_cover = init_cover_samples[:, 1]
    X2.initial_relative_cover = init_cover_samples[:, 2]
    return nothing
end

"""
    initial_coral_composition_scenarios(; n_func_groups::Int64=5)::Matrix{Float64}

1. Generates all combinations of 5 elements vectors that contains numbers 1:5 with
replacement
2. Divide all elements by the greatest common denominator (gcd) (so [1,1,1,1,1], [2,2,2,2,2],
[3,3,3,3,3], [4,4,4,4,4] and [5,5,5,5,5] will all become equal to [1,1,1,1,1]) and remove
all duplicates
3. Returns a matrix with each row being a unique non-normalized combination of weights for
each functional group initial coral cover
"""
function initial_coral_composition_scenarios(; n_func_groups::Int64=5)::Matrix{Float64}
    icc_w_combinations = collect.(vec(collect(
        Iterators.product(fill(1:n_func_groups, n_func_groups)...)
    )))

    # Manually remove element [4,4,4,4,4] to avoid creating a recursive while loop to keep
    # dividing by the gcd while possible. I'm doing this beucase I know that [4,4,4,4,4] is
    # the only element of icc_w_combinations that can be divided by the gcd twice as long
    # as n_func_groups <= 5
    icc_w_combinations = icc_w_combinations[icc_w_combinations.!=Ref([4, 4, 4, 4, 4])]

    return Matrix(hcat(unique(icc_w_combinations ./ gcd.(icc_w_combinations))...)')
end

function initial_coral_composition(dom::Domain, icc_weights::Vector{Float64})::Matrix{Float64}
    norm_icc_weights = icc_weights ./ sum(icc_weights)
    _functional_group_names = ADRIA.functional_group_names()
    n_functional_groups = length(_functional_group_names)
    icc_weights_yax = ADRIA.DataCube(
        reshape(norm_icc_weights, n_functional_groups, 1),
        species=String.(_functional_group_names),
        locations=collect(dom.init_coral_cover.locs.val)
    )
    return ADRIA._split_cover(icc_weights_yax).data
end

function _sample_X2(
    X1_param_idx::Vector{Int64},
    X2_param_idx::Vector{Int64},
    _X1::Vector{Float64},
    _X2::Vector{Float64},
    factor_names::Vector{String};
    _icc_scens::Matrix{Float64}=icc_scens
)
    icc_idx::Vector{Int64} = sort(findall(occursin.("icc", factor_names)))

    # The only dependent factors are the icc ones (initial coral composition)
    # If there are no icc factors in X2, we just use X2, otherwise we take X2 and
    # sample the icc factors conditioned on the icc X1 values. Same if there are no icc
    # factors in X1.
    if (sum(X2_param_idx .∈ Ref(icc_idx)) == 0) || (sum(X1_param_idx .∈ Ref(icc_idx)) == 0)
        return @view _X2[X2_param_idx]
    else
        # icc factor indexes present on X1
        X1_icc_idx = sort(X1_param_idx[findall(X1_param_idx .∈ Ref(icc_idx))])

        # functional group indexes of icc factors on X1
        X1_fgroup_idx = sort(findall(icc_idx .∈ Ref(X1_icc_idx)))

        # Indexes of all icc_scens that are compatible with X1 icc values
        @views compat_icc_scen_idx = findall(
            eachrow(_icc_scens[:, X1_fgroup_idx]) .== Ref(_X1[X1_icc_idx])
        )

        # Sample uniformily among the compatible scenarios
        n_compat_icc_scens = length(compat_icc_scen_idx)
        icc_scens_distribution = ADRIA.Distributions.DiscreteUniform(1, n_compat_icc_scens)
        target_icc_scen_idx = compat_icc_scen_idx[rand(icc_scens_distribution, 1)]

        n_functional_groups = size(_icc_scens, 2)
        X2_fgroup_idx = sort(setdiff(1:n_functional_groups, X1_fgroup_idx))

        @views X2_values = _X2[X2_param_idx]
        X2_icc_idx = sort(findall(X2_param_idx .∈ Ref(icc_idx)))

        # Replace icc factors (X2_icc_idx) with sampled ones on X2_values
        X2_values[X2_icc_idx] .= _icc_scens[target_icc_scen_idx, X2_fgroup_idx]'

        return X2_values
    end
end
