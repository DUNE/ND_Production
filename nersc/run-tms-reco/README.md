# Installing TMS Software

[dune-tms](https://github.com/DUNE/dune-tms/tree/main) is the reposititory used for studying the Temporary Muon Spectrometer as a part of the DUNE Near Detector system. To setup and build the code at NERSC, it's necessary to use an SL7 container. Aside from this the steps are essentially the same as is described in the [README](https://github.com/DUNE/dune-tms/blob/main/README.md) for that repository.

Installation and building can be done with a single command.

```
shifter --image=fermilab/fnal-wn-sl7:latest --module=cvmfs /bin/bash -- ${PWD}/install_tms_reco.sh
```

The command must be executed from the same directory as this README (`ND_Production/nersc/run-tms-reco`). It will launch the container and run `install_tms_reco.sh`. This script clones the dune-tms repository, checksout a particular tag of that repository, sets up the necessary environment via cvmfs and calls `make`. It will then exit the container. 

Note that the installation script and job script both assume the following version of `edep-sim`:

```
edepsim v3_2_0 -f Linux64bit+3.10-2.17 -q e20:prof
```


# Running TMS Software
`ND_Production/nersc/run-tms-reco/run_tms_reco.sh` is the grid script for NERSC. It currently assumes a base directory structure consistent with receiving `edep-sim` files made using the `2x2_sim` style workflow. As in that workflow, `run_tms_reco.sh` jobs will be managed using fireworks. Details to come soon.

For ease during productions and consistency with other tiers of output files, the output file name for a particular call of `run_tms_reco.sh` is set using the environment variable `ND_PRODUCTION_TMS_OUTFILE`. 
