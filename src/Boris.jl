module Boris

export boris, trace_particles

using Base.Threads
using ProgressMeter
using LinearAlgebra
using StaticArrays
using Random
using Unitful
using Unitful:Quantity, 𝐋, 𝐓, 𝐈, 𝐌, unit
import PhysicalConstants.CODATA2018: m_p, e

using ..PlutoUnits

mutable struct Particle{X,V,QM}
    x::SVector{3,Quantity{Float64,𝐋,X}}
    v::SVector{3,Quantity{Float64,𝐋/𝐓,V}}
    qm::Quantity{Float64,𝐈*𝐓/𝐌, QM}
    Particle{X,V,QM}(x,v,qm) where {X,V,QM} = new{X,V,QM}(x,v,qm)
end
function Particle(x, v, qm)
    UX = typeof(unit(eltype(x)))
    UV = typeof(unit(eltype(v)))
    UQM = typeof(unit(qm))
    Particle{UX,UV,UQM}(x, v, qm)
end
function Base.convert(::Type{Particle{A,B,C}}, p::Particle{AA,BB,CC}) where {A,B,C,AA,BB,CC}
    if (A,B,C) == (AA,BB,CC)
        return p
    end
    Particle{A,B,C}(p.x, p.v, p.qm)
end
function Base.copy(p::Particle)
    Particle(p.x, p.v, p.qm)
end

struct Fields{T, U}
    E::T
    B::U
end

struct Domain{T}
    min_x::T
    min_y::T
    min_z::T
    max_x::T
    max_y::T
    max_z::T
end
Domain(a,b,c,d,e,f) = Domain(promote(a,b,c,d,e,f)...)
Domain(boundaries::Tuple{T,T,T}) where T<:Tuple{U,U} where U = Domain(
    boundaries[1][1], boundaries[2][1], boundaries[3][1],
    boundaries[1][2], boundaries[2][2], boundaries[3][2]
)
in(x, d::Domain) = d.min_x <= x[1] <= d.max_x && d.min_y <= x[2] <= d.max_y && d.min_z <= x[3] <= d.max_z
in(p::Particle, d::Domain) = in(p.x, d)
function Random.rand(rng::AbstractRNG, d::Random.SamplerTrivial{Domain{T}}) where T
    d = d[]
    SVector{3,T}(
        d.min_x + (d.max_x - d.min_x)*rand(typeof(one(T))),
        d.min_y + (d.max_y - d.min_y)*rand(typeof(one(T))),
        d.min_z + (d.max_z - d.min_z)*rand(typeof(one(T)))
    )
end
Base.eltype(::Type{Domain{T}}) where T = SVector{3,T}

function vstep(v,dt,E,B)
    t = B*dt/2
    s = 2t/(1+t⋅t)

    v⁻ = v + E*dt/2
    v′ = v⁻ + v⁻ × t
    v⁺ = v⁻ + v′ × s
    return v⁺ + E*dt/2
end

function xstep(x,dt,v)
    x + v*dt
end

function step(x,v,dt,E,B,qm)
    EE = qm*E(x[1], x[2], x[3])
    BB = qm*B(x[1], x[2], x[3])
    rv = vstep(v, dt, EE, BB)
    rx = xstep(x, dt, rv)
    return rx, rv
end
step(p::Particle, f::Fields, dt) = step(p.x, p.v, dt, f.E, f.B, p.qm)

function boris(xinit, vinit, dt, E, B, N, m=m_p, q=e)
    ret_x = Vector{typeof(xinit)}(undef, N+1)
    ret_v = Vector{typeof(vinit)}(undef, N+1)
    ret_x[1] = xinit
    ret_v[1] = vinit
    qm = q/m
    @inbounds for i in 1:N
        ret_x[i+1], ret_v[i+1] = step(ret_x[i], ret_v[i], dt, E, B, qm)
    end
    return ret_x, ret_v
end

function bounds_handler!(p, domain)
    if p.x[2] > domain.max_y
        p.x = SA[p.x[1],p.x[2]-(domain.max_y-domain.min_y), p.x[3]]
    elseif p.x[2] < domain.min_y
        p.x = SA[p.x[1],p.x[2]+(domain.max_y-domain.min_y), p.x[3]]
    end

    if p.x[3] > domain.max_z
        p.x = SA[p.x[1],p.x[2], p.x[3]-(domain.max_z-domain.min_z)]
    elseif p.x[3] < domain.min_z
        p.x = SA[p.x[1],p.x[2],p.x[3]+(domain.max_z-domain.min_z)]
    end
end

function advance!(particles, fields, domain, dt)
    to_delete = []
    for (i,p) in enumerate(particles)
        bounds_handler!(p, domain)
        p.x, p.v = step(p, fields, dt)
        if p.x[1] < domain.min_x # delete particles after they go too far downstream
            push!(to_delete, i)
        end
    end
    deleteat!(particles, to_delete)
end

function trace_particles!(particles, add_particles!, fields, domain, dt, N; saveat=N)
    return_as_list = length(saveat) != 1
    if return_as_list
        saved = Vector{Vector{eltype(particles)}}(undef, 0)
    end
    @showprogress for i in 1:N
        add_particles!(particles)
        advance!(particles, fields, domain, dt)
        if i ∈ saveat
            if return_as_list
                push!(saved, copy.(particles))
            else
                return particles
            end
        end
    end
    return saved
end
function trace_particles(particles, add_particles!, fields, domain, dt, N; saveat=N)
    particles = copy.(particles)
    trace_particles!(particles, add_particles!, fields, domain, dt, N; saveat=saveat)
end
function trace_particles(add_particles!, fields, domain, dt, N; saveat=N)
    T = Particle{typeof(u"Rp"),typeof(u"km/s"),typeof(u"C/kg")}
    particles = Vector{T}(undef, 0)
    trace_particles!(particles, add_particles!, fields, domain, dt, N; saveat=saveat)
end

end # module
