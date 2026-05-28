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

# Set other environment variables: globalIdx, ND_PRODUCTION_OUTDIR_BASE, subDir, tmpOutDir, outDir
source $ND_PRODUCTION_DIR/util/init.inc.sh

# Input HDF5-to-ROOT file
inName=${ND_PRODUCTION_IN_NAME}.${globalIdx}
inFile=${ND_PRODUCTION_OUTDIR_BASE}/run-pandora/${ND_PRODUCTION_IN_NAME}/FLOW/${subDir}/${inName}.FLOW.hdf5_hits.root

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

# Move LArRecoND output files to output dir
tmpMCHierOut=${tmpRunDir}/MCHierarchy.root
tmpEvtHierOut=${tmpRunDir}/EventHierarchy.root

anaOutDir=${outDir}/LAR_RECO_ND/${subDir}
anaOutFile=${anaOutDir}/${outName}.LAR_RECO_ND.root
mcHierOutDir=${outDir}/MC_HIER/${subDir}
mcHierOutFile=${mcHierOutDir}/${outName}.MC_HIER.root
evtHierOutDir=${outDir}/EVT_HIER/${subDir}
evtHierOutFile=${evtHierOutDir}/${outName}.EVT_HIER.root

mkdir -p ${anaOutDir}
mv "${tmpOuterfaceOut}" "${anaOutFile}"
mkdir -p ${mcHierOutDir}
mv "${tmpMCHierOut}" "${mcHierOutFile}"
mkdir -p ${evtHierOutDir}
mv "${tmpEvtHierOut}" "${evtHierOutFile}"
