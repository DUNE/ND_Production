#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

source load_mlreco.inc.sh

outFile=${tmpOutDir}/${outName}.MLRECO_ANA.hdf5
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-mlreco/${ND_PRODUCTION_IN_NAME}/MLRECO_INF/${subDir}/${inName}.MLRECO_INF.hdf5
config=ana_240403.cfg

tmpDir=$(mktemp -d)
mkdir "${tmpDir}/log_trash"

sed "s!%TMPDIR%!${tmpDir}!g" "configs/${config}" > "${tmpDir}/${config}"

run python3 install/lartpc_mlreco3d/analysis/run.py \
    "${tmpDir}/${config}" \
    --data_keys "$inFile" \
    --outfile "$outFile"

anaOutDir=${outDir}/MLRECO_ANA/${subDir}
mkdir -p "$anaOutDir"
mv "$outFile" "$anaOutDir"

rm -rf "$tmpDir"
