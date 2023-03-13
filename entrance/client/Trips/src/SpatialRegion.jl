module SpatialRegion

using Dates, ProgressMeter
using Lazy: @>>
include("Trips.jl")
.using Trips: Trip
include("SpatialUtils.jl")
using .SpatialUtils: gps2webmercator, linear_interpolate, searchrange

export Region, tms2key, create_traffic_tensors

mutable struct Region
    city::String
    minlon::Float64
    minlat::Float64
    maxlon::Float64
    maxlat::Float64
    xstep::Float64
    ystep::Float64

    minx::Float64
    miny::Float64
    maxx::Float64
    maxy::Float64

    numx::Int
    numy::Int

    I::Matrix # inflow
    O::Matrix # outflow
    S::Matrix # speed
    C::Matrix # count
end

function Region(
    city::String,
    minlon::Float64,
    minlat::Float64,
    maxlon::Float64,
    maxlat::Float64,
    xstep::Float64,
    ystep::Float64)
    
    minx, miny = gps2webmercator(minlon, minlat)
    maxx, maxy = gps2webmercator(maxlon, maxlat)
    numx = @>> round(maxx - minx, digits=6)/xstep ceil(Int)
    numy = @>> round(maxy - miny, digits=6)/ystep ceil(Int)
    
    Region(
        city,
        minlon, minlat,
        maxlon, maxlat,
        xstep, ystep,
        minx, miny,
        maxx, maxy,
        numx, numy,
        zeros(Float32, numy, numx),
        zeros(Float32, numy, numx),
        zeros(Float32, numy, numx),
        zeros(Float32, numy, numx)
    )
end

function Base.show(io::IO, r::Region)
    print(io, "City: $(r.city), size: ($(r.numy), $(r.numx)).")
end


"""
    coord2regionoffset(region::Region, x::Float64, y::Float64)

Given a region (city), converting the Web Mercator coordinate to offset tuple

Args:
    region, x, y
Returns:
    xoffset: 0 <= xoffset < region.numx.
    yoffset: 0 <= yoffset < region.numy.
"""
function coord2regionoffset(region::Region, x::Float64, y::Float64)
    xoffset = @>> round(x - region.minx, digits=6) / region.xstep floor(Int)
    yoffset = @>> round(y - region.miny, digits=6) / region.ystep floor(Int)
    xoffset, yoffset
    #yoffset * region.numx + xoffset
end

coord2regionoffset(region::Region, xy::Tuple) = coord2regionoffset(region, xy...)

"""
Given a region (city), converting the GPS coordinate to the offset tuple
"""
function gps2regionoffset(region::Region, lon::Float64, lat::Float64)
    function isinregion(region, lon, lat)
        region.minlon <= lon < region.maxlon &&
        region.minlat <= lat < region.maxlat
    end
    @assert isinregion(region, lon, lat) "lon:$lon lat:$lat out of region:$(region.city)"
    coord2regionoffset(region, gps2webmercator(lon, lat))
end

gps2regionoffset(region::Region, gps::Tuple) = gps2regionOffset(region, gps...)

function reset!(region::Region)
    for field in [:I, :O, :S, :C]
        @eval $region.$field .= 0
    end
end


"""
Create the tensor that counts the number of taxi inflowing and outflowing each
cell in `region` using the `trips`.
"""
function createflowtensor!(region::Region, trips::Vector{Trip})
    function normalizex!(X)
        X ./= sum(X)
        X ./= maximum(X)
    end

    reset!(region)

    for trip in trips
        fine_trip, _, v̄ = linear_interpolate(gps2webmercator.(trip.lon, trip.lat), trip.tms)
        for i = 2:length(fine_trip)
            px, py = coord2regionoffset(region, fine_trip[i-1][1:2]...) .+ 1
            cx, cy = coord2regionoffset(region, fine_trip[i][1:2]...) .+ 1
            if cx ≠ px || cy ≠ py
                region.O[py, px] += 1 # outflow
                region.I[cy, cx] += 1 # inflow
                region.S[cy, cx] += v̄[i] # speed
                region.C[cy, cx] += 1
            elseif v̄[i] ≠ v̄[i-1] # mean speed changes so we count it
                region.S[cy, cx] += v̄[i] # speed
                region.C[cy, cx] += 1
            end
        end
    end
    normalizex!(region.I)
    normalizex!(region.O)
    idx = region.C .> 0
    region.S[idx] ./= region.C[idx]
end

"""
Return the sub-trips falling into time slot [stms, etms].
"""
function timeslotsubtrips(trips::Vector{Trip}, stms::T, etms::T) where T
    subtrips = Trip[]
    for trip in trips
        #(trip.tms[1] > etms || trip.tms[end] < stms) && continue
        a, b = searchrange(trip.tms, stms, etms)
        if a < b
            subtrip = Trip(lon=trip.lon[a:b], lat=trip.lat[a:b], tms=trip.tms[a:b])
            push!(subtrips, subtrip)
        end
    end
    subtrips
end

"""
Return the trips whose start time falling into time slot [stms, etms].
"""
function timeslottrips(trips::Vector{Trip}, stms::T, etms::T, Δmins=5) where T
    filter(trips) do trip
        stms < trip.tms[1] < etms && etms + Δmins*60 > trip.tms[end]
    end
end

"""
Collect the trips in the past 30 minutes of `tms` to create the traffic tensor
along with the trips in the future 50 minutes.
"""
function collectslotdata(region::Region, trips::Vector{Trip}, tms::Float64)
    sort!(trips, by=t -> first(t.tms))
    slotsubtrips = timeslotsubtrips(trips, tms-30*60, tms)
    createflowtensor!(region, slotsubtrips)
    slottrips = timeslottrips(trips, tms, tms+50*60)
    slottrips = filter(t -> t.tms[end]-t.tms[1] >= 1*60, slottrips)
    copy(region.S), slottrips
end

function tms2key(tms, slotsize=20)
    dt = unix2datetime(tms)
    hour, minute = Dates.hour(dt), Dates.minute(dt)
    (Dates.yearmonthday(dt)..., div(hour*60 + minute, slotsize))
end

"""
Create traffic tensors for from trips.

Args
    slotsize (mins): discretizing the time dimension into slots by the `slotsize`.
    duration (mins): collecting the subtrips generated in the past `duration` minutes.
Returns
    a tensor dict with key (year, month, day, i).
"""
function create_traffic_tensors(
    region::Region,
    trips::Vector{Trip},
    day::Union{DateTime,Nothing}=nothing,
    slotsize=20,
    duration=30
)
    #sort!(trips, by=t -> first(t.tms))
    if isnothing(day)
        sdt = unix2datetime(trips[1].tms[1]) |> t -> DateTime(Dates.yearmonthday(t)...)
        edt = unix2datetime(trips[end].tms[1]) |> t -> DateTime(Dates.yearmonthday(t)..., 23, 59, 59)
    else
        sdt = DateTime(Dates.yearmonthday(day)...)
        edt = DateTime(Dates.yearmonthday(day)..., 23, 59, 59)
    end
    traffic_tensor = Dict{Tuple, Matrix}()
    @showprogress for dt in sdt+Dates.Minute(slotsize):Dates.Minute(slotsize):edt
        ## tms is the starting time of a discretized slot [tms, tms+slotsize)
        tms = datetime2unix(dt)
        ## collecting subtrips before tms
        slotsubtrips = timeslotsubtrips(trips, tms - duration * 60, tms)
        createflowtensor!(region, slotsubtrips)

        key = tms2key(tms, slotsize)
        ## copy as S will be rewritten 
        traffic_tensor[key] = copy(region.S)
    end
    traffic_tensor[(Dates.yearmonthday(sdt)..., 0)] = traffic_tensor[(Dates.yearmonthday(sdt)..., 1)]
    return traffic_tensor
end

function get_traffic_tensor(traffic_tensor::Dict, tms, slotsize=20)
    key = tms2key(tms, slotsize)
    get(traffic_tensor, key, [])
end


end # module