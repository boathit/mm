# @everywhere begin
#     import Pkg
#     Pkg.activate(dirname(@__DIR__))
# end

using Distributed, ArgParse, ProgressMeter, MLStyle
using Trips

@everywhere begin
    using Trips: validspeed, gcj2wgs!
    include("mapmatcher.jl")
end

args = let s = ArgParseSettings()
    @add_arg_table s begin
        "--port"
            arg_type=Int
            default=1236
        "--city"
            arg_type=String
            default="harbin"
        "--write_format"
            arg_type=String
            default="json"
    end
    parse_args(s; as_symbols=true)
end

url =  "http://127.0.0.1:$(args[:port])/match"

inputpath  = "../../../trips/input"
outputpath = "../../../trips/output"
@assert isdir(inputpath) "could find trips/input"
isdir(outputpath) || mkdir(outputpath)
tripfiles  = readdir(inputpath)

porto_bound = (-8.7015, -8.5302, 40.0990, 41.2082)

readtrips, process = @match args[:city] begin
    "chengdu" || "xian" => begin
        readtripsgaia, trip -> begin
            gcj2wgs!(trip)
            match!(trip, url)
            trip.validspeed = validspeed(trip)
            trip
        end
    end
    "harbin" => begin
        readtripsharbin, trip -> begin
            match!(trip, url)
            trip.validspeed = validspeed(trip)
            trip
        end
    end
    "porto" => begin
        readtripsporto, trip -> begin
            match!(trip, url)
            trip.validspeed = validspeed(trip)
            trip
        end
    end
    city => error("unsupported city $city.")
end

writetrips, suffix = @match args[:write_format] begin
    "json" => (writetripsjson, ".json")
    "csv" =>  (writetripscsv, ".csv")
    "bson" => (writetripsbson, ".bson")
    "jld2" => (writetripsjld2, ".jld2")
    "h5" => (writetripsh5, ".h5")
    x => error("unsupported output format $x.")
end

for tripfile in tripfiles
    trips = readtrips(joinpath(inputpath, tripfile))
    args[:city] == "porto" && filter!(trip -> inregion(trip, porto_bound), trips)
    #trips = trips[1:1000]
    println("Processing $(length(trips)) trips in $(tripfile)...")
    @time trips = @showprogress pmap(process, trips)
    states = pmap(trip -> trip.state, trips)
    valids = pmap(trip -> !trip.validspeed, trips)
    writetrips(joinpath(outputpath, splitext(tripfile) |> first |> f -> f * suffix), trips)
    println("File: $tripfile, #Trips: $(length(trips)), ", 
            "#Matched: $(sum(states)), #Invalid: $(sum(valids))")
end

println("The matching outputs are available at trips/output/")