using GradientFlows, Flux, Test, TimerOutputs
include("../testutils.jl")

@testset "IO" begin
@testset "chain IO" begin
    d = 2
    n = 10
    s = Chain(Dense(d => d))
    path = model_filename("test_problem", d, n)
    save(path, s)
    s_loaded = load(path)
    x = rand(Float32, d)
    @test s(x) == s_loaded(x)

    other_s = Chain(Dense(d => d))
    path2 = model_filename("test_problem", d, n + 1)
    save(path2, other_s)
    s_loaded = best_model("test_problem", d)
    @test s(x) != s_loaded(x)
    @test other_s(x) == s_loaded(x)

    path_prefix = splitpath(path)[1]
    rm(path_prefix, recursive=true)
end
@testset "experiment IO" begin
    problem = diffusion_problem(2, 10, Blob(blob_epsilon(2, 10)))
    experiment = GradFlowExperiment(problem)
    path = experiment_filename(experiment, 1)
    save(path, experiment)
    experiment_loaded = load(path)
    @test experiment_loaded.problem == experiment.problem
    path_prefix = splitpath(path)[1]
    rm(path_prefix, recursive=true)
end

@testset "experiment result IO" begin
    problem = diffusion_problem(2, 10, Blob(blob_epsilon(2, 10)))
    experiment = GradFlowExperiment(problem)
    solve!(experiment)
    result = GradFlowExperimentResult(experiment)
    path = experiment_result_filename(experiment, 1)
    save(path, result)
    result_loaded = load(path)
    @test result_loaded == result
    path_prefix = splitpath(path)[1]
    rm(path_prefix, recursive=true)
end

@testset "timer IO" begin
    timer = TimerOutput()
    @timeit timer "test" sleep(0.5)
    path = timer_filename("test_problem", 2)
    save(path, timer)
    timer_loaded = load(path)
    @test timer_loaded isa TimerOutput
end
end