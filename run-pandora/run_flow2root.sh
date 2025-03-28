#!/usr/bin/env bash

# Example run environment setup
#export ND_PRODUCTION_RUNTIME=SHIFTER
#export ND_PRODUCTION_CONTAINER=fermilab/fnal-wn-sl7:latest
#export ND_PRODUCTION_DIR=$(realpath "$PWD"/..)
#export ND_PRODUCTION_IN_NAME=Tutorial.flow
#export ND_PRODUCTION_OUT_NAME=Tutorial.flow2root
#export ND_PRODUCTION_INDEX=0

# Container
source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ND_PRODUCTION_DIR/run-pandora/setup_pandora.sh

# Set other environment variables: globalIdx, ND_PRODUCTION_OUTDIR_BASE, tmpOutDir, outDir, outName, subDir
source $ND_PRODUCTION_DIR/util/init.inc.sh

# Input HDF5 file
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/${ND_PRODUCTION_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5

# Convert input HDF5 file to ROOT
source $ND_PRODUCTION_PANDORA_INSTALL/pandora.venv/bin/activate
python3 $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/h5_to_root_ndlarflow.py $inFile 0 $tmpOutDir
deactivate

# Move ROOT file from tmpOutDir to output directory
rootOutDir=$outDir/FLOW/$subDir
mkdir -p "${rootOutDir}"
rootFile=${rootOutDir}/${outName}.FLOW.hdf5_hits.root
tmpRootFile=${tmpOutDir}/${inName}.FLOW.hdf5_hits.root
mv "${tmpRootFile}" "${rootFile}"
