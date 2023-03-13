#!/usr/bin

if [ $# -eq 1 ]; then
    city=$1
else 
    echo "Please provide the city, like 'bash start.sh chengdu'"
    exit
fi

port=1236
num_workers=5

cd server

python ubodt_gen.py $city
python fmm_config_gen.py $city
gunicorn -w $num_workers -b 0.0.0.0:$port flask_server:app &> "$city-log.txt" &

echo "Server started and is listening at port: $port with $num_workers workers for city $city."
echo "Test like: python flask_client.py 1236"

write_format="json"
echo "Starting client with 'cd client && bash start_client.sh $city $port $num_workers $write_format'"
