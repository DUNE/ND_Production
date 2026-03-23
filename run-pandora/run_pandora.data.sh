#!/usr/bin/env bash

# Example run environment setup
#export ND_PRODUCTION_RUNTIME=SHIFTER
#export ND_PRODUCTION_CONTAINER=fermilab/fnal-wn-sl7:latest
#export ND_PRODUCTION_DIR=$(realpath "$PWD"/..)
#export ND_PRODUCTION_IN_NAME=Tutorial.flow2root
#export ND_PRODUCTION_OUT_NAME=Tutorial.pandora
#export ND_PRODUCTION_INDEX=0
#export ND_PRODUCTION_GEOM=geometry/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.gdml
#export ND_PRODUCTION_PANDORA_GEOM=LArRecoND/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.root

export ND_PRODUCTION_DIR=${ND_PRODUCTION_DIR:-$(realpath "$PWD"/..)}
export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-fermilab/fnal-wn-sl7:latest}

# Container
source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

# Setup Pandora environment
source $ND_PRODUCTION_DIR/run-pandora/setup_pandora.sh

export ND_PRODUCTION_PANDORA_INPUT_FORMAT=SP

source $ND_PRODUCTION_DIR/util/init.data.inc.sh

# Input HDF5-to-ROOT file
outName=$(basename "$ND_PRODUCTION_CHARGE_FILE" .h5)
inName=$outName.FLOW.hdf5_hits.root
inFile=${ND_PRODUCTION_FLOW2ROOT_DIR_BASE}/${relDir}/${inName}

# Create temporary run directory
tmpRunDir=$(mktemp -d)
cd $tmpRunDir

# Create soft link to input file for hierarchy output (event numbers & trigger times)
ln -sf $inFile LArRecoNDInput.root

# Run LArRecoND Pandora program over all events, which creates the initial LArRecoND.root (hierarchy analysis) output file
run ${ND_PRODUCTION_PANDORA_INSTALL}/LArRecoND/bin/PandoraInterface -i ${ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML} \
    -r ${ND_PRODUCTION_PANDORA_LAR_RECO_ND_RUN_OPTION} -f ${ND_PRODUCTION_PANDORA_INPUT_FORMAT} \
    -g ${ND_PRODUCTION_PANDORA_GEOM} -e $inFile -j ${ND_PRODUCTION_PANDORA_LAR_RECO_ND_VIEW_OPTION} -M -N

# Rename LArRecoND.root to LArRecoNDHierarchy.root for the Pandora outerface input
tmpHierarchyOut=${tmpRunDir}/LArRecoND.root
tmpOuterfaceIn=${tmpRunDir}/LArRecoNDHierarchy.root
mv "${tmpHierarchyOut}" "${tmpOuterfaceIn}"

# Run the Pandora outerface (track/shower & PID reco) to create the final LArRecoND.root file for the CAFs
tmpOuterfaceOut=${tmpRunDir}/LArRecoND.root
run ${ND_PRODUCTION_PANDORA_INSTALL}/LArRecoND/bin/PandoraOuterface -f ${tmpOuterfaceIn} \
    -x ${ND_PRODUCTION_PANDORA_OUTERFACE_XML} -o ${tmpOuterfaceOut} -g ${ND_PRODUCTION_PANDORA_GEOM}

# Move LArRecoND hierarchy analysis ROOT file to output dir
tmpAnaOut=${tmpRunDir}/LArRecoND.root
tmpMCHierOut=${tmpRunDir}/MCHierarchy.root
tmpEvtHierOut=${tmpRunDir}/EventHierarchy.root

anaOutDir=${outDir}/LAR_RECO_ND
anaOutFile=${anaOutDir}/${outName}.LAR_RECO_ND.root

mkdir -p ${anaOutDir}
mv "${tmpAnaOut}" "${anaOutFile}"
