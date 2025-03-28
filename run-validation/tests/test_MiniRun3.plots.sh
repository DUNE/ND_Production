#!/usr/bin/env bash

export ND_PRODUCTION_EDEP_NAME='test_MiniRun3.convert2h5'
export ND_PRODUCTION_LARND_NAME='test_MiniRun3.larnd'
export ND_PRODUCTION_FLOW_NAME='test_MiniRun3.flow'
export ND_PRODUCTION_OUT_NAME='test_MiniRun3.plots'
export ND_PRODUCTION_INDEX='0'

./run_validation.sh
