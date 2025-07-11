#!/usr/bin/env bash

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

ghepFile="../productions-SAND_opt3_DRIFT1/run-genie/sand-events/GHEP/0000000/sand-events.0000000.GHEP.root"

LIBTG4EVENT_DIR=${LIBTG4EVENT_DIR:-libTG4Event}
# LD_PRELOAD="/usr/lib64/libxml2.so:/opt/generators/genie/lib/libGFwUtl-3.04.00.so:/opt/generators/root/lib/libHist.so:/opt/generators/root/lib/libPhysics.so" /opt/generators/root/bin/root.exe



run root -l -b -q \
    -e "gSystem->Load(\"$LIBTG4EVENT_DIR/libTG4Event.so\")" \
    "convert2User.cpp(\"$ghepFile\")"

