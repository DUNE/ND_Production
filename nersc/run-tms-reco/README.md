# Installing TMS Software

[dune-tms](https://github.com/DUNE/dune-tms/tree/main) is the reposititory used for studying the Temporary Muon Spectrometer as a part of the DUNE Near Detector system. To setup and build the code at NERSC, it's necessary to use an SL7 container. Aside from this the steps are essentially the same as is described in the [README](https://github.com/DUNE/dune-tms/blob/main/README.md) for that repository.

Installation and building can be done with a single command.

```
shifter --image=fermilab/fnal-wn-sl7:latest --module=cvmfs /bin/bash -- ${PWD}/install_tms_reco.sh
```

The command must be executed from the same directory as this README (`ND_Production/nersc/run-tms-reco`). It will launch the container and run `install_tms_reco.sh`. This script clones the dune-tms repository, sets up the necessary environment via cvmfs and calls `make`. It will then exit the container. 
