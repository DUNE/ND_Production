#!/usr/bin/env bash

# The setup scripts can return nonzero
set +o errexit

# Assumes ND_PRODUCTION_RUNTIME, ND_PRODUCTION_CONTAINER & ND_PRODUCTION_DIR
# have already been set

# Core software packages
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup cmake v3_22_2
setup gcc v9_3_0
setup eigen v3_3_5
# Sets ROOT version consistent with edepsim production version
setup edepsim v3_2_0c -q e20:prof

# Only export onwards if the vars are filled. Exporting OMP_NUM_THREADS as 1
# helps with memory consumption in flow2root.
[ -n "$ND_PRODUCTION_OMP_NUM_THREADS" ] && export OMP_NUM_THREADS=$ND_PRODUCTION_OMP_NUM_THREADS

# Pandora install directory
export ND_PRODUCTION_PANDORA_BASEDIR=${ND_PRODUCTION_DIR}/run-pandora
export ND_PRODUCTION_PANDORA_INSTALL=${ND_PRODUCTION_PANDORA_BASEDIR}/install

# Pandora package versions
export ND_PRODUCTION_PANDORA_PFA_VERSION=v04-19-02
export ND_PRODUCTION_PANDORA_SDK_VERSION=v04-01-00
export ND_PRODUCTION_PANDORA_MONITORING_VERSION=v04-00-03
export ND_PRODUCTION_PANDORA_LAR_CONTENT_VERSION=v04_19_02
export ND_PRODUCTION_PANDORA_LAR_MLDATA_VERSION=v04-19-03
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_VERSION=v01-04-01

# Relative path used by Pandora packages
export MY_TEST_AREA=${ND_PRODUCTION_PANDORA_INSTALL}

# Set FW_SEARCH_PATH for Pandora xml run files & machine learning data etc
export FW_SEARCH_PATH=${MY_TEST_AREA}/LArRecoND/settings
export FW_SEARCH_PATH=${MY_TEST_AREA}/LArMachineLearningData:${FW_SEARCH_PATH}

# Geometry GDML file
GDMLName='Merged2x2MINERvA_v4_withRock'
if [ -n "$ND_PRODUCTION_GEOM" ]; then
  # If ND_PRODUCTION_GEOM is specified at yaml level, follow the convention of other
  # production steps (no ND_PRODUCTION_DIR at the start).
  export ND_PRODUCTION_GEOM=${ND_PRODUCTION_DIR}/${ND_PRODUCTION_GEOM}
  GDMLName=`basename $ND_PRODUCTION_GEOM .gdml`
else
  export ND_PRODUCTION_GEOM=${ND_PRODUCTION_DIR}/geometry/Merged2x2MINERvA_v4/${GDMLName}.gdml
fi
if [ -n "$ND_PRODUCTION_PANDORA_GEOM" ]; then
  # If ND_PRODUCTION_PANDORA_GEOM is specified at yaml level, follow the ND_PRODUCTION_GEOM
  # convention. 
  export ND_PRODUCTION_PANDORA_GEOM=${ND_PRODUCTION_PANDORA_INSTALL}/${ND_PRODUCTION_PANDORA_GEOM}
else
  export ND_PRODUCTION_PANDORA_GEOM=${ND_PRODUCTION_PANDORA_INSTALL}/LArRecoND/${GDMLName}.root
fi

# Set LArRecoND input data format: SP (SpacePoint data) or SPMC (SpacePoint MC)
export ND_PRODUCTION_PANDORA_INPUT_FORMAT=SPMC

# Set LArRecoND Pandora workflow settings xml files for the reconstruction & outerface (track/shower PID).
# ND-LAr cheated workflows require the SPMC format since they need the MC truth info
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML=$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/settings/PandoraSettings_LArRecoND_ThreeD_PartialCheated.xml
# Nominal 3D reco settings without cheating (for 2x2)
#export ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML=$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/settings/PandoraSettings_LArRecoND_ThreeD.xml
# Pandora Outerface
export ND_PRODUCTION_PANDORA_OUTERFACE_XML=$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/settings/PandoraSettings_Outerface_Voxelize.xml

# Set LArRecoND run option: AllHitsSliceNu (recommended), AllHitsSliceCR, Full, AllHitsCR, AllHitsNu, CRRemHitsSliceCR, CRRemHitsSliceNu
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_RUN_OPTION=AllHitsSliceNu

# Set LArRecoND view option: both (recommended), 3d, lartpc
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_VIEW_OPTION=both

set -o errexit
