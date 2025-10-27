#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# INPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions_abooth/MicroProdN4p1/run-spill-build/MicroProdN4p1_NDComplex_FHC.spill.full/EDEPSIM_SPILLS/0002000/0002400/MicroProdN4p1_NDComplex_FHC.spill.full.0002460.EDEPSIM_SPILLS.root"
# OUTPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions_abooth/MicroProdN4p1/run-spill-build/MicroProdN4p1_NDComplex_FHC.spill.full/EDEPSIM_SPILLS/0002000/0002400/MicroProdN4p1_NDComplex_FHC.spill.full.0002460.OVERLAY.root"

nuName=$ND_PRODUCTION_NU_NAME.$globalIdx
# rockName=$ND_PRODUCTION_ROCK_NAME.$globalIdx
echo "outName is $outName"

inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-spill-build
spillDir=$inBaseDir/$ND_PRODUCTION_NU_NAME
# rockInDir=$inBaseDir/$ND_PRODUCTION_ROCK_NAME

spillFile=$spillDir/EDEPSIM_SPILLS/$subDir/${nuName}.EDEPSIM_SPILLS.root
# rockInFile=$rockInDir/EDEPSIM_SPILLS/$subDir/${rockName}.EDEPSIM_SPILLS.root

overlayFile=$tmpOutDir/${outName}.OVERLAY.root
rm -f "$overlayFile"

LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}

run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "convert4sandreco.cpp(\"$spillFile\", \"$overlayFile\")"

mkdir -p "$outDir/OVERLAY/$subDir"
mv "$overlayFile" "$outDir/OVERLAY/$subDir"