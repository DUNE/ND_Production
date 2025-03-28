#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source load_mlreco.inc.sh

[ -z "$ND_PRODUCTION_FLOW2SUPERA_CONFIG" ] && export ND_PRODUCTION_FLOW2SUPERA_CONFIG="2x2"

outFile=${tmpOutDir}/${outName}.LARCV.root
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/${ND_PRODUCTION_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5
config=$ND_PRODUCTION_FLOW2SUPERA_CONFIG

rm -f "$outFile"

run install/flow2supera/bin/run_flow2supera.py -o "$outFile" -c "$config" "$inFile"

larcvOutDir=$outDir/LARCV/$subDir
mkdir -p "${larcvOutDir}"
mv "${outFile}" "${larcvOutDir}"
