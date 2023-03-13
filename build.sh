#!/usr/bin

tmpdir=$HOME/mmtrips
if [ -d $tmpdir ]; then
    echo "Please make sure $tmpdir is empty and move it to other place."
    exit 1
fi

if [ -d "trips" ]; then
    echo "Moving dataset to $tmpdir..."
    mkdir -p $tmpdir
    mv trips $tmpdir
fi
mkdir trips

docker build -f docker/Dockerfile . -t mm-xiucheng \
    --build-arg USER_ID=$(id -u) \
    --build-arg GROUP_ID=$(id -g)

if [ -d "$tmpdir/trips/input" ]; then
    mv $tmpdir/trips/input trips/
else 
    mkdir -p trips/input
fi

if [ -d "$tmpdir/trips/output" ]; then
    msg1="\nThe files in trips/output/ might get overwritten.\n"
    msg2="Move them to other place if you want to keep them."
    echo -e $msg1$msg2
    mv $tmpdir/trips/output trips/
else 
    mkdir -p trips/output
fi

if [ -d "$tmpdir" ]; then
    rm -rf $tmpdir
    echo "Done."
fi