# Using the data transfer nodes.

There are four nodes provided by NERSC (`dtn0{1..4}.nersc.gov`) for the purpose of data transfer. The script `transfer_to_fnal.py` uses `gfal-*` tools to move files from NERSC disk to Fermilab disk via `xrootd` protocol.

To run the script you will need a valid x509 certificate. I usually generate this on the DUNE GPVMs and copy it across to `/tmp` on the data transfer nodes. For example on the DUNE GPVMs for my username and uids:

```
setup_fnal_security
scp /tmp/x509up_u50363 abooth@dtn01.nersc.gov:/tmp/x509up_u99810
```

You'll also need to set up a python virtual environment to use the `gfal-*` tools. On the data transfer nodes this can be done as follows:

```
module load python
conda create -n gfal
source activate gfal
conda install -c conda-forge gfal2-util
```

An example of how to use the `transfer_to_fnal.py` script is as follows:

```
transfer_to_fnal.py --ignore-jsons --destination-base root://fndca1.fnal.gov:1094//pnfs/fnal.gov/usr/dune/persistent/users/abooth/Production/MiniProdN1p1-v1r1 --source-base /global/cfs/cdirs/dune/users/abooth/MiniProdN1p1-v1r1/run-convert2h5/output/MiniProdN1p1_NDLAr_1E19_RHC.convert2h5/EDEPSIM_H5/ --maintain-structure-below /global/cfs/cdirs/dune/users/abooth/MiniProdN1p1-v1r1
```

If in-place metadata `jsons` have been made for the files you want to transfer and you want to transfer those too, exclude the `--ignore-jsons` argument.

