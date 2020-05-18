module Utility
export listofvectors, listofmatrices, geomspace, asunitless
using StaticArrays
using Unitful

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

end # module
