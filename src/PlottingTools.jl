module PlottingTools
export plt, circlegrid, map_projection, vec_coords, geodetic, mapcoords, ccrs, plotdist, plotshape

using PyCall
using LinearAlgebra
using Unitful
using ..Utility
using ..SphericalShapes

const plt = PyNULL()
const Axes3D = PyNULL()
const ccrs = PyNULL()
const unit_sphere = PyNULL()
const map_projection = PyNULL()
const vec_coords = PyNULL()
const geodetic = PyNULL()

function __init__()
   copy!(plt, pyimport("matplotlib.pyplot"))
   copy!(Axes3D, pyimport("mpl_toolkits.mplot3d").Axes3D)
   copy!(ccrs, pyimport("cartopy.crs"))
   copy!(unit_sphere, ccrs.Globe(semimajor_axis=1., semiminor_axis=1., ellipse=nothing))
   copy!(map_projection, ccrs.Mollweide(globe=unit_sphere))
   copy!(vec_coords, map_projection.as_geocentric())
   copy!(geodetic, map_projection.as_geodetic())
end

function mapcoords(vs; from_crs=vec_coords, to_crs=map_projection)
   mc = to_crs.transform_points(from_crs,
      x=getindex.(vs,1),
      y=getindex.(vs,2),
      z=getindex.(vs,3)
   )
   @views (mc[:,1], mc[:,2])
end

py"""
import numpy as np
def plot_sphere(ax, r, x_offset=0, **kwargs):
   u=np.linspace(0,2*np.pi,100)
   v=np.linspace(0,np.pi,100)
   x = r * np.outer(np.cos(u), np.sin(v)) - x_offset
   y = r * np.outer(np.sin(u), np.sin(v))
   z = r * np.outer(np.ones(np.size(u)), np.cos(v))
   return ax.plot_surface(x,y,z,**kwargs)
"""
plot_sphere(ax, r, x_offset=0; kwargs...) = py"plot_sphere"(ax, r, xoffset, kwargs...)

function plot_3d_dist(ax, d)
    ax.scatter(getindex.(d.v, 1), getindex.(d.v,2), getindex.(d.v,3))
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_zlabel("z")
    plot_sphere(ax, 100, 400, alpha=0.6)
end

function plotshape(ax, sp; kwargs...)
   es = collect(Iterators.flatten(edges(sp)))
   ax.plot(mapcoords(es, to_crs=geodetic)...; transform=geodetic, kwargs...)
end

function circlepoints(a,N=100)
   [(cos(a), sin(a)*sin(t), -sin(a)*cos(t)) for t in 2π/N*(0:N)]
end

function circlegrid(ax, N=5)
   for a in π/(N+1)*(1:N)
      ax.plot(mapcoords(circlepoints(a), to_crs=geodetic)..., transform=geodetic, color="gray", linewidth=0.5, alpha=0.75)
   end
end

function mapfigure()
    fig, ax = plt.subplots(subplot_kw=Dict("projection"=>map_projection))
    ax.set_global()
    circlegrid(ax)
    ax.background_patch.set_facecolor("lightgray")
    return fig, ax
end

pepssi_fov_polys(et) = [fov_polygon("NH_PEPSSI_S$(i)", et) for i in 0:5]
function plot_pepssi(ax, et)
    polys = pepssi_fov_polys(et)
    plotshape(ax, polys[1], color="blue")
    for p in @view polys[2:end]
        plotshape(ax, p, color="darkgray")
    end
end

function plot_dist(fig, ax, d; marker=".", s=30.0, kwargs...)
   l = -asunitless(d.v)
   E = ustrip(uconvert.(u"keV", energy.(d)))
   mappable = ax.scatter(mapcoords(l)...; marker=marker, s=s, c=E, kwargs...)
   cb = fig.colorbar(mappable)
   cb.set_label("Energy (keV)")
end
plot_sun(ax) = ax.scatter(mapcoords([[1.,0.,0.]])..., marker="*", edgecolors="k", color="gold", s=200)
plot_pluto(ax,pos::AbstractArray) = ax.scatter(mapcoords([-ustrip(pos)])..., marker=raw"$♥$",  edgecolors="k", color="chocolate", s=100)
plot_pepssi_view(s, et) = plot_pepssi_view(mapfigure()..., s, et)
function plot_pepssi_view(fig, ax, s, et)
    l = location(et)
    d = Distribution(s, l)
    d = filter(hastag(He_ipui), d)
    plot_dist(fig, ax, d)
    plot_sun(ax)
    plot_pluto(ax, l)
    plot_pepssi(ax, et)
end


"""
Expand x and concat y so that they may be used for a scatter plot. That is,
each y needs to be concatinated and x needs to be expanded by duplicating its
entries.

Examples:
julia> x,y = scatterargs([1,2,3], [[1,2],[1,2,3],[1]])
([1,1,2,2,2,3], [1,2,1,2,3,1])
julia> scatter(x,y)

julia> x,y,s = scatterargs([1,2,3], [[1,2],[1,2,3],[1]], [[20,10],[30,20,10],[10]])
([1,1,2,2,2,3], [1,2,1,2,3,1], [20,10,30,20,10,10])
julia> scatter(x,y, markersize=s)
"""
function scatterargs(x, eachy...)
    # Check that arguments are well formed
    # recall that eachy is a tuple of Vectors of Vectors.
    # 1. Each y in `eachy` should have the same length as `x`
    # (i.e. y contains one list for each element of `x`)
    @assert all(length.(eachy) .== length(x))

    # 2. The sequence of lengths of all the lists in each y in `eachy` must be
    # the same. (i.e. length.(y_1) == length.(y_2) for each y_i in `eachy`)
    # this sequence of lengths, `N`, is used below to expand x.
    fy, ry = firstrest(eachy)
    N = length.(fy)
    for y in ry
        @assert length.(y) == N
    end

    # The arguments should be well formed, so we expand x and concatinate the ys.
    x = expandby(x, N)
    return x, reduce.(vcat, eachy)...
end
expandby(a, n) = reduce(vcat, fill.(a,n))

"Prepare a spectrogram figure"
function especfigure()
    fig, ax = plt.subplots()
    # Setting xlim to work around an error that occurs when you add a Datetime
    # locator and formatter to an axis that contains zero. (An empty axis
    # contains zero by default.)
    ax.set_xlim(2,3)
    # setting xlim turns off autoscale, so turn it back on.
    ax.autoscale()
    mdates = pyimport("matplotlib.dates")
    locator = mdates.AutoDateLocator()
    formatter = mdates.ConciseDateFormatter(locator)
    ax.xaxis.set_major_locator(locator)
    ax.xaxis.set_major_formatter(formatter)
    ax.set_xlabel("Time")
    ax.set_ylabel("Energy (keV)")

    return fig,ax
end

function _espec_basevalues(xs, ds)
    ys = energies.(ds)
    fs = fluxes.(ds)
    scatterargs(xs, ys, fs)
end

"Returns H, xedges, yedges"
function _espec_histogram(xs, ds; kw...)
    xs, ys, fs = _espec_basevalues(xs, ds)
    np.histogram2d(xs, ustrip.(u"keV", ys), bins=25, weights=ustrip.(u"cm^-2 s^-2",fs); kw...)
end

function plot_espec_histogram(fig, ax, xs, ds; hist_kw=Dict(), pcolor_kw=Dict())
    H,xedges,yedges = _espec_histogram(xs, ds; hist_kw...)
    mappable = ax.pcolormesh(xedges, yedges, transpose(H); pcolor_kw...)
    cbar = fig.colorbar(mappable)
    cbar.set_label("Ion flux (cm^-2 s^-1)")
    return H, xedges, yedges, mappable
end

function plot_espec_scatter(fig, ax, xs, ds)
    xs, ys, fs = _espec_basevalues(xs, ds)
    ax.scatter(xs, ys, s=20fs/maximum(fs))
end

end # module
