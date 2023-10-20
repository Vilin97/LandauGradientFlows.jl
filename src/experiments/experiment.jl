mutable struct GradFlowExperiment{P, V, S, F}
	problem :: P
    saveat :: V
    num_solutions :: Int
	solutions :: Vector{S} # solutions[run][time_index][d, n] isa Float
    L2_error :: F
    mean_norm_error :: F
    cov_norm_error :: F
    cov_trace_error :: F
    # TODO: add timer
end

function Base.show(io::IO, experiment::GradFlowExperiment)
    @unpack problem, saveat, num_solutions, solutions, L2_error, mean_norm_error, cov_norm_error, cov_trace_error = experiment
    width = 6
    d,n = size(problem.u0)
    print(io, "\n$(problem.name)(d=$d,n=$(rpad(n,6))) $(rpad(problem.solver, 11)) $(num_solutions) runs: |ρ∗ϕ - ρ*|₂ = $(short_string(L2_error,width)) |E(ρ)-E(ρ*)|₂ = $(short_string(mean_norm_error,width)) |Σ-Σ'|₂ = $(short_string(cov_norm_error,width)) |tr(Σ-Σ')| = $(short_string(cov_trace_error,width))")
end

"Solve `problem` `num_solutions` times with different u0."
function GradFlowExperiment(problem::GradFlowProblem, num_solutions :: Int; saveat = problem.tspan[2])
    solutions = Vector{Vector{typeof(problem.u0)}}(undef, 0)
    F = eltype(problem.u0)
    return GradFlowExperiment(problem, saveat, num_solutions, solutions, zero(F), zero(F), zero(F), zero(F))
end

function solve!(experiment::GradFlowExperiment)
    @unpack problem, saveat, num_solutions, solutions = experiment
    d,n = size(problem.u0)
    for _ in 1:num_solutions
        # TODO: want to reinit the NN here
        # TODO: want different solvers to start with the same initial sample
        @timeit DEFAULT_TIMER "resample" resample!(problem)
        @timeit DEFAULT_TIMER "d=$d n=$(rpad(n,6)) $(rpad(problem.name, 10)) $(problem.solver)" sol = solve(problem, saveat=saveat)
        push!(solutions, sol.u)
    end
    nothing
end

function compute_errors!(experiment::GradFlowExperiment)
    d,n = size(experiment.problem.u0)
    @timeit DEFAULT_TIMER "d=$d n=$(rpad(n,6)) Lp" experiment.L2_error = Lp_error(experiment;p=2)
    experiment.mean_norm_error = mean_norm_error(experiment)
    experiment.cov_norm_error = cov_norm_error(experiment)
    experiment.cov_trace_error = cov_trace_error(experiment)
    nothing
end

function Lp_error(experiment; kwargs...)
    return avg_metric(Lp_error, experiment; kwargs...)
end
function mean_norm_error(experiment; kwargs...)
    return avg_metric((u,dist) -> sqrt(normsq(emp_mean(u), mean(dist))), experiment; kwargs...)
end
function cov_norm_error(experiment; kwargs...)
    return avg_metric((u,dist) -> sqrt(normsq(emp_cov(u), cov(dist))), experiment; kwargs...)
end
function cov_trace_error(experiment; kwargs...)
    return avg_metric((u,dist) -> abs(tr(emp_cov(u) .- cov(dist))), experiment; kwargs...)
end

function avg_metric(error, experiment::GradFlowExperiment; t_idx = length(experiment.saveat), kwargs...)
    @unpack problem, saveat, solutions = experiment
    dist = true_dist(problem, saveat[t_idx])
    return mean([error(sol[t_idx], dist; kwargs...) for sol in solutions])
end
    
struct GradFlowExperimentSet{E}
    experiments::E # a collection of `GradFlowExperiment`s
end

function GradFlowExperimentSet(problems, num_solutions; kwargs...)
    experiments = [GradFlowExperiment(problem, num_solutions; kwargs...) for problem in problems]
    return GradFlowExperimentSet(experiments)
end

"Make an experiment set for a given problem and dimension d with three solvers: Blob, SBTM, Exact."
function GradFlowExperimentSet(problem, d, ns, num_solutions; model)
    num_solvers = 3
    problems = Array{GradFlowProblem, 2}(undef, num_solvers, length(ns))
    for (j,n) in enumerate(ns)
        solvers = [Blob(blob_eps(d, n)), SBTM(deepcopy(model)), Exact()]
        for (i,solver) in enumerate(solvers)
            @timeit DEFAULT_TIMER "d=$d n=$(rpad(n, 6)) setup $solver" problems[i,j] = problem(d, n, solver)
        end
    end
    return GradFlowExperimentSet(problems, num_solutions)
end

function run_experiment_set!(experiment_set; save_intermediates=false, verbose=false)
    for experiment in experiment_set.experiments
        solve!(experiment)
        compute_errors!(experiment)
        if verbose
            print("$experiment")
        end
        if save_intermediates
            save(experiment_filename(experiment), experiment)
            # TODO make io for timer
            problem_name = experiment.problem.name
            save("data/experiments/$problem_name/timer.jld2", DEFAULT_TIMER)
        end
    end
end

Base.show(io::IO, experiment_set::GradFlowExperimentSet) = Base.show(io, experiment_set.experiments)