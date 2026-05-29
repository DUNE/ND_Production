#!/usr/bin/env bash

# assume Shifter if ND_PRODUCTION_RUNTIME is unset
export ND_PRODUCTION_RUNTIME=${ND_PRODUCTION_RUNTIME:-SHIFTER}

export ND_PRODUCTION_CONTAINER=$ND_PRODUCTION_CONTAINER_HADD

source ../util/reload_in_container.inc.sh

rm -f getGhepPOT.exe


g++ -o getGhepPOT.exe getGhepPOT.C `root-config --cflags --glibs`

exit
