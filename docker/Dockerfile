FROM ubuntu:20.04
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ARG USER_ID
ARG GROUP_ID
RUN addgroup --gid $GROUP_ID user
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
USER user

FROM julia:1.8
RUN apt-get update && apt-get install -y \
    build-essential software-properties-common\
    libboost-dev libboost-serialization-dev libssl-dev \
    cmake vim\
    wget \
    make libbz2-dev libexpat1-dev swig python3-dev python3-pip
# update system python to python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
RUN ln -s /usr/bin/pip3 /usr/bin/pip

RUN apt-get -y install gdal-bin libgdal-dev libspatialindex-dev
RUN mkdir -p /mm /mnt/entrance /mnt/trips
COPY fmm /mm/fmm
COPY entrance /mm/entrance
WORKDIR /mm/fmm
RUN ln -s /mnt/trips /mm/trips

RUN rm -rf build
RUN mkdir -p build && \
    cd build && \
    cmake .. && \
    make install
RUN pip install flask==2.1.0 
RUN pip install gunicorn==20.0.4
RUN pip install requests==2.25.
RUN pip install pyproj==2.6.1
RUN pip install osmnx==1.0.0
RUN pip install shapely
RUN pip install numpy
RUN pip install toolz

CMD cd /mm/entrance && echo "You can configure the parameters in start.sh and run 'bash start.sh'" && /bin/bash
