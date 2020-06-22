module Utility
export  listofvectors, listofmatrices, geomspace, asunitless, viewasarray,
        @utc2et_str, @utc2datetime_str, getcolumns
using StaticArrays
using Unitful
using PyCall

const st = PyNULL()

function __init__()
    copy!(st, pyimport("spice_tools"))
end

"""
    listofvectors(array)
Convert Array{T,2} to Vector{SVector{3,T}}.
If size(arr,1) != 3, there will be an error.
A copy is made.
"""
function listofvectors(arr::AbstractArray{T,2}) where T
    SVector{3,T}.(eachrow(arr))
end
"Convert Array{T,3} with size (3,3,:) to Vector{SMatrix{3,3,T}}"
function listofmatrices(arr::AbstractArray{T,3}) where T
    SMatrix{3,3,T,9}.(eachslice(arr,dims=1))
end

function geomspace(start, stop, N)
    exp10.(range(log10(start), stop=log10(stop), length=N))
end

"No-copy ustrip for Arrays of StaticArrays of Quantities"
asunitless(A::AbstractArray{SA}) where {Size, Q<:Quantity, SA<:StaticArray{Size, Q}} = reinterpret(similar_type(SA,Unitful.numtype(Q)), A)
viewasarray(x::AbstractArray{SA,1}) where {S,T,SA<:StaticArray{S,T}} = reshape(reinterpret(T,x), (size(SA)...,:))
getcolumns(x::AbstractArray{SA<:StaticArray,1}) = Tuple(getindex.(x, i) for i in 1:length(SA))

macro utc2et_str(t)
    :(st.sp.str2et("2015-7-14T$($t)"))
end
macro utc2datetime_str(t)
    :(st.et2pydatetime(@pluto_et_str $t))
end

end # module
