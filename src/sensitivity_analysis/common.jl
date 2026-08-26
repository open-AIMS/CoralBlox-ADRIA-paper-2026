using Dates
using Pkg
using TOML

"""
    SAConfig

What the sensitivity analysis experiment *is*: DHW ranges, metrics, sampling bounds. Ported
unchanged from Analysis_CoralBlox_Shapley-Effect's `src/common.jl` - edit the defaults here
to change the analysis design. Machine-specific settings (sample count, cores, output paths)
live in `config.toml`'s `[sensitivity_analysis]` section instead.
"""
Base.@kwdef struct SAConfig
    dhw_ranges::Vector{Vector{Int16}} = [[0, 0], [0, 30], [0, 8], [8, 16], [16, 30]]
    metrics::Vector{String} = ["cc_delta", "sv_delta", "ev_delta", "jv_delta"]
    init_cover_range::Vector{Float64} = [0.3, 0.3]
    # (lower, upper, default) sampling bounds for every dist_mean factor
    dist_mean_bounds::Vector{Float64} = [3.0, 10.0, 3.0]
    loc_area::Float64 = 1e8
    timeframe::Vector{Int64} = [2023, 2024]
    # Upper bound is the 23.79 m max depth_med of the canonical reefs gpkg, plus 10%
    depth_range::Vector{Float64} = [0.0, 26.4]
    k_area_range::Vector{Float64} = [0.0, 1.0]
    dummy_range::Vector{Float64} = [0.0, 1.0]
    scenario_ssp::String = "45"
end

# Naming convention for SA outputs, shared by the run and the aggregation stages
const SA_RESULT_FILES = ("se_increments.parq", "se2_increments.parq", "m_results.parq")
const SA_METADATA_FILE = "run_metadata.toml"
const TRACKED_PACKAGES = ["ADRIA", "ADRIAanalysis", "CoralBlox", "SAShE"]

dhw_range_label(dhw_range)::String = "dhw_$(dhw_range[1])_$(dhw_range[2])"

function sa_output_dir_name(dhw_range, n_samples::Int64, metric::String)::String
    return "$(dhw_range_label(dhw_range))__$(n_samples)__$(metric)"
end

function sa_output_dir(
    out_data_dir::String, dhw_range, n_samples::Int64, metric::String
)::String
    return joinpath(out_data_dir, sa_output_dir_name(dhw_range, n_samples, metric))
end

"""
A metric is complete only when its directory holds all three result files: a directory
alone can be the leftover of a run that died partway through writing.
"""
function is_metric_complete(
    out_data_dir::String, dhw_range, n_samples::Int64, metric::String
)::Bool
    dir = sa_output_dir(out_data_dir, dhw_range, n_samples, metric)
    return isdir(dir) && all(isfile.(joinpath.(dir, SA_RESULT_FILES)))
end

function _package_versions()::Dict{String,String}
    return Dict(
        p.name => string(p.version)
        for p in values(Pkg.dependencies())
        if (p.name in TRACKED_PACKAGES) && !isnothing(p.version)
    )
end

function _git_revision()::String
    return try
        revision = readchomp(`git rev-parse HEAD`)
        isempty(readchomp(`git status --porcelain`)) ? revision : "$(revision)-dirty"
    catch
        "unknown"
    end
end

# dhw_ranges says which ranges to compute, not how any single one was computed. It is
# recorded but not compared, so that adding a range later doesn't invalidate the ranges
# already on disk.
const UNCOMPARED_CONFIG_FIELDS = ["dhw_ranges"]

"""
The whole `SAConfig`, derived from `fieldnames` so fields added later are captured
without touching this.
"""
function config_dict(sa_config::SAConfig)::Dict{String,Any}
    return Dict{String,Any}(
        string(field) => getfield(sa_config, field) for field in fieldnames(SAConfig)
    )
end

compared_config_fields(config::Dict{String,Any}) =
    sort(setdiff(collect(keys(config)), UNCOMPARED_CONFIG_FIELDS))

"""
    run_metadata(sa_config::SAConfig, dhw_range, n_samples::Int64)

Provenance for a single SA run, written next to the results so each output folder is
self-describing. Existing results often predate a config change, and the aggregation stage
has no other way to tell which vintage it is reading.
"""
function run_metadata(sa_config::SAConfig, dhw_range, n_samples::Int64)::Dict{String,Any}
    return Dict{String,Any}(
        "timestamp" => string(now()),
        "n_samples" => n_samples,
        "dhw_range" => Int.(dhw_range),
        "git_revision" => _git_revision(),
        "config" => config_dict(sa_config),
        "package_versions" => _package_versions()
    )
end

function write_run_metadata(dir::String, metadata::Dict{String,Any})::Nothing
    open(joinpath(dir, SA_METADATA_FILE), "w") do io
        TOML.print(io, metadata)
    end
    return nothing
end

function read_run_metadata(
    out_data_dir::String, dhw_range, n_samples::Int64, metric::String
)::Union{Dict{String,Any},Nothing}
    path = joinpath(
        sa_output_dir(out_data_dir, dhw_range, n_samples, metric), SA_METADATA_FILE
    )
    return isfile(path) ? TOML.parsefile(path) : nothing
end

"""
Design fields whose drift would make a stored run incomparable with the ranges being run
now. Package versions are included since a CoralBlox bump changes the model itself.
Fields absent from the stored metadata are skipped: they were added to `SAConfig` after
that run, so there is nothing to compare against.
"""
function _provenance_mismatches(
    metadata::Dict{String,Any}, sa_config::SAConfig
)::Vector{String}
    mismatches = String[]

    current_config = config_dict(sa_config)
    stored_config = metadata["config"]
    for field in compared_config_fields(current_config)
        haskey(stored_config, field) || continue
        if stored_config[field] != current_config[field]
            push!(
                mismatches, "$(field): $(stored_config[field]) -> $(current_config[field])"
            )
        end
    end

    current_versions = _package_versions()
    for (pkg, version) in sort(collect(metadata["package_versions"]))
        if get(current_versions, pkg, version) != version
            push!(mismatches, "$(pkg): $(version) -> $(current_versions[pkg])")
        end
    end

    return mismatches
end

"""
    sa_run_plan(out_data_dir::String, sa_config::SAConfig, n_samples::Int64)

Inventory of which DHW ranges already have results in `out_data_dir`. A single model run
produces every metric at once, so the unit of work is the DHW range: a range holding only
some of `sa_config.metrics` must be re-run in full, overwriting what is already there.
"""
function sa_run_plan(out_data_dir::String, sa_config::SAConfig, n_samples::Int64)
    return map(sa_config.dhw_ranges) do dhw_range
        found = filter(
            m -> is_metric_complete(out_data_dir, dhw_range, n_samples, m),
            sa_config.metrics
        )
        missing_metrics = setdiff(sa_config.metrics, found)

        status = if isempty(missing_metrics)
            :complete
        elseif isempty(found)
            :absent
        else
            :partial
        end

        metadata = isempty(found) ? nothing :
                   read_run_metadata(out_data_dir, dhw_range, n_samples, found[1])
        mismatches = isnothing(metadata) ? String[] :
                     _provenance_mismatches(metadata, sa_config)

        (; dhw_range, status, found, missing_metrics, metadata, mismatches)
    end
end

function report_sa_run_plan(plan, out_data_dir::String, n_samples::Int64)::Nothing
    width = maximum(length.(dhw_range_label.(getproperty.(plan, :dhw_range))))

    lines = map(plan) do entry
        label = rpad(dhw_range_label(entry.dhw_range), width)
        if entry.status == :complete
            stamp = isnothing(entry.metadata) ? "no metadata" : entry.metadata["timestamp"]
            "  $label  COMPLETE  [$(join(entry.found, ", "))] ($(stamp)) -> skipping"
        elseif entry.status == :absent
            "  $label  ABSENT    -> running"
        else
            "  $label  PARTIAL   found [$(join(entry.found, ", "))], " *
            "missing [$(join(entry.missing_metrics, ", "))] -> re-running whole range, " *
            "existing metrics will be OVERWRITTEN"
        end
    end

    n_to_run = count(e -> e.status != :complete, plan)
    @info join(
        [
            "Scanning $(out_data_dir) for existing results (n_samples = $(n_samples))",
            lines...,
            "Running $(n_to_run) of $(length(plan)) DHW ranges"
        ],
        "\n"
    )

    if any(e -> e.status == :partial, plan)
        @warn "Partial ranges are recomputed in full: a model run produces all metrics at " *
              "once, so their existing results will be replaced."
    end

    for entry in filter(e -> e.status == :complete, plan)
        if isnothing(entry.metadata)
            @warn "$(dhw_range_label(entry.dhw_range)): results predate metadata logging, " *
                  "provenance cannot be verified"
        elseif !isempty(entry.mismatches)
            @warn "$(dhw_range_label(entry.dhw_range)): skipped results were produced " *
                  "under a different setup:\n  " * join(entry.mismatches, "\n  ")
        end
    end

    return nothing
end

"""
    assert_provenance_compatible(plan)

Refuse to compute new DHW ranges that would not be comparable with the completed ones
already on disk. Ranges are computed incrementally, so a package bump or a `SAConfig`
change between runs would otherwise leave the output directory holding two vintages that
later get plotted as a single experiment.
"""
function assert_provenance_compatible(plan)::Nothing
    any(e -> e.status != :complete, plan) || return nothing

    incompatible = filter(e -> e.status == :complete && !isempty(e.mismatches), plan)
    isempty(incompatible) && return nothing

    report = join(
        ["  $(dhw_range_label(e.dhw_range)): " * join(e.mismatches, ", ") for e in incompatible],
        "\n"
    )
    error(
        "Completed ranges on disk were produced under a different setup than this run " *
        "would use:\n$(report)\n" *
        "Recompute those ranges, move them aside, or restrict sa_config.dhw_ranges."
    )
end

function _group_labels(entries, value_of)::Dict{String,Vector{String}}
    grouped = Dict{String,Vector{String}}()
    for entry in entries
        value = string(value_of(entry.metadata))
        push!(get!(grouped, value, String[]), dhw_range_label(entry.dhw_range))
    end
    return grouped
end

function _describe_groups(grouped::Dict{String,Vector{String}})::String
    return join(
        ["$(value) [$(join(sort(labels), ", "))]" for (value, labels) in sort(collect(grouped))],
        "; "
    )
end

"""
    report_provenance(entries)::Nothing

Check that every DHW range being loaded was produced under the same setup. Ranges are
computed incrementally, so a figure can end up combining runs from either side of a
package bump or a config change without anything on disk looking wrong.
"""
function report_provenance(entries)::Nothing
    differences = String[]

    stored_fields = union((keys(e.metadata["config"]) for e in entries)...)
    for field in compared_config_fields(Dict{String,Any}(f => nothing for f in stored_fields))
        grouped = _group_labels(entries, m -> get(m["config"], field, "not recorded"))
        length(grouped) > 1 && push!(differences, "$(field): $(_describe_groups(grouped))")
    end

    for pkg in TRACKED_PACKAGES
        grouped = _group_labels(entries, m -> get(m["package_versions"], pkg, "unknown"))
        length(grouped) > 1 && push!(differences, "$(pkg): $(_describe_groups(grouped))")
    end

    if isempty(differences)
        @info "Provenance consistent across $(length(entries)) DHW ranges"
    else
        @warn "DHW ranges were produced under different setups, cross-range comparison " *
              "may be affected:\n  " * join(differences, "\n  ")
    end

    # Reported separately: the revision moves with every unrelated commit, so a difference
    # here is common and not on its own a reason to distrust a comparison
    grouped_revision = _group_labels(entries, m -> m["git_revision"])
    length(grouped_revision) > 1 &&
        @info "Ranges span multiple git revisions: $(_describe_groups(grouped_revision))"

    return nothing
end

"""
    extract_factor!(X, factor_name, to_skip_idx)

Pulls `factor_name`'s value out of a sampled factor vector `X` (indexed against the global
`factor_names`) and records its index in `to_skip_idx`, so the caller can later exclude it
from the factors passed straight through to `ADRIA.run_model`. Used by
`01_run_sa.jl`'s `_run_ADRIA` for factors (k_area, depth_med, dhw, initial cover, icc
weights, dummy) that are handled manually rather than via the domain's own param table.
"""
function extract_factor!(
    X::Vector{Float64}, factor_name::String, to_skip_idx::Vector{Int}
)::Float64
    factor_idx = findfirst(factor_names .== factor_name)
    push!(to_skip_idx, factor_idx)
    return X[factor_idx]
end
