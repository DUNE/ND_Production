#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source load_mlreco.inc.sh

inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/${ND_PRODUCTION_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5

mkdir -p $tmpOutDir/$subDir
outFile=$tmpOutDir/$subDir/$outName.LARCV.root
rm -f "$outFile"

config=$ND_PRODUCTION_FLOW2SUPERA_CONFIG
run install/flow2supera/bin/run_flow2supera.py -o "$outFile" -c "$config" "$inFile"

mkdir -p "$outDir/LARCV/$subDir"
mv "${outFile}" "${outDir}/LARCV/$subDir"
