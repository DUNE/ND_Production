#!/bin/bash

# Reload in Shifter if necessary
if [[ "$SHIFTER_IMAGEREQUEST" != "$ND_PRODUCTION_CONTAINER" ]]; then
	shifter --image=$ND_PRODUCTION_CONTAINER --module=none -- "$0" "$@"
	exit
fi

geom=$1; shift
tune=$1; shift
topvol=$1; shift

seed=0
npoints=1000
nrays=1000
# Used for all: 
# *_v2025.08.11.gdml with and without topvol volArgonCubeDetector75 specified.
#npoints=5000
#nrays=5000

args_gmxpl=( \
 	-f "$geom" \
	 -L cm -D g_cm3 \
	 -n "$npoints" \
	 -r "$nrays" \
	 --tune "$tune" \
	 --seed "$seed" \
  )

maxpath=maxpath/$(basename "$geom" .gdml).$tune.maxpath.xml
if [ -n "${topvol}" ]; then
  args_gmxpl+=( -t "$topvol" )
  maxpath=maxpath/$(basename "$geom" .gdml).$topvol.$tune.maxpath.xml
fi
args_gmxpl+=( -o "$maxpath" )
mkdir -p "$(dirname "$maxpath")"

source /environment

gmxpl "${args_gmxpl[@]}"
