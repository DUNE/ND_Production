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


# Alma9 FNAL container
export ND_PRODUCTION_RUNTIME=SHIFTER
export ND_PRODUCTION_CONTAINER=fermilab/fnal-wn-el9:latest
export ND_PRODUCTION_DIR=$(realpath "$PWD"/..)

source $ND_PRODUCTION_DIR/util/reload_in_container.inc.sh

source setup_pandora.sh

# Create install directory
cd $ND_PRODUCTION_DIR
mkdir -p $ND_PRODUCTION_PANDORA_INSTALL

# First checkout LArRecoND (Pandora ND reco)
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/PandoraPFA/LArRecoND.git
cd LArRecoND
git checkout $ND_PRODUCTION_PANDORA_LAR_RECO_ND_VERSION

# Setup Alma9 environment with required external packages (ROOT, Eigen & PyTorch)
echo "Setting up Alma9 environment"
source $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/scripts/setup/Alma9_FNAL.sh

# Build Pandora packages, including LArRecoND
echo "Building required Pandora packages & LArRecoND"
export PANDORA_PROJECT_DIR=${ND_PRODUCTION_PANDORA_INSTALL}
$ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/scripts/build/build_al9.sh

# Install h5flow for converting HDF5 input files to ROOT for LArRecoND
cd $ND_PRODUCTION_PANDORA_INSTALL
git clone https://github.com/lbl-neutrino/h5flow.git
echo "Setting up pandora.venv for h5flow"
python3 -m venv pandora.venv
source pandora.venv/bin/activate
cd h5flow
pip3 install .
pip3 install uproot
deactivate

# Convert GDML geometry file to ROOT for LArRecoND (using cm length units)
echo "Converting GDML geometry file to ROOT"
root -l -b -q -e "TGeoManager::LockDefaultUnits(kFALSE); TGeoManager::SetDefaultUnits(TGeoManager::kRootUnits); TGeoManager::Import(\"${ND_PRODUCTION_GEOM}\"); gGeoManager->Export(\"${ND_PRODUCTION_PANDORA_GEOM}\");"

# Pre-compile the conversion macro
echo "Pre-compiling flow ROOT conversion macro"
cd $ND_PRODUCTION_PANDORA_BASEDIR
root -l -b -q -e ".L $ND_PRODUCTION_PANDORA_INSTALL/LArRecoND/ndlarflow/rootToRootConversion.C+"
