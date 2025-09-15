#!/usr/bin/env bash

# Example run environment setup
#export ND_PRODUCTION_RUNTIME=SHIFTER
#export ND_PRODUCTION_CONTAINER=fermilab/fnal-wn-sl7:latest
#export ND_PRODUCTION_DIR=$(realpath "$PWD"/..)
#export ND_PRODUCTION_IN_NAME=Tutorial.flow
#export ND_PRODUCTION_OUT_NAME=Tutorial.flow2root
#export ND_PRODUCTION_INDEX=0

export ND_PRODUCTION_DIR=${ND_PRODUCTION_DIR:-$(realpath "$PWD"/..)}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

# Container
source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ND_PRODUCTION_DIR/run-pandora/setup_pandora.sh

# Set other environment variables: globalIdx, ND_PRODUCTION_OUTDIR_BASE, tmpOutDir, outDir, outName, subDir
source $ND_PRODUCTION_DIR/util/init.inc.sh

# Input HDF5 file
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/${ND_PRODUCTION_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5

# Is this data or MC?
isData=1
[ "${ND_PRODUCTION_PANDORA_INPUT_FORMAT}" ==  "SPMC" ] && isData=0

# Use *prompt* hits for simulation until truth-matching
# issues can be fully debugged. - Aug 20, 2025
#isFinal=${ND_PRODUCTION_USE_FINAL_HITS:-1}
isFinal=0

# Convert input HDF5 file to ROOT
source $ND_PRODUCTION_PANDORA_INSTALL/pandora.venv/bin/activate
python3 $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/h5_to_root_ndlarflow.py $inFile $isData $isFinal ${tmpOutDir}/${inName}.tmp.root
run root -l -q $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/rootToRootConversion.C+\(true,\"${tmpOutDir}/${inName}.tmp.root\",\"${tmpOutDir}/${inName}.FLOW.hdf5_hits.root\"\)
deactivate

# Move ROOT file from tmpOutDir to output directory
rootOutDir=$outDir/FLOW/$subDir
mkdir -p "${rootOutDir}"
tmpRootFile=${tmpOutDir}/${inName}.FLOW.hdf5_hits.root
rootFile=${rootOutDir}/${outName}.FLOW.hdf5_hits.root
mv "${tmpRootFile}" "${rootFile}"
