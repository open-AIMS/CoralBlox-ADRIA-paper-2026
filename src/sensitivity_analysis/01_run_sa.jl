# Manual entry point (NOT included by main.jl): runs the Shapley-effect sensitivity
# analysis and writes raw per-sample results to an EXTERNAL directory, configured via
# config.toml's [sensitivity_analysis].raw_data_dir - never to this repo's own outputs/.
#
#   julia --project=. src/sensitivity_analysis/01_run_sa.jl
#
# Ported from Analysis_CoralBlox_Shapley-Effect's src/01_sa_analysis.jl, re-pathed to use
# THIS repo's own pinned RME domain and calibrated params (config.toml's
# [calibration.domains].rme_domain / [calibration.products].calib_params) instead of the
# source repo's separately-configured domain/calib paths.
using Revise, Infiltrator
using Distributed
using TOML
using CSV
using Random
using Combinatorics
using Parquet2
using ProgressMeter

CONFIG_PATH = joinpath(dirname(dirname(@__DIR__)), "config.toml")
CONFIG::Dict{String,Any} = TOML.parsefile(CONFIG_PATH)
SA_CONFIG_SECTION = CONFIG["sensitivity_analysis"]

# * Setup multicore run
n_cores::Int = get(SA_CONFIG_SECTION, "n_cores", 1)
@assert n_cores > 0 "Number of cores must be positive"
if n_cores > 1
    # Remove extra procs in case the script is run mutiple times
    @info "Removing existing procs..."
    rmprocs(workers())
    @info "Adding $(n_cores - 1) procs..."
    addprocs(n_cores - 1)
end

# * Load packages
@everywhere using SAShE
@everywhere using ADRIA
@everywhere using ADRIAanalysis
@everywhere using DataFrames

# Workers resolve relative includes against their own working directory, so the path has
# to be interpolated as an absolute one
const SRC_DIR = @__DIR__
@everywhere include(joinpath($SRC_DIR, "common.jl"))
@everywhere include(joinpath($SRC_DIR, "samples.jl"))

# ** Create sensitivity analysis config object holding dhw_ranges, metrics, init_cover_range
sa_config = SAConfig()

@everywhere sa_config = $sa_config

const SEED = 0987

# This is not constant because different N_SAMPLES may be used for generating vs analysing
N_SAMPLES::Int64 = SA_CONFIG_SECTION["n_samples"]
@info ("Using $(N_SAMPLES) samples for Sensitivity Analysis")

# Domain and calibrated params are sourced from THIS repo's own pinned config, not a
# separately-configured path, so the SA is always run against the domain/calibration this
# repo's other figures already use.
const RME_PATH = CONFIG["calibration"]["domains"]["rme_domain"]
const CALIB_PARAMS_PATH = CONFIG["calibration"]["products"]["calib_params"]
const OUT_DATA_DIR = SA_CONFIG_SECTION["raw_data_dir"]

#* Load RME Domain
# calib_params_fn folds the calibrated coral/growth-accel/depth-atten values into the
# domain's model spec (see CoralBlox-params-calibration/scripts/plot/viz_results.jl). We
# don't load historic init cover here since this analysis samples initial conditions
# itself rather than using the calibration's historic values.
dom = ADRIA.load_domain(
    RMEDomain, RME_PATH, sa_config.scenario_ssp;
    timeframe=Tuple(sa_config.timeframe),
    force_single_reef=true,
    calib_params_fn=CALIB_PARAMS_PATH
)

#* Fix factors before sampling
# Do not fix any *_mean_colony_diameter_m factor here: sv_delta passes only the sampled
# factors to ADRIA.metrics.relative_shelter_volume, which reshapes them over
# (n_sizes, n_groups) and throws a DimensionMismatch if any are missing
ADRIA.deactivate_interventions!(dom)
ADRIA.fix_factor!(dom, :wave_scenario, 0)
ADRIA.fix_factor!(dom, :cyclone_mortality_scenario, 0)

# dhw_scenario is being fixed here but DHW values are being manually sampled and added below
ADRIA.fix_factor!(dom, :dhw_scenario, 1)

ms = ADRIA.model_spec(dom)
dst_mean_factors = ms[occursin.(Ref("dist_mean"), string.(ms.fieldname)), :fieldname]
ADRIA.set_factor_bounds!.(
    Ref(dom), dst_mean_factors, Ref(Tuple(sa_config.dist_mean_bounds))
)

dom.loc_data.area .= sa_config.loc_area

# Each icc_scens row is a initial coral composition scenario index
icc_scens::Matrix{Float64} = initial_coral_composition_scenarios()

# Cache DataFrameRow
cache_param_set = ADRIA.sample(dom, 1; sample_method=ADRIA.Distributions.Uniform())[1, :]

@everywhere dom = $dom
@everywhere cache_param_set = $cache_param_set
@everywhere icc_factor_names = $(_icc_factor_names())

@everywhere begin
    function _run_ADRIA(
        X::Vector{Float64};
        param_set::DataFrameRow=cache_param_set,
        factor_names::Vector{String}=factor_names,
        metrics::Vector{String}=sa_config.metrics,
        icc_factor_names::Vector{String}=icc_factor_names
    )
        Y = zeros(length(metrics))

        to_skip_idx::Vector{Int64} = []

        # Extract externally defined factors and add to to_skip_idx
        dom.loc_data.k .= extract_factor!(X, "k_area", to_skip_idx)
        dom.loc_data.depth_med .= extract_factor!(X, "depth_med", to_skip_idx)
        dom.dhw_scens .= extract_factor!(X, "dhw", to_skip_idx)

        init_rel_cover = extract_factor!(X, "initial_relative_cover", to_skip_idx)

        icc_weights = extract_factor!.(Ref(X), icc_factor_names, Ref(to_skip_idx))
        composition = init_rel_cover .* (icc_weights ./ sum(icc_weights))
        dom.init_coral_cover .= initial_coral_composition(dom, composition) .* init_rel_cover

        extract_factor!(X, "dummy", to_skip_idx)

        keep_idx = setdiff(1:length(factor_names), to_skip_idx)
        param_set[factor_names[keep_idx]] .= X[keep_idx]
        raw_results = ADRIA.run_model(dom, param_set; apply_allee_effect=false).raw

        for (metric_idx, metric) in enumerate(metrics)
            Y[metric_idx] = if metric == "cc_delta"
                sum(@view raw_results[end, :, :]) - sum(@view raw_results[1, :, :])
            elseif metric == "sv_delta"
                rsv = ADRIA.metrics.relative_shelter_volume(
                    raw_results, ADRIA.loc_k_area(dom), param_set[factor_names[keep_idx]]
                )
                rsv[end, 1] - rsv[1, 1]
            elseif metric == "ev_delta"
                rel_loc_taxa_cover = ADRIA.metrics.relative_loc_taxa_cover(raw_results)
                evenness = ADRIA.metrics.coral_evenness(rel_loc_taxa_cover.data)
                # Inverse Simpson is >= 1 for any living reef; the 0 returned at zero cover
                # is an absence sentinel rather than a low evenness
                max(evenness[end], 1.0) - max(evenness[1], 1.0)
            elseif metric == "jv_delta"
                rj = ADRIA.metrics.relative_juveniles(raw_results)
                rj[end, 1] - rj[1, 1]
            else
                error("Unsupported metric: $(metric)")
            end
        end

        return Y
    end

    """
    Resamples the dependent (icc) factors of a single row of X2, conditioned on that same
    row's X1 values. Only reads the row's own pre-update values, so rows are independent
    and this can be dispatched to any worker.
    """
    function _resample_X2_task(
        task::Tuple{Vector{Int64},Vector{Int64},Vector{Float64}}
    )::Vector{Float64}
        X1_param_idx, X2_param_idx, original_row = task
        return _sample_X2(
            X1_param_idx, X2_param_idx, original_row, original_row, factor_names;
            _icc_scens=icc_scens
        )
    end
end

"""
    run_sa_for_dhw_range(dom, sa_config, dhw_range, n_samples, out_data_dir, icc_scens)

Run the Shapley effect analysis for a single DHW range and write one output folder per
metric. Samples are reused when a matching pair of `.parq` files already exists.
"""
function run_sa_for_dhw_range(
    dom,
    sa_config::SAConfig,
    dhw_range,
    n_samples::Int64,
    out_data_dir::String,
    icc_scens::Matrix{Float64}
)::Nothing
    label = dhw_range_label(dhw_range)
    @info "=== $(label) ==="

    X1_path = joinpath(out_data_dir, "$(label)__$(n_samples)__X1.parq")
    X2_path = joinpath(out_data_dir, "$(label)__$(n_samples)__X2.parq")

    X1, X2 = if isfile(X1_path) && isfile(X2_path)
        @info "Using existing samples"
        DataFrame(Parquet2.Dataset(X1_path)), DataFrame(Parquet2.Dataset(X2_path))
    else
        @info "Couldn't find existing samples"
        @info "Generating samples"
        all_X1 = ADRIA.sample(dom, n_samples; sample_method=ADRIA.Distributions.Uniform())
        all_X2 = ADRIA.sample(dom, n_samples; sample_method=ADRIA.Distributions.Uniform())
        _X1 = ADRIAanalysis._filter_constants(all_X1)
        _X2 = ADRIAanalysis._filter_constants(all_X2)

        # Add extra factors to the sampled data
        add_k_area!(_X1, _X2, n_samples; bounds=sa_config.k_area_range)
        add_depth_med!(_X1, _X2, n_samples; bounds=sa_config.depth_range)
        add_dhw!(
            _X1, _X2, n_samples;
            lower_bound=Float64(dhw_range[1]), upper_bound=Float64(dhw_range[2])
        )
        add_initial_coral_composition!(_X1, _X2, n_samples, icc_scens)
        add_initial_cover!(_X1, _X2, n_samples; bounds=sa_config.init_cover_range)
        add_dummy_factor!(_X1, _X2, n_samples; bounds=sa_config.dummy_range)

        Parquet2.writefile(X1_path, _X1)
        Parquet2.writefile(X2_path, _X2)

        _X1, _X2
    end

    factor_names = names(X1)
    @everywhere factor_names = $factor_names

    n_factors = size(X1, 2)
    permutations = SAShE.generate_permutations(n_samples, n_factors)
    S_x = SAShESample(X1, X2, permutations)

    # Each row must be an independent Vector{Float64}: a DataFrameRow (and a matrix row
    # view) holds a reference to the whole frame, which Distributed would then serialise
    # once per task. `analyze` only reads S_x.samples for its size, not its values, so
    # mutating this matrix directly (rather than writing back into S_x.samples) is enough.
    samples_matrix = Matrix{Float64}(S_x.samples)
    n_rows = size(samples_matrix, 1)

    # Since there is a dependency between the coral composition factors, X2 needs to be
    # sampled for each permutation conditionally to X1. Each row's resample only reads
    # that same row's pre-update values (never another row's), so the n_samples*n_factors
    # resamples are independent and are distributed across workers instead of running
    # serially on the main process.
    @everywhere icc_scens = $icc_scens

    # Row 1 of each (n_factors + 1)-row permutation block is the untouched X1 row;
    # `block_pos` is that row's position within its block (0 = no resample needed).
    block_pos = [mod(row - 1, n_factors + 1) for row in 1:n_rows]
    rows_to_update = findall(!=(0), block_pos)

    update_tasks = Vector{Tuple{Vector{Int64},Vector{Int64},Vector{Float64}}}(
        undef, length(rows_to_update)
    )
    X2_indices = Vector{Vector{Int64}}(undef, length(rows_to_update))
    for (i, row) in enumerate(rows_to_update)
        pos = block_pos[row]
        permutation_idx = div(row - 1, n_factors + 1) + 1
        π_n = permutations[permutation_idx, :]
        X1_param_idx = π_n[(pos+1):end]
        X2_param_idx = π_n[1:pos]
        X2_indices[i] = X2_param_idx
        update_tasks[i] = (X1_param_idx, X2_param_idx, samples_matrix[row, :])
    end

    resample_batch_size = clamp(length(update_tasks) ÷ (nworkers() * 20), 1, 200)
    @info "Generating samples ($(length(update_tasks)) conditional resamples, " *
          "batches of $(resample_batch_size))"
    new_values = @showprogress pmap(
        _resample_X2_task, update_tasks; batch_size=resample_batch_size
    )

    for (row, X2_param_idx, values) in zip(rows_to_update, X2_indices, new_values)
        samples_matrix[row, X2_param_idx] .= values
    end

    sample_rows = [samples_matrix[i, :] for i in axes(samples_matrix, 1)]

    # A single model run takes milliseconds, so one remotecall per row would spend a large
    # fraction of the time on bookkeeping. Batches are sized to give every worker many of
    # them, keeping the tail balanced, and capped so the progress bar still moves.
    batch_size = clamp(length(sample_rows) ÷ (nworkers() * 20), 1, 200)

    # Y is a matrix of n_samples x n_metrics
    @info "Running model ($(length(sample_rows)) evaluations, batches of $(batch_size))"
    Y = @showprogress pmap(_run_ADRIA, sample_rows; batch_size=batch_size)

    # Lowercase ϕ refers to the matrix of increments to each SE capital case Φ
    # * Save Shapley Effect Increments and Variance
    @info "Solving Sensitivity Analysis problem"
    metadata = run_metadata(sa_config, dhw_range, n_samples)
    for (metric_idx, metric) in enumerate(sa_config.metrics)
        Yₙ = getindex.(Y, metric_idx)

        _ϕ, _ϕ² = SAShE.analyze(S_x, Yₙ)

        # No timestamp in the SA output dir name: that would make managing multiple
        # distinct combinations of dhw_range and n_samples harder. Provenance goes into
        # run_metadata.toml instead.
        dir = mkpath(sa_output_dir(out_data_dir, dhw_range, n_samples, metric))

        Parquet2.writefile(joinpath(dir, "se_increments.parq"), DataFrame(_ϕ', factor_names))
        Parquet2.writefile(joinpath(dir, "se2_increments.parq"), DataFrame(_ϕ²', factor_names))
        Parquet2.writefile(
            joinpath(dir, "m_results.parq"),
            DataFrame(Symbol(metric) => Yₙ[1:(n_factors+1):(n_samples*(n_factors+1))])
        )
        write_run_metadata(dir, metadata)
    end

    return nothing
end

# * Run analysis for every DHW range that isn't already on disk
mkpath(OUT_DATA_DIR)
plan = sa_run_plan(OUT_DATA_DIR, sa_config, N_SAMPLES)
report_sa_run_plan(plan, OUT_DATA_DIR, N_SAMPLES)
assert_provenance_compatible(plan)

try
    for entry in filter(e -> e.status != :complete, plan)
        # Reseed per range so every range draws the same non-DHW factor samples, as it did
        # back when each range was run in its own process
        Random.seed!(SEED)
        run_sa_for_dhw_range(
            dom, sa_config, entry.dhw_range, N_SAMPLES, OUT_DATA_DIR, icc_scens
        )
    end
finally
    # Also runs on error and on Ctrl-C. Workers left behind keep the registry files open,
    # which makes later Pkg operations fail with a permission error on Windows
    n_cores > 1 && rmprocs(workers())
end
