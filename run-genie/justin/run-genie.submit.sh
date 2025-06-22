#!/bin/bash

# justin simple-workflow --monte-carlo 2 ...

justin-test-jobscript --monte-carlo 1 --jobscript run-genie.jobscript \
    --env ND_PRODUCTION_NAME=MR5_justIN_test \
    --env ND_PRODUCTION_OUTDIR_BASE=. \
    --env ND_PRODUCTION_LOGDIR_BASE=. \
    --env ND_PRODUCTION_RUNTIME=NONE \
    --env ND_PRODUCTION_DET_LOCATION=MiniRun5-Nu \
    --env ND_PRODUCTION_EXPOSURE=1E15 \
    --env ND_PRODUCTION_DK2NU_DIR=. \
    --env ND_PRODUCTION_GEOM=geometry/Merged2x2MINERvA_v4/Merged2x2MINERvA_v4_noRock.gdml \
    --env ND_PRODUCTION_TUNE=AR23_20i_00_000 \
    --env ND_PRODUCTION_XSEC_FILE=/cvmfs/larsoft.opensciencegrid.org/products/genie_xsec/v3_04_00/NULL/AR2320i00000-k250-e1000/data/gxspl-NUsmall.xml
