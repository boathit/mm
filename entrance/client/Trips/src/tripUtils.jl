
"""
    readtripsharbin(tripfile::String)

Read Harbin taxi dataset.
"""
function readtripsharbin(tripfile::String)
    trips = Trip[]
    h5open(tripfile, "r") do f
        ntrips = read(f["/meta/ntrips"])
        @showprogress for i = 1:ntrips
            lon = read(f["/trip/$i/lon"])
            lat = read(f["/trip/$i/lat"])
            tms = read(f["/trip/$i/tms"])
            trip = Trip(lon=lon, lat=lat, tms=tms)
            length(trip) >= 2 && push!(trips, trip)
            #i >= 10000 && break
        end
    end
    trips
end

"""
    readtripsgaia(tripfile::String, header=nothing)

Read trips from csvfile. If `header` is unspecified, the csvfile must contain
columns [:devid, :tripid, :tms, :lon, :lat].
"""
function readtripsgaia(tripfile::String, header=[:devid, :tripid, :tms, :lon, :lat])
    df = CSV.File(tripfile, header=header) |> DataFrame
    hasdevid = :devid in names(df)
    trips = Trip[]
    for sdf in groupby(df, :tripid)
        sdf = DataFrame(sdf)
        sort!(sdf, :tms)
        lon = convert(Vector{Float64}, sdf.lon)
        lat = convert(Vector{Float64}, sdf.lat)
        tms = convert(Vector{Float64}, sdf.tms) .+ 8*3600.0 # (GMT+8)
        trip = Trip(lon=lon, lat=lat, tms=tms)
        length(trip) >= 2 && push!(trips, trip)
    end
    trips
end

function readtripsporto(csvfile::String)
    df = CSV.File(csvfile) |> DataFrame
    df = df[df.MISSING_DATA .== false, :]
    sort!(df, [:TIMESTAMP])
    
    trips = Trip[]
    @showprogress for (taxi_id, stms, polyline) in zip(df.TAXI_ID, df.TIMESTAMP, df.POLYLINE)
        try
            points = Meta.parse(polyline) |> eval
            if length(points) >= 2
                lon = first.(points)
                lat = last.(points)
                tms = stms .+ collect(0:length(lon)-1) * 15.0
                trip = Trip(lon=lon, lat=lat, tms=tms, devid=taxi_id)
                push!(trips, trip)
            end
        catch e
            continue
        end
    end
    println("$min_lon, $max_lon, $min_lat, $max_lat")
    trips
end

function writetripsjson(tripfile::String, trips::Vector{Trip}, names=[])
    names = length(names) == 0 ? fieldnames(Trip) : names
    open(tripfile, "w") do f
        # dicts = [Dict([name => getfield(trip, name) for name in names]) for trip in trips]
        # write(f, JSON.json(dicts))
        write(f, "[" * "\n")
        for trip in trips[1:end-1]
            js = JSON.json(Dict([name => getfield(trip, name) for name in names]))
            write(f, js * "," * "\n")
        end
        js = JSON.json(Dict([name => getfield(trips[end], name) for name in names]))
        write(f, js * "\n" * "]")
    end
end

function readtripsjson(jsonfile::String)
    dicts = JSON.parsefile(jsonfile)
    names = keys(dicts[1])
    trips = Trip[]
    @showprogress for d in dicts
        trip = Trip()
        for name in names
            setproperty!(trip, Symbol(name), d[name])
        end
        push!(trips, trip)
    end
    trips
end

function writetripscsv(tripfile::String, trips::Vector{Trip})
    stringify(x) = typeof(x) <: Array ? "[" * join(x, ",") * "]" : string(x)
    for name in fieldnames(Trip)
        @eval $(Symbol("$(name)_v")) = String[]
    end
    for trip in trips
        for name in fieldnames(Trip)
            push!(eval(Symbol("$(name)_v")), getfield(trip, name) |> stringify)
        end
    end
    argstr = join(["$name=$(Symbol("$(name)_v"))" for name in fieldnames(Trip)], ",")
    df = DataFrame("(" * argstr * ")" |> Meta.parse |> eval)
    CSV.write(tripfile, df; delim=';')
end

"""
    parsedataframe(df::DataFrame)

Parsing the DataFrame saved by `writetripscsv(tripfile::String, trips::Vector{Trip})`.
"""
function parsedataframe(df::DataFrame)
    function parserow(row)
        parsefield(T, v) = T <: Array ? eval(Meta.parse(v)) : v
        trip = Trip()
        for (name, T) in zip(fieldnames(Trip), fieldtypes(Trip))
            setproperty!(trip, name, parsefield(T, row[name]))
        end
        trip
    end
    for name in names(df)
        Union{Missing, String} <: eltype(df[!, name]) && replace!(df[!, name], missing=>"")
    end

    println("Parsing $(size(df, 1)) rows...")
    trips = Trip[]
    @showprogress for row in eachrow(df)
        push!(trips, parserow(row))
    end
    return trips
end

function readtripscsv(tripfile::String)
    CSV.File(tripfile, delim=';') |> DataFrame |> parsedataframe
end

function writetripsh5(tripfile::String, trips::Vector{Trip})
    h5open(tripfile, "w") do f
        f["/meta/n"] = length(trips)
        for i in 1:length(trips)
            for name in fieldnames(Trip)
                f["/trip/$i/$name"] = getfield(trips[i], name)
            end
        end
    end
end

function readtripsh5(tripfile::String)
    trips = Trip[]
    h5open(tripfile, "r") do f
        n = read(f["/meta/n"])
        @showprogress for i in 1:n
            trip = Trip()
            for name in fieldnames(Trip)
                setproperty!(trip, name, read(f["/trip/$i/$name"]))
            end
            push!(trips, trip)
        end
    end
    trips
end

"""
    writetripsbson(tripfile::String, trips::Vector{Trip})

Write the trips into the bson file. It enjoys much faster loading speed 
in comparison to the csv file, but could only be used in Julia.
"""
function writetripsbson(tripfile::String, trips::Vector{Trip})
    BSON.bson(tripfile, trips=trips)
end

function readtripsbson(tripfile::String)
    d = BSON.load(tripfile, @__MODULE__)
    convert(Vector{Trip}, d[:trips])
end

"""
    writetripsjld2(tripfile::String, trips::Vector{Trip})

Write the trips into the jld2 file. It enjoys much faster loading speed 
in comparison to the csv file, but could only be used in Julia.
"""
function writetripsjld2(tripfile::String, trips::Vector{Trip})
    FileIO.save(tripfile, "trips", trips)
end

function readtripsjld2(tripfile::String)
    FileIO.load(tripfile, "trips")
end


gcj2wgs!(trip::Trip) = begin
    trip.lon, trip.lat = gcj2wgs(trip.lon, trip.lat)
    trip
end

"""
    validspeed(trip::Trip)

Return true if the trip is a valid trip which maximum speed cannnot exceed 35
otherwise return false.
"""
function validspeed(trip::Trip, maxspeed=35)
    # for i = 2:length(trip.tms)
    #     px, py = gps2webmercator(trip.lon[i-1], trip.lat[i-1])
    #     cx, cy = gps2webmercator(trip.lon[i], trip.lat[i])
    #     euclidean([px, py], [cx, cy]) / (trip.tms[i] - trip.tms[i-1]) > 40 && return false
    # end
    # true
    !trip.state && return false
    delta = trip.tms[2:end] .- trip.tms[1:end-1]
    delta .= trip.spdist[2:end] * 10000 ./ delta
    maximum(delta) < maxspeed
end

function get_bound(trips::Vector{Trip})
    min_lon, max_lon, min_lat, max_lat = 180., -180., 90., -90.
    for trip in trips
        min_lon = min(min_lon, minimum(trip.lon))
        max_lon = max(max_lon, maximum(trip.lon))
        min_lat = min(min_lat, minimum(trip.lat))
        max_lat = max(max_lat, maximum(trip.lat))
    end

end

function inregion(trip::Trip, bound::Tuple)
    (min_lon, max_lon, min_lat, max_lat) = bound
    function inregion(lon, lat)
        min_lon <= lon <= max_lon &&
        min_lat <= lat <= max_lat
    end
    all(inregion.(trip.lon, trip.lat))
end