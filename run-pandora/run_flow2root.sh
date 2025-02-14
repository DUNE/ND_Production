#!/usr/bin/env bash

# Example run environment setup
#export ARCUBE_RUNTIME=SHIFTER
#export ARCUBE_CONTAINER=fermilab/fnal-wn-sl7:latest
#export ARCUBE_DIR=$(realpath "$PWD"/..)
#export ARCUBE_IN_NAME=Tutorial.flow
#export ARCUBE_OUT_NAME=Tutorial.flow2root
#export ARCUBE_INDEX=0

export ARCUBE_DIR=${ARCUBE_DIR:-$(realpath "$PWD"/..)}
export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-fermilab/fnal-wn-sl7:latest}

# Container
source $ARCUBE_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ARCUBE_DIR/run-pandora/setup_pandora.sh

# Set other environment variables: globalIdx, ARCUBE_OUTDIR_BASE, tmpOutDir, outDir, outName, subDir
source $ARCUBE_DIR/util/init.inc.sh

# Input HDF5 file
inName=${ARCUBE_IN_NAME}.${globalIdx}
inFile=${ARCUBE_OUTDIR_BASE}/run-ndlar-flow/${ARCUBE_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5

# Is this data or MC?
isData=1
[ "${ARCUBE_PANDORA_INPUT_FORMAT}" ==  "SPMC" ] && isData=0

# Convert input HDF5 file to ROOT
source $ARCUBE_PANDORA_INSTALL/pandora.venv/bin/activate
run python3 $ARCUBE_PANDORA_INSTALL/LArRecoND/ndlarflow/h5_to_root_ndlarflow.py $inFile $isData $tmpOutDir
deactivate

# Move ROOT file from tmpOutDir to output directory
rootOutDir=$outDir/FLOW/$subDir
mkdir -p "${rootOutDir}"
rootFile=${rootOutDir}/${outName}.FLOW.hdf5_hits.root
tmpRootFile=${tmpOutDir}/${inName}.FLOW.hdf5_hits.root
mv "${tmpRootFile}" "${rootFile}"
