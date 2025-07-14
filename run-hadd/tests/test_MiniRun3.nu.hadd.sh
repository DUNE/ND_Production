#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME='SHIFTER'
export ND_PRODUCTION_CONTAINER='mjkramer/sim2x2:genie_edep.LFG_testing.20230228.v2'
export ND_PRODUCTION_HADD_FACTOR='10'
export ND_PRODUCTION_IN_NAME='test_MiniRun3.nu'
export ND_PRODUCTION_OUT_NAME='test_MiniRun3.nu.hadd'
export ND_PRODUCTION_INDEX='0'

./run_hadd.sh
