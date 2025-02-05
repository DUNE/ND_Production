#!/usr/bin/env bash

# Helpful if working with ndlar
#export ND_PRODUCTION_GEOM=geometry/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.gdml
#export ND_PRODUCTION_PANDORA_GEOM=LArRecoND/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.0.3.root


if [ -z "$1" ]; then
  echo "Install of Pandora is detector specific, you must pass either '2x2' or 'ndlar' as"
  echo "the first positional argument of this script."
  exit 1
fi

if { [ -z "$ND_PRODUCTION_GEOM" ] || [ -z "$ND_PRODUCTION_PANDORA_GEOM" ]; } && [ "$1" == "ndlar" ]; then
  echo "If installing ndlar, you must also export"
  echo "ND_PRODUCTION_GEOM and ND_PRODUCTION_PANDORA_GEOM. There"
  echo "are some handy commented lines at the top"
  echo "of this script to help with that."
  exit 2
fi


export ND_PRODUCTION_RUNTIME=SHIFTER
export ND_PRODUCTION_CONTAINER=fermilab/fnal-wn-sl7:latest
export ND_PRODUCTION_DIR=$(realpath "$PWD"/..)

source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

source setup_pandora.sh

# Create install directory
cd $ND_PRODUCTION_DIR
mkdir -p $ND_PRODUCTION_PANDORA_INSTALL

# PandoraPFA (cmake files)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/PandoraPFA.git
cd PandoraPFA
git checkout $ND_PRODUCTION_PANDORA_PFA_VERSION

# PandoraSDK (Abstract interface and software development kit)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/PandoraSDK.git
cd PandoraSDK
git checkout $ND_PRODUCTION_PANDORA_SDK_VERSION
mkdir build
cd build
cmake -DCMAKE_MODULE_PATH=$ND_PRODUCTION_PANDORA_INSTALL/PandoraPFA/cmakemodules ..
make -j4 install

# PandoraMonitoring (ROOT event displays and output)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/PandoraMonitoring.git
cd PandoraMonitoring
git checkout $ND_PRODUCTION_PANDORA_MONITORING_VERSION
mkdir build
cd build
cmake -DCMAKE_MODULE_PATH="$ND_PRODUCTION_PANDORA_INSTALL/PandoraPFA/cmakemodules;$ROOTSYS/etc/cmake" \
-DPandoraSDK_DIR=$ND_PRODUCTION_PANDORA_INSTALL/PandoraSDK ..
make -j4 install

# LArContent (algorithms) without LibTorch (no Deep Learning Vertexing)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/LArContent.git
cd LArContent
git checkout $ND_PRODUCTION_PANDORA_LAR_CONTENT_VERSION
mkdir build
cd build
cmake -DCMAKE_MODULE_PATH="$ND_PRODUCTION_PANDORA_INSTALL/PandoraPFA/cmakemodules;$ROOTSYS/etc/cmake" \
-DPANDORA_MONITORING=ON -DPandoraSDK_DIR=$ND_PRODUCTION_PANDORA_INSTALL/PandoraSDK \
-DPandoraMonitoring_DIR=$ND_PRODUCTION_PANDORA_INSTALL/PandoraMonitoring \
-DEigen3_DIR=$EIGEN_DIR/Eigen3/share/eigen3/cmake/ ..
make -j4 install

# LArRecoND (DUNE ND reco)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/LArRecoND.git
cd LArRecoND
git checkout $ND_PRODUCTION_PANDORA_LAR_RECO_ND_VERSION
mkdir build
cd build
cmake -DCMAKE_MODULE_PATH="$ND_PRODUCTION_PANDORA_INSTALL/PandoraPFA/cmakemodules;$ROOTSYS/etc/cmake" \
-DPANDORA_MONITORING=ON -DPandoraSDK_DIR=$ND_PRODUCTION_PANDORA_INSTALL/PandoraSDK/ \
-DPandoraMonitoring_DIR=$ND_PRODUCTION_PANDORA_INSTALL/PandoraMonitoring/ \
-DLArContent_DIR=$ND_PRODUCTION_PANDORA_INSTALL/LArContent ..
make -j4 install

# LArMachineLearningData (BDT, MVA & Deep Learning training files)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/LArMachineLearningData.git
cd LArMachineLearningData
git checkout $ND_PRODUCTION_PANDORA_LAR_MLDATA_VERSION
# # Download training files: only do this once to avoid google drive's access restrictions (up to 24 hrs wait)
# . download.sh sbnd
# . download.sh dune
# . download.sh dunend
cp -r /global/cfs/cdirs/dune/www/data/pandora/LArMachineLearningData/* .

# Install h5flow for converting HDF5 input files to ROOT for LArRecoND
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/lbl-neutrino/h5flow.git
echo "Setting up pandora.venv for h5flow"
python3 -m venv pandora.venv
source pandora.venv/bin/activate
cd h5flow
pip3 install .
deactivate

# Convert GDML geometry file to ROOT for LArRecoND (using cm length units)
root -l -b -q -e "TGeoManager::LockDefaultUnits(kFALSE); TGeoManager::SetDefaultUnits(TGeoManager::kRootUnits); TGeoManager::Import(\"${ND_PRODUCTION_GEOM}\"); gGeoManager->Export(\"${ND_PRODUCTION_PANDORA_GEOM}\");"
