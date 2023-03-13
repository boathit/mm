#!/bin/bash

if [ $# -eq 1 ]; then
    city=$1
    port=1236
    num_workers=5
    write_format="json"
    echo "city:$city port:$port num_workers:$num_workers write_format:$write_format"
elif [ $# -eq 4 ]; then
    city=$1
    port=$2
    num_workers=$3
    write_format=$4
    echo "city:$city port:$port num_workers:$num_workers write_format:$write_format"
else 
    echo "running as 'bash start_client.sh city port num_workers write_format'"
    exit 1
fi

if [ $write_format = "csv" ]; then
    echo "You select to save the output in csv format.\
    But if using output in Julia, the jld2 format is recommended."
fi

export JULIA_PKG_SERVER=https://mirrors.tuna.tsinghua.edu.cn/julia

#cd Trips
#julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
#cd ../scripts

julia -e 'using Pkg; Pkg.develop(path="./Trips")'

cd scripts/

#export JULIA_LOAD_PATH=`pwd`:$JULIA_LOAD_PATH

julia -p $num_workers client.jl --city $city --port $port --write_format $write_format

cd .. && ls ../../trips/output