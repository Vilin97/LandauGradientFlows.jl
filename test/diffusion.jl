using GradientFlows, StableRNGs

d = 2
n = 2000
for solver in [Exact(), SBTM(mlp(d, depth=1, rng=StableRNG(321))), Blob(0.16)]
    problem = diffusion_problem(d, n, solver; rng=StableRNG(123))
    test_prob(problem)
end