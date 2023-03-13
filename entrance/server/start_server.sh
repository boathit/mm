#!/bin/bash

#python server.py -c fmm_config.json -p 1236 &

#export FLASK_APP=flask_server.py
#flask run --host=0.0.0.0 --port 1236 --with-threads &

city=$1
port=$2
num_workers=$3

python ubodt_gen.py $city
python fmm_config_gen.py $city
gunicorn -w $num_workers -b 0.0.0.0:$port flask_server:app &

echo "Server started and is listening at port: $port"
echo "Test like: python flask_client.py 1236"