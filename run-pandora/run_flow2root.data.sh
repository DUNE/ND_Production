#!/usr/bin/env bash

export ND_PRODUCTION_DIR=${ND_PRODUCTION_DIR:-$(realpath "$PWD"/..)}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

# Container
source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ND_PRODUCTION_DIR/run-pandora/setup_pandora.sh

# Set other environment variables: globalIdx, ND_PRODUCTION_OUTDIR_BASE, tmpOutDir, outDir, outName, subDir
source $ND_PRODUCTION_DIR/util/init.data.inc.sh

# Prevent excessive memory use
export OMP_NUM_THREADS=1

outName=$(basename "$ND_PRODUCTION_CHARGE_FILE" .h5).FLOW.hdf5_hits.root
outFile=${tmpOutDir}/${outName}

inName=$(basename "$ND_PRODUCTION_CHARGE_FILE" .h5).FLOW.hdf5
inFile=${ND_PRODUCTION_FLOW_DIR_BASE}/${relDir}/${inName}

rm -f "$outFile"

isData=1
isFinal=${ND_PRODUCTION_USE_FINAL_HITS:-1}

source $ND_PRODUCTION_PANDORA_INSTALL/pandora.venv/bin/activate
run python3 $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/h5_to_root_ndlarflow.py $inFile $isData $isFinal ${outFile}.firstStep.root
run root -l -q $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/rootToRootConversion.C+\(true,\"${outFile}.firstStep.root\",\"${outFile}\"\)
rm ${outFile}.firstStep.root
deactivate

mv "${outFile}" "${outDir}"

echo "Written to $(realpath "${outDir}/$(basename "$outFile")")"
