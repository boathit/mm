module SpatialUtils

using Distances: euclidean

export gps2webmercator, webmercator2gps, wktlinestring2lonlat, lonlat2wktlinestring, 
       linear_interpolate, wgs2gcj, gcj2wgs

const semimajoraxis = 6378137.0
const secret_number = 0.00669342162296594323

function gps2webmercator(lon::T, lat::T) where T<:AbstractFloat
    """
    Converting GPS coordinate to Web Mercator coordinate
    """
    east = lon * 0.017453292519943295
    north = lat * 0.017453292519943295
    t = sin(north)
    semimajoraxis * east, 3189068.5 * log((1 + t) / (1 - t))
end

function webmercator2gps(x::T, y::T) where T<:AbstractFloat
    """
    Converting Web Mercator coordinate to GPS coordinate
    """
    lon = x / semimajoraxis / 0.017453292519943295
    t = exp(y / 3189068.5)
    lat = asin((t - 1) / (t + 1)) / 0.017453292519943295
    lon, lat
end

gps2webmercator(p) = gps2webmercator(p...)
webmercator2gps(p) = webmercator2gps(p...)

"""
Return the start and end index of element in `a` that falls into range [s, e],
and `a` is assumed to be sorted in ascending order.
"""
@inline function searchrange(a::Vector{T}, s::T, e::T) where T<:Real
    searchsortedfirst(a, s), searchsortedlast(a, e)
end

"""
    wktlinestring2lonlat(gps_wkt::String)

Args:
    gps_wkt: "LINESTRING(126.603110 45.742172,126.60328 45.742348,126.60574)"
Returns:
    (lon::Vector{Float64}, lat::Vector{Float64})
"""
function wktlinestring2lonlat(gps_wkt::String)
    @assert startswith(gps_wkt, "LINESTRING(") && endswith(gps_wkt, ")") "invalid linstring $gps_wkt"
    points = gps_wkt[12:end-1] |> x -> split(x, [',', ' ']) .|>  Meta.parse
    points[1:2:end], points[2:2:end]
end

"""
    lonlat2wktlinestring(lon::Vector{T}, lat::Vector{T})

The inverse operation of `wktlinestring2lonlat(gps_wkt::String)`.
"""
function lonlat2wktlinestring(lon::Vector{T}, lat::Vector{T}) where T<:AbstractFloat
    gpsstr = ["$x $y" for (x, y) in zip(lon, lat)] |> xs -> join(xs, ",")
    return "LINESTRING(" * gpsstr * ")"
end

"""
    linear_interpolate(p1::Tuple{T,T}, p2::Tuple{T,T}, t1, t2, Δ)

Insert n points between p1 and p2 where n = d(p1, p2) / Δ, return the interpolated
n+2 points and the mean speed.

    linear_interpolate(trip::Vector{Tuple{T,T}}, tms::Vector, Δ=200.)

Interpolate a trip linearly.
    Args:
      trip: A vector of Webmercator coordinates with timestampes.
    Returns:
      fine_trip: A vector of Webmercator coordinates with mean speed.
"""
linear_interpolate

function linear_interpolate(p1::Tuple{T,T}, p2::Tuple{T,T}, t1, t2, Δ) where T<:Real
    ϵ = 1e-8
    sx, sy = p1
    ex, ey = p2

    d = euclidean([sx, sy], [ex, ey])
    ## inserted points
    p = mod(d, Δ) == 0 ? collect(0:Δ:d)/(d+ϵ) : push!(collect(0:Δ:d), d)/(d+ϵ)
    ## direction
    vx, vy = ex - sx, ey - sy
    v̄ = d / (t2 - t1) # average speed
    collect(zip(sx .+ vx * p, sy .+ vy * p)), t1 .+ (t2-t1) * p, fill(v̄, length(p))
end


function linear_interpolate(trip::Vector{Tuple{T,T}}, tms::Vector, Δ=200.) where T<:Real
    fine_trip, ts, vs = Tuple{T,T}[], T[], T[]
    for i = 2:length(trip)
        points, t, v = linear_interpolate(trip[i-1], trip[i], tms[i-1], tms[i], Δ)
        if i == 2
            append!(fine_trip, points); append!(ts, t); append!(vs, v)
        else
            append!(fine_trip, points[2:end]); append!(ts, t[2:end]); append!(vs, v[2:end])
        end
    end
    fine_trip, ts, vs
end

#@inline isinchina(lon, lat) = 72.004 <= lon <= 137.8347 && 0.8293 <= lat <= 55.8271

function delta_step(lon::T, lat::T) where T<: AbstractFloat

    function transform(x, y)
        init = 20.0 * sin(6pi * x) + 20.0 * sin(2pi * x)
        
        t_lon = 2/3*(init + 20sin(pi * x) + 40sin(pi * x / 3) + 150sin(pi * x / 12) + 300sin(pi * x / 30))
        t_lat = 2/3*(init + 20sin(pi * y) + 40sin(pi * y / 3) + 160sin(pi * y / 12) + 320sin(pi * y / 30))
        t_lon = t_lon + 300 + 1x + 2y + 0.1x^2 + 0.1x*y + 0.1sqrt(abs(x))
        t_lat = t_lat - 100 + 2x + 3y + 0.2y^2 + 0.1x*y + 0.2sqrt(abs(x))
        return t_lon, t_lat
    end
 
    t_lon, t_lat = transform(lon-105, lat-35)
    radian_lat = lat / 180 * pi
    magic = 1 - secret_number * sin(radian_lat)^2
    sqrt_magic = sqrt(magic)
    d_lon = t_lon * 180 / (semimajoraxis / sqrt_magic * cos(radian_lat) * pi)
    d_lat = t_lat * 180 / (semimajoraxis * (1-secret_number) / (magic * sqrt_magic) * pi)
    return d_lon, d_lat
end

@inline wgs2gcj(lon::T, lat::T) where T <: AbstractFloat = begin
    d_lon, d_lat = delta_step(lon, lat)
    return lon + d_lon, lat + d_lat
end 

@inline gcj2wgs(lon::T, lat::T) where T <: AbstractFloat = begin
    d_lon, d_lat = delta_step(lon, lat)
    return lon - d_lon, lat - d_lat
end

@inline wgs2gcj(lon::Vector{T}, lat::Vector{T}) where T <: AbstractFloat = begin
    pairs = wgs2gcj.(lon, lat)
    first.(pairs), last.(pairs)
end

@inline gcj2wgs(lon::Vector{T}, lat::Vector{T}) where T <: AbstractFloat = begin
    pairs = gcj2wgs.(lon, lat)
    first.(pairs), last.(pairs)
end

end