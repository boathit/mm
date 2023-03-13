# mm

`mm` is backended by [`fmm`](https://github.com/cyang-kth/fmm).

## Building the docker and launching the fmm server

Navigating to the `mm` folder and running

```sh
bash build.sh
```

the above command will build the docker and create a folder `trips` which will be used to hold
the input and output trajectory datasets. To run the built docker, execute 

```sh
bash run.sh
```

and it enters the running container and stays in `/mm/entrance`. The script `start.sh`
will launch the fmm server with the specified parameters such as

```sh
city="harbin"
port=1236
num_workers=5
```

you can change the parameters and run the script to start the server.

```sh
bash start.sh chengdu
```

## Running the client

Move your trajectory files into `mm/trips/input`. 

You can choose to run the client either in the container or in the host.

Note that if you want to run the client in the container you **cannot use symbol links** for the trajectory files, 
and have to move them mannually to `mm/trips/input` but symbol links are fine for running in the host.

### Running in the container

```sh
cd /mm/entrance/client && bash start_client.sh $city $port $num_workers $write_format
```

where `$city`, `$port`, `$num_workers` are parameters you specified in `/mm/entrance/start.sh`. For `$write_format`,
the available formats are "csv", "jld2", "h5"; it is saved as `csv` format by default but if you wish to use the output
in Julia, the "jld2" format is recommended because it enjoys much faster loading speed. The loading time (including the parsing time) "jld2" < "h5" < "csv". Their corresponding reading functions `readtripscsv`, `readtripsjld2` `readtripsh5`, can be found in file `tripUtils.jl`.

### Running in the host

First, install [`julia-1.8`](https://julialang.org/downloads/) and navigate to `mm/entrance/client`, run

```sh
bash start_client.sh $city $port $num_workers $write_format
```

## QA

* The fmm parameters can be configured in `mm/entrance/server/fmm_config_gen.py`.
* The map data is stored in `mm/entrance/data/cities/`.
* You can also download the latest osm data using `mm/entrance/server/osm_data.py` where you can specify the bounding box, like `python osm_data.py harbin`.
* The input trajectory files are put in `mm/trips/input/`.
* The matching results are saved in `mm/trips/output/`.
* The matching output csv file is seperated by ';', the columns are all the fields defined in `struct Trip` in `Trips.jl`.
* The `struct Trip` has a field `validspeed` (bool) and the matched trajectories with speed more than 35m/s are considered invalid (`validspeed=false`).
* The jld2 output format is recommened if using in Julia language.
* If you want to obtain other field returned by `fmm` you can change `Trip` in `Trips.jl` 
  and `process_response` in `mapmatcher.jl`
* `num_workers` is the number of workers employed to perform the matching tasks, you can set it a large number
  if your machine has many cpu cores.
  