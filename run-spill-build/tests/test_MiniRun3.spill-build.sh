#!/usr/bin/env bash

export ND_PRODUCTION_RUNTIME='SHIFTER'
export ND_PRODUCTION_CONTAINER='mjkramer/sim2x2:genie_edep.LFG_testing.20230228.v2'
export ND_PRODUCTION_NU_NAME='test_MiniRun3.nu.hadd'
export ND_PRODUCTION_NU_POT='1E16'
export ND_PRODUCTION_ROCK_NAME='test_MiniRun3.rock.hadd'
export ND_PRODUCTION_ROCK_POT='1E16'
export ND_PRODUCTION_OUT_NAME='test_MiniRun3.spill'
export ND_PRODUCTION_INDEX='0'

./run_spill_build.sh
