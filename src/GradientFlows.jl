module GradientFlows

using UnPack: @unpack
using OrdinaryDiffEq: solve, ODEProblem
using DiffEqCallbacks: PresetTimeCallback
using LinearAlgebra, Random
using CUDA
using HCubature: hcubature

import Distributions: MvNormal, Distribution, MultivariateDistribution, mean, cov, gradlogpdf, pdf
import OrdinaryDiffEq.solve
import CUDA: cu
import Statistics.mean, Statistics.cov


const DEFAULT_RNG = Random.default_rng()

include("score.jl")
include("problem.jl")
include("solver.jl")
include("solve.jl")
include("cu.jl")

include("analysis/linalg.jl")
include("analysis/moments.jl")
include("analysis/kde.jl")
include("analysis/Lp.jl")


export GradFlowProblem, Solver
export Exact
export solve
export update!
export diffusion_problem
export cu

export true_dist
export emp_mean, emp_cov
export kde
export Lp_distance, Lp_error
export score

end
