# Using the data transfer nodes.

There are four nodes provided by NERSC (`dtn0{1..4}.nersc.gov`) for the purpose of data transfer. The script `transfer_to_fnal.py` uses `gfal-*` tools to move files from NERSC disk to Fermilab disk via `xrootd` protocol.

To run the script you will need a valid x509 certificate. I usually generate this on the DUNE GPVMs and copy it across to `/tmp` on the data transfer nodes. For example on the DUNE GPVMs for my username and uids:

`setup_fnal_security` is a NOvA script!!! run `voms-proxy-init -rfc -noregen -voms dune:/dune/Role=Analysis` instead on the gpvm's

```
setup_fnal_security 
scp /tmp/x509up_u50363 abooth@dtn01.nersc.gov:/tmp/x509up_u99810
```

The transfer script uses `gfal-*` tools, they are available as standard on the data transfer nodes. `python` however is not available in the usual way. The NERSC service desk advised that it can be access via global common:

```
/global/common/software/nersc/pe/conda-envs/24.1.0/python-3.11/nersc-python/bin/python
```

An example of how to use the `transfer_to_fnal.py` script is as follows:

```
/global/common/software/nersc/pe/conda-envs/24.1.0/python-3.11/nersc-python/bin/python transfer_to_fnal.py --ignore-jsons --destination-base root://fndca1.fnal.gov:1094//pnfs/fnal.gov/usr/dune/persistent/users/abooth/Production/MiniProdN1p1-v1r1 --source-base /global/cfs/cdirs/dune/users/abooth/MiniProdN1p1-v1r1/run-convert2h5/output/MiniProdN1p1_NDLAr_1E19_RHC.convert2h5/EDEPSIM_H5/ --maintain-structure-below /global/cfs/cdirs/dune/users/abooth/MiniProdN1p1-v1r1
```

If in-place metadata `jsons` have been made for the files you want to transfer and you want to transfer those too, exclude the `--ignore-jsons` argument. There are also useful arguments for either including or excluding files with certain extensions from the transfer.

