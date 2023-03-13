#!/bin/bash

docker run -it -p 1236:1236 -v ${PWD}/entrance/:/mnt/entrance -v ${PWD}/trips/:/mnt/trips mm-xiucheng