#!/usr/bin/env bash

# Examples of generating metadata for reflows

# 2x2 v11:

base_2x2=/global/cfs/cdirs/dune/www/data/2x2/reflows/v11
filelist_2x2=/pscratch/sd/d/dunepro/mkramer/install/Reflow_2x2_v11/inputs.2x2.everything.json

python DumpAllMetadata.py --stage flow --release v1.5.0 --dir $base_2x2/flow --filelist $filelist_2x2 --config proto_nd --replace --parallel 10

python DumpAllMetadata.py --stage pandora --release v01-02-02 --dir $base_2x2/pandora --filelist $filelist_2x2 --config proto_nd --replace --parallel 10


# FSD v5:

base_fsd=/global/cfs/cdirs/dune/www/data/FSD/reflows/v5
filelist_fsd=/pscratch/sd/d/dunepro/mkramer/install/Reflow_FSD_v5/inputs.fsd.everything.json

python DumpAllMetadata.py --stage flow --release v1.5.1p1 --dir $base_fsd/flow --filelist $filelist_fsd --config fsd --replace --parallel 10
