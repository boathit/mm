using HTTP, JSON
using Trips: Trip, lonlat2wktlinestring

headers = ["Content-Type" => "application/json"]

function process_response(response)
    parsed = JSON.parse(response.body |> String)
    if get(parsed, "state", 0) == 1
        cpath    = get(parsed, "cpath", [])
        index    = get(parsed, "indices", [])
        opath    = get(parsed, "opath", [])
        spdist   = get(parsed, "spdist", [])
        offset_t = get(parsed, "offset", [])
        length_t = get(parsed, "length", [])
        mgeom    = get(parsed, "mgeom_wkt", "")
        pgeom    = get(parsed, "pgeom_wkt", "")
        ratio    = length(offset_t) > 0 ? clamp!(offset_t ./ length_t, 0.0, 1.0) : []     
        return @NamedTuple{opath::Vector{Int}, 
                           cpath::Vector{Int},
                           index::Vector{Int},
                           ratio::Vector{Float64},
                           spdist::Vector{Float64},
                           mgeom::String,
                           pgeom::String}((opath, cpath, index, ratio, spdist, mgeom, pgeom)), true
    else
        return @NamedTuple{opath::Vector{Int}, 
                           cpath::Vector{Int},
                           index::Vector{Int},
                           ratio::Vector{Float64},
                           spdist::Vector{Float64},
                           mgeom::String,
                           pgeom::String}(([], [], [], [], [], "", "")), false
    end
end

function match!(trip::Trip, url::String)
    gps_wkt = lonlat2wktlinestring(trip.lon, trip.lat)
    response = HTTP.post(url, headers, JSON.json(Dict("gps_wkt" => gps_wkt)))
    processed, state = process_response(response)
    trip.opath = processed.opath 
    trip.cpath = processed.cpath
    trip.index = processed.index
    trip.ratio = processed.ratio
    trip.mgeom = processed.mgeom
    trip.pgeom = processed.pgeom
    trip.spdist = processed.spdist
    trip.state = state
    trip
end