#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

spillName=$ND_PRODUCTION_SPILL_NAME.$globalIdx
echo "outName is $outName"

inBaseDir=$ND_PRODUCTION_OUTDIR_BASE/run-spill-build
spillDir=$inBaseDir/$ND_PRODUCTION_SPILL_NAME

spillFile=$spillDir/EDEPSIM_SPILLS/$subDir/${spillName}.EDEPSIM_SPILLS.root

overlayFile=$tmpOutDir/${outName}.OVERLAY.root
rm -f "$overlayFile"

LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}

run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "convert4sandreco.cpp(\"$spillFile\", \"$overlayFile\", $ND_PRODUCTION_RUN_OFFSET)"

mkdir -p "$outDir/OVERLAY/$subDir"
mv "$overlayFile" "$outDir/OVERLAY/$subDir"