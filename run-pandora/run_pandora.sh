#!/usr/bin/env bash

# Example run environment setup
#export ARCUBE_RUNTIME=SHIFTER
#export ARCUBE_CONTAINER=fermilab/fnal-wn-sl7:latest
#export ARCUBE_DIR=$(realpath "$PWD"/..)
#export ARCUBE_IN_NAME=Tutorial.flow2root
#export ARCUBE_OUT_NAME=Tutorial.pandora
#export ARCUBE_INDEX=0

export ARCUBE_CONTAINER=${ARCUBE_CONTAINER:-fermilab/fnal-wn-sl7:latest}

# Container
source $ARCUBE_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ARCUBE_DIR/run-pandora/setup_pandora.sh

# Set other environment variables: globalIdx, ARCUBE_OUTDIR_BASE, subDir, tmpOutDir, outDir
source $ARCUBE_DIR/util/init.inc.sh

# Input HDF5-to-ROOT file
inName=${ARCUBE_IN_NAME}.${globalIdx}
inFile=${ARCUBE_OUTDIR_BASE}/run-pandora/${ARCUBE_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5_hits.root

# Create temporary run directory
tmpRunDir=$(mktemp -d)
cd $tmpRunDir

# Create soft link to input file for hierarchy output (event numbers & trigger times)
ln -sf $inFile LArRecoNDInput.root

# Run LArRecoND Pandora program over all events
run ${ARCUBE_PANDORA_INSTALL}/LArRecoND/bin/PandoraInterface -i ${ARCUBE_PANDORA_INSTALL}/LArRecoND/settings/PandoraSettings_LArRecoND_ThreeD.xml \
    -r AllHitsSliceNu -f ${ARCUBE_PANDORA_INPUT_FORMAT} -g ${ARCUBE_PANDORA_GEOM} -e $inFile -j both -M -N

# Move LArRecoND hierarchy analysis ROOT file to output dir
tmpAnaOut=${tmpRunDir}/LArRecoND.root
tmpMCHierOut=${tmpRunDir}/MCHierarchy.root
tmpEvtHierOut=${tmpRunDir}/EventHierarchy.root

anaOutDir=${outDir}/LAR_RECO_ND/${subDir}
anaOutFile=${anaOutDir}/${outName}.LAR_RECO_ND.root
mcHierOutDir=${outDir}/MC_HIER/${subDir}
mcHierOutFile=${mcHierOutDir}/${outName}.MC_HIER.root
evtHierOutDir=${outDir}/EVT_HIER/${subDir}
evtHierOutFile=${evtHierOutDir}/${outName}.EVT_HIER.root

mkdir -p ${anaOutDir}
mv "${tmpAnaOut}" "${anaOutFile}"
mkdir -p ${mcHierOutDir}
mv "${tmpMCHierOut}" "${mcHierOutFile}"
mkdir -p ${evtHierOutDir}
mv "${tmpEvtHierOut}" "${evtHierOutFile}"
