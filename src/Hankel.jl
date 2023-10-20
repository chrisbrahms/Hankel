module Hankel
import SpecialFunctions: besselj, gamma
using GSL: GSL
using Roots: Roots
import LinearAlgebra: mul!, ldiv!
using LinearAlgebra: axpy!, dot
import Base: *, \
using ChainRulesCore

export QDHT, integrateK, integrateR, onaxis, symmetric, Rsymmetric

const J₀₀ = besselj(0, 0)

include("utils.jl")
include("qdht.jl")
include("chainrules.jl")

end
