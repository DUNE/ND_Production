#!/usr/bin/env bash

# Examples of generating metadata for reflows


# 2x2 v11:

base_2x2=/global/cfs/cdirs/dune/www/data/2x2/reflows/v11
filelist_2x2=/pscratch/sd/d/dunepro/mkramer/install/Reflow_2x2_v11/inputs.2x2.everything.json

python DumpAllMetadata.py --stage flow --release v1.5.0 --dir $base_2x2/flow --filelist $filelist_2x2 --config proto_nd --replace --parallel 10

python DumpAllMetadata.py --stage pandora --release v01-02-02 --dir $base_2x2/pandora --filelist $filelist_2x2 --config proto_nd --replace --parallel 10

SPINE_SETTINGS=2x2_full_chain_data_240819.cfg python DumpAllMetadata.py --stage spine --release 6a44ceffe56 --dir $base_2x2/spine --filelist $filelist_2x2 --config proto_nd --replace --parallel 10

python DumpAllMetadata.py --stage caf --release 8ad48f2 --dir $base_2x2/caf --filelist $filelist_2x2 --config proto_nd --replace --parallel 10

python DumpAllMetadata.py --stage caf_flat --release 8ad48f2 --dir $base_2x2/caf.flat --filelist $filelist_2x2 --config proto_nd --replace --parallel 10


# FSD v5:

base_fsd=/global/cfs/cdirs/dune/www/data/FSD/reflows/v5
filelist_fsd=/pscratch/sd/d/dunepro/mkramer/install/Reflow_FSD_v5/inputs.fsd.everything.json

python DumpAllMetadata.py --stage flow --release v1.5.1p1 --dir $base_fsd/flow --filelist $filelist_fsd --config fsd --replace --parallel 10

python DumpAllMetadata.py --stage pandora --release v01-02-02 --dir $base_fsd/pandora --filelist $filelist_fsd --config fsd --replace --parallel 10

SPINE_SETTINGS=ndlar_single_full_chain_data_250629.cfg python DumpAllMetadata.py --stage spine --release 08b2fc3 --dir $base_fsd/spine --filelist $filelist_fsd --config fsd --replace --parallel 10

python DumpAllMetadata.py --stage caf --release e17772a --dir $base_fsd/caf --filelist $filelist_fsd --config fsd --replace --parallel 10

python DumpAllMetadata.py --stage caf_flat --release e17772a --dir $base_fsd/caf.flat --filelist $filelist_fsd --config fsd --replace --parallel 10
