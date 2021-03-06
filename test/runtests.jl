using HybridTools
using Test, NearestNeighbors, PyCall, Unitful
using PhysicalConstants.CODATA2018: m_p, e
using StaticArrays
using Random
const RNG = MersenneTwister(1234)

const st = pyimport("spice_tools")

@testset "All Tests" begin
    @test Trajectory(st.flyby_start, st.flyby_end, 60) isa Trajectory
    @testset "Simulation tests" begin
        s = Simulation("/home/nathan/data/chinook/pluto-3")
        @test s isa Simulation
        @test s.tree isa KDTree
        @test touching(s,[0,0,0]) == touching(s,[0,0,0]u"km",s.dx*u"km")
        @test Distribution(s,[0.,0.,0.]u"km") isa Distribution
        @test Distribution.(s,[[0.,0.,0.], [1.,1.,1.]]u"km") isa Vector{<:Distribution}
    end
    @testset "Sensors tests" begin
        test_kT = 1.5u"eV"
        m = 4*m_p
        N = 1000
        maxwl = Distribution(
            [(test_kT/m)^(1/2).*randn(RNG, 3) .+ [5.0,0.,0.]u"km/s" for _ in 1:N],
            fill(m,N),
            fill(e,N),
            ones(N)u"m^-3",
            ones(Int, N)
        )
        bulk_v = bulkvelocity(maxwl)
        @test isapprox(bulk_v[1], 5u"km/s", rtol=0.1)
        @test isapprox(bulk_v[2], 0u"km/s", atol=1u"km/s")
        @test isapprox(bulk_v[3], 0u"km/s", atol=1u"km/s")
        @test isapprox(thermalenergy(maxwl), test_kT, rtol=0.1)
    end

    include("boristests.jl")
end # outer testset
