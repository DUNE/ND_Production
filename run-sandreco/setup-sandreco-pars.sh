#!/bin/sh

# physics parameters
export MIN_EN_DEPOSIT_TRK="0.04"
export MIN_EN_DEPOSIT_GRAIN="1.0"
export MIN_EN_DEPOSIT_ECAL="1.0"
export B_FIELD_MAGNITUDE="0.6"

# decide which smearing you want, gauss, gluckstern or both
export APPLY_GAUSS_SMEARING=1
export APPLY_GLUCK_SMEARING=1




# ****************************
# DEFAULT CONFIGURATION

export APPLY_GAUSS_SMEARING="${APPLY_GAUSS_SMEARING:-"0"}"
export APPLY_GLUCK_SMEARING="${APPLY_GLUCK_SMEARING:-"0"}"
# Gauss smearing
if [ "$APPLY_GAUSS_SMEARING" = "1" ]; then
    export ENERGY_RESOLUTION="${ENERGY_RESOLUTION:-"0.057"}"      # energy resolution for gauss smearing
    export MOMENTUM_RESOLUTION="${MOMENTUM_RESOLUTION:-"0.05"}"   # momentum resolution for gauss smearing
    export POS_RESOLUTION="${POS_RESOLUTION:-"200e-3"}"           # position resolution for gauss smearing
fi          

# Gluckstern smearing
if [ "$APPLY_GLUCK_SMEARING" = "1" ]; then
    export POS_RES_TRANSVERSE_GLUCKSTERN="${POS_RES_TRANSVERSE_GLUCKSTERN:-"200e-3"}"   # transverse position resolution
    export POS_RES_LONGITUDINAL_GLUCKSTERN="${POS_RES_LONGITUDINAL_GLUCKSTERN:-"2"}"    # longitudinal position resolution
    export HIT_ENERGY_THRESHOLD="${HIT_ENERGY_THRESHOLD:-"250e-6"}"                     # hit energy threshold 
fi  