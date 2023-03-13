### Build the docker image

Under the project folder of mm, run this command

```
docker build -f docker/Dockerfile . -t mm-xiucheng
```

### Open bash in the docker image

```
docker run -it -p 1236:1236 -v ${PWD}/entrance/:/mnt/entrance -v ${PWD}/trips/:/mnt/trips mm-xiucheng
```
