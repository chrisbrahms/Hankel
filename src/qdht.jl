"""
    QDHT([p, ] R, N; dim=1)

`p`-th order quasi-discrete Hankel transform over aperture radius `R` with `N` samples
which transforms along dimension `dim`. If not given, `p` defaults to 0.

After:

[1] L. Yu, M. Huang, M. Chen, W. Chen, W. Huang, and Z. Zhu, Optics Letters 23 (1998)

[2] M. Guizar-Sicairos and J. C. Gutiérrez-Vega, JOSA A 21, 53 (2004)

but with some alterations:

The transform matrix T is not the same as C/T defined in [1, 2].
Instead of dividing by J₁(αₚₙ)J₁(αₚₘ) we divide by J₁(αₚₙ)^2. This cancels out
the factor between f and F so we do not have to mutltiply (divide) by J₁(αₚₙ) (J₁(αₚₘ)) before
and after applying the transform matrix.

Follows [`AbstractFFT`](https://github.com/JuliaMath/AbstractFFTs.jl) approach of applying
fwd and inv transform with `mul` and `ldiv`.

To calculate radial integrals of functions sampled using `QDHT`, use [`integrateR`](@ref)
and [`integrateK`](@ref).

The type of the coefficients is inferred from the type of `R` (but is promoted to be at
least `Float`), so for arbitrary precision use `QDHT([p, ] BigFloat(R), ...)`.
"""
struct QDHT{nT<:Real, pT<:Real} <: AbstractQDHT{nT}
    p::pT # Order of the transform
    N::Int # Number of samples
    T::Array{nT, 2} # Transform matrix
    J1sq::Array{nT, 1} # J₁² factors
    K::nT # Highest spatial frequency
    k::Vector{nT} # Spatial frequency grid
    R::nT # Aperture size (largest real-space coordinate)
    r::Vector{nT} # Real-space grid
    scaleR::Vector{nT} # Scale factor for real-space integration
    scaleK::Vector{nT} # Scale factor for frequency-space integration
    scaleRK::nT # Scalar factor multiplied/divided during fwd/rev transform
    dim::Int # Dimension along which to transform
end

function QDHT(p, R, N; dim=1)
    p = convert(typeof(R), p)
    roots = besselj_zero.(p, 1:N) # type of besselj_zero is inferred from first argument
    S = besselj_zero(p, N+1)
    r = roots .* R/S # real-space vector
    K = S/R # Highest spatial frequency
    k = roots .* K/S # Spatial frequency vector
    J₁ = abs.(besselj.(p+1, roots))
    J₁sq = J₁ .* J₁
    T = 2/S * besselj.(p, (roots * roots')./S)./J₁sq' # Transform matrix

    K, R = promote(K, R) # deal with R::Int

    scaleR = 2/K^2 ./ J₁sq # scale factor for real-space integration
    scaleK = 2/R^2 ./ J₁sq # scale factor for reciprocal-space integration
    scaleRK = R / K
    QDHT(p, N, T, J₁sq, K, k, R, r, scaleR, scaleK, scaleRK, dim)
end

QDHT(R, N; dim=1) = QDHT(0, R, N; dim=dim)

"
    mul!(Y, Q::QDHT, A)

Calculate the forward quasi-discrete Hankel transform of array `A` using the QDHT `Q`
and store the result in `Y`.

# Examples
```jldoctest
julia> q = QDHT(1e-2, 8); A = exp.(-q.r.^2/(1e-3*q.R)); Y = similar(A);
julia> mul!(Y, q, A)
8-element Array{Float64,1}:
  4.326937831591551e-6
  2.3341589529175126e-6
  7.689558743828849e-7
  1.546419420523699e-7
  1.8999259906096856e-8
  1.4159642663129888e-9
  7.013670190083954e-11
 -6.07681871673291e-13
```
"
mul!(::Any, ::QDHT, ::Any)

"
    ldiv!(Y, Q::QDHT, A)

Calculate the inverse quasi-discrete Hankel transform of array `A` using the QDHT `Q`
and store the result in `Y`.

# Examples
```jldoctest
julia> q = QDHT(1e-2, 8); A = exp.(-q.r.^2/(1e-3*q.R)); Y = similar(A);
julia> mul!(Y, q, A);
julia> YY = similar(Y); ldiv!(YY, q, Y);
julia> YY ≈ A
true
```
"
ldiv!(::Any, ::QDHT, ::Any)

"""
    *(Q::QDHT, A)

Calculate the forward quasi-discrete Hankel transform of array `A` using the QDHT `Q`.

# Examples
```jldoctest
julia> q = QDHT(1e-2, 8); A = exp.(-q.r.^2/(1e-3*q.R));
julia> q*A
8-element Array{Float64,1}:
  4.326937831591551e-6
  2.3341589529175126e-6
  7.689558743828849e-7
  1.546419420523699e-7
  1.8999259906096856e-8
  1.4159642663129888e-9
  7.013670190083954e-11
 -6.07681871673291e-13
```
"""
*(::QDHT, ::Any)

"""
    \\(Q::QDHT, A)

Calculate the inverse quasi-discrete Hankel transform of array `A` using the QDHT `Q`.

# Examples
```jldoctest
julia> q = QDHT(1e-2, 8); A = exp.(-q.r.^2/(1e-3*q.R));
julia> Ak = q*A;
julia> q \\ Ak ≈ A
true
```
"""
\(::QDHT, ::Any)

"""
    integrateR(A, Q::QDHT; dim=1)

Radial integral of `A`, over the aperture of `Q` in real space.

Assuming `A` contains samples of a function `f(r)` at sample points `Q.r`, then
`integrateR(A, Q)` approximates ∫f(r)r dr from r=0 to r=∞.

!!! note
    `integrateR` and `integrateK` fulfill Parseval's theorem, i.e. for some array `A`,
    `integrateR(abs2.(A), q)` and `integrateK(abs2.(q*A), q)` are equal, **but**
    `integrateR(A, q)` and `integrateK(q*A, q)` are **not** equal.

!!! warning
    using `integrateR` to integrate a function (i.e. `A` rather than `abs2(A)`) is only
    supported for the 0th-order QDHT. For more details see [Derivations](@ref).

# Examples
```jldoctest
julia> q = QDHT(10, 128); A = exp.(-q.r.^2/2);
julia> integrateR(abs2.(A), q) ≈ 0.5 # analytical solution of ∫exp(-r²)r dr from 0 to ∞
true
```
"""
integrateR(::Any, ::QDHT)

"""
    integrateK(Ak, Q::QDHT; dim=1)

Radial integral of `A`, over the aperture of `Q` in reciprocal space.

Assuming `A` contains samples of a function `f(k)` at sample points `Q.k`, then
`integrateR(A, Q)` approximates ∫f(k)k dk from k=0 to k=∞.

!!! note
    `integrateR` and `integrateK` fulfill Parseval's theorem, i.e. for some array `A`,
    `integrateR(abs2.(A), q)` and `integrateK(abs2.(q*A), q)` are equal, **but**
    `integrateR(A, q)` and `integrateK(q*A, q)` are **not** equal.

# Examples
```jldoctest
julia> q = QDHT(10, 128); A = exp.(-q.r.^2/2);
julia> integrateR(abs2.(A), q) ≈ 0.5 # analytical solution of ∫exp(-r²)r dr from 0 to ∞
true
julia> Ak = q*A;
julia> integrateK(abs2.(Ak), q) ≈ 0.5 # Same result
true

```
"""
integrateK(::Any, ::QDHT)

"""
    onaxis(Ak, Q::QDHT; dim=Q.dim)

Calculate on-axis sample in space (i.e. at r=0) from transformed array `Ak`.

# Examples
```jldoctest
julia> q = QDHT(10, 128); A = exp.(-q.r.^2/2);
julia> onaxis(q*A, q) ≈ 1 # should be exp(0) = 1
true
```
"""
function onaxis(Ak, Q::QDHT; dim=Q.dim)
    Q.p == 0 || throw(
        DomainError("on-axis samples can only be obtained for 0th-order transforms"))
    J₀₀ .* integrateK(Ak, Q; dim=dim)
end

"""
    symmetric(A, Q::QDHT)

Create symmetric array from samples in `A`, including on-axis sample.

Given `A`, sampled at `[r₁, r₂, r₃, ...]`, generates array sampled at
`[...-r₃, -r₂, -r₁, 0, r₁, r₂, r₃...]`

# Examples
```jldoctest
julia> q = QDHT(10, 128); A = exp.(-q.r.^2);
julia> As = symmetric(A, q);
julia> size(As)
(257,)
julia> As[1:128] == A[128:-1:1]
true
julia> As[129] ≈ 1 # should be exp(0) = 1
true
julia> As[130:end] == A
true
```
"""
symmetric(::Any, ::QDHT)

"""
    Rsymmetric(Q::QDHT)

Create radial coordinate array to go along with `symmetric(A, Q::QDHT)`.

# Examples
```jldoctest
julia> q = QDHT(10, 4);
julia> q.r
4-element Array{Float64,1}:
 1.6106347946239767
 3.697078919099734
 5.795844623798052
 7.8973942990196395
julia> Rsymmetric(q)
9-element Array{Float64,1}:
 -7.8973942990196395
 -5.795844623798052
 -3.697078919099734
 -1.6106347946239767
  0.0
  1.6106347946239767
  3.697078919099734
  5.795844623798052
  7.8973942990196395
```
"""
Rsymmetric(::QDHT)

"""
    oversample(A, Q::QDHT; factor::Int=4)

Oversample (smooth) the array `A`, which is sampled with the `QDHT` `Q`, by a `factor`.

This works like Fourier-domain zero-padding: a new `QDHT` is created with the same radius,
but `factor` times more points. The existing array is transformed and placed onto this
new spatial frequency grid, and the rest filled with zeros. Transforming back yields the
same shape in space but with more samples.

!!! note
    Unlike in zero-padding using FFTs, the old and oversampled **spatial** grids do not
    have any sampling points in common.
"""
oversample(::Any, ::QDHT)

function oversample(Q::QDHT; factor::Int=4)
    factor == 1 && return Q
    return QDHT(Q.p, Q.R, factor*Q.N, dim=Q.dim)
end
