#!/usr/bin/env bash

# The setup scripts can return nonzero
set +o errexit

# Assumes ND_PRODUCTION_RUNTIME, ND_PRODUCTION_CONTAINER & ND_PRODUCTION_DIR
# have already been set

# Only export onwards if the vars are filled. Exporting OMP_NUM_THREADS as 1
# helps with memory consumption in flow2root.
[ -n "$ND_PRODUCTION_OMP_NUM_THREADS" ] && export OMP_NUM_THREADS=$ND_PRODUCTION_OMP_NUM_THREADS

# Pandora install directory
export ND_PRODUCTION_PANDORA_BASEDIR=${ND_PRODUCTION_DIR}/run-pandora
export ND_PRODUCTION_PANDORA_INSTALL=${ND_PRODUCTION_PANDORA_BASEDIR}/install

# Set the LArRecoND version, which will also set the other required Pandora packages
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_VERSION=v01-06-00

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

# Set LArRecoND input data format: SP (SpacePoint data) or SPMC (SpacePoint MC).
# Running with cheated or partially cheated workflows requires the SPMC format for the MC truth info
export ND_PRODUCTION_PANDORA_INPUT_FORMAT=SPMC

# Set LArRecoND Pandora workflow settings xml files for the reconstruction & outerface (track/shower PID).
# Default setting is for 3D slicing & neutrino reco with rock muon tagging without cheating, with the CRRemHitsSliceNu reco option
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML_NAME=${ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML_NAME:-PandoraSettings_LArRecoND_ThreeD_RockMuTagging.xml}
# For ND-LAr MC, recommended is cheated slicing with rock muon tagging & 3D neutrino reco (until the DL-trained slicing becomes available)
#export ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML_NAME=${ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML_NAME:-PandoraSettings_LArRecoND_ThreeD_CheatedSlicing_RockMuTagging.xml}
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML=$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/settings/${ND_PRODUCTION_PANDORA_LAR_RECO_ND_XML_NAME}

# Pandora Outerface
export ND_PRODUCTION_PANDORA_OUTERFACE_XML=$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/settings/PandoraSettings_Outerface_Voxelize.xml

# Set LArRecoND run option: CRRemHitsSliceNu (recommended), AllHitsSliceNu, AllHitsSliceCR, Full, AllHitsCR, AllHitsNu, CRRemHitsSliceCR
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_RUN_OPTION=CRRemHitsSliceNu

# Set LArRecoND view option: both (recommended), 3d, lartpc
export ND_PRODUCTION_PANDORA_LAR_RECO_ND_VIEW_OPTION=both

set -o errexit
