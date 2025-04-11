#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME='SHIFTER'
export ND_PRODUCTION_CONTAINER='mjkramer/sim2x2:genie_edep.LFG_testing.20230228.v2'
export ND_PRODUCTION_SPILL_NAME='test_MiniRun3.spill'
export ND_PRODUCTION_OUT_NAME='test_MiniRun3.convert2h5'
export ND_PRODUCTION_INDEX='0'

./run_convert2h5.sh
