#!/usr/bin/env bash

export ND_PRODUCTION_CONTAINER=${ND_PRODUCTION_CONTAINER:-mjkramer/sim2x2:ndlar011}

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# INPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions_abooth/MicroProdN4p1/run-spill-build/MicroProdN4p1_NDComplex_FHC.spill.full/EDEPSIM_SPILLS/0002000/0002400/MicroProdN4p1_NDComplex_FHC.spill.full.0002460.EDEPSIM_SPILLS.root"
# OUTPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions_abooth/MicroProdN4p1/run-spill-build/MicroProdN4p1_NDComplex_FHC.spill.full/EDEPSIM_SPILLS/0002000/0002400/MicroProdN4p1_NDComplex_FHC.spill.full.0002460.OVERLAY.root"

INPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions-SAND_opt3_DRIFT1/run-spill-build/sand-events/EDEPSIM_SPILLS/0000000/sand-events.0000000.EDEPSIM_SPILLS.root"
OUTPUT_FILE="/storage/gpfs_data/neutrino/users/gsantoni/ND_Production/productions-SAND_opt3_DRIFT1/run-spill-build/sand-events/EDEPSIM_SPILLS/0000000/sand-events-new.0000000.OVERLAY.root"

LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}

run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "convert4sandreco.cpp(\"$INPUT_FILE\", \"$OUTPUT_FILE\")"