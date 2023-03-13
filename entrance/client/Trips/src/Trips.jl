module Trips 

using Parameters
using HDF5, CSV, DataFrames, ProgressMeter
using Distances: euclidean
import JSON, BSON, FileIO

include("SpatialUtils.jl")
using .SpatialUtils
export gps2webmercator, webmercator2gps, wktlinestring2lonlat, lonlat2wktlinestring, 
       linear_interpolate, wgs2gcj, gcj2wgs

export Trip, readtripsharbin, readtripsgaia, readtripsporto, 
       readtripscsv, readtripsbson, readtripsjld2, readtripsh5, readtripsjson,
       writetripscsv, writetripsbson, writetripsjld2, writetripsh5, writetripsjson

@with_kw mutable struct Trip
    lon::Vector{Float64} = []
    lat::Vector{Float64} = []
    tms::Vector{Float64} = []

    devid::Int = -1 # device id

    ## opath .== cpath[index .+ 1]
    opath::Vector{Int} = []
    cpath::Vector{Int} = []
    index::Vector{Int} = []
    ## offset ratio on each edge
    ratio::Vector{Float64} = []
    spdist::Vector{Float64} = []

    mgeom::String = ""
    pgeom::String = ""

    ## matched or not
    state::Bool = false
    ## valid trip or not
    validspeed::Bool = true
end

# mutable struct Trip{T<:AbstractFloat}
#     lon::Vector{T}
#     lat::Vector{T}
#     tms::Vector{T}

#     devid::Int # device id

#     ## opath .== cpath[index .+ 1]
#     opath::Vector{Int}
#     cpath::Vector{Int}
#     index::Vector{Int}
#     ## offset ratio on each edge
#     ratio::Vector{Float64}
#     spdist::Vector{Float64}

#     mgeom::String
# end

# Trip(lon, lat, tms) = Trip(lon, lat, tms, -1, Int[], Int[], Int[], Float64[], Float64[], "")
# Trip(lon, lat, tms, devid) = Trip(lon, lat, tms, devid, Int[], Int[], Int[], Float64[], Float64[], "")

# function Base.show(io::IO, t::Trip)
#     print(io, "Trip: $(length(t.lon)) points")
# end

Base.length(t::Trip) = length(t.lon)

include("tripUtils.jl")

end


    
    