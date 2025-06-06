#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh

if [ -f ./corsikaConverter.exe ]; then
    rm corsikaConverter.exe
fi

pushd corsika_converter
make
chmod +x corsikaConverter
mv corsikaConverter ../corsikaConverter.exe
popd
