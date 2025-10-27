# ND_Production
This repository contains auxiliary files for ND simulation production. It is meant as a centralized place for collecting input files to be used for official production passes for the ND software group.
Examples: geometry gdml files, flux window definitions, macros

For details of **ND Production samples**, please see the [wiki](https://github.com/DUNE/ND_Production/wiki/Production-Samples).
 
# Organization
The repository is organized with a dedicated area for geometry gdml files, and then a directory corresponding to each production stage: generator, geant4, detsim, reco, analysis. There is also a dedicated area for grid scripts to facilitate version control of these scripts. Many jobs that run multiple stages in a single submission will require input files from several of these areas.

# Geometry
The geometry area of this repository is intended to store gdml files for production. These should be generated from configuration files in the dunendggd repository. It is strongly encouraged to tag the dunendggd repo when a production geometry is created, and reference the tag either in the gdml file name or at least the commit message. Including the geometries in this repository simplifies the production process by providing a centralized repo for all input files required for production.

# Production stages
The generator area contains input files related to the neutrino event generation (GENIE) stage, for example the flux window definition. The geant4 area contains input files for simulating neutrino interaction products in the detector, for example the edep-sim macro file. Files in the generator and geant4 areas will typically be common to all ND productions.

The detsim, reco, and analysis areas contain inputs for simulating the detector response, running reconstruction, and producing analysis ntuples, respectively. These inputs are likely to be specific to a particular subdetector and less likely to be common accross the ND groups. Please use descriptive names when committing files to these areas especially to avoid confusion. For example, if you are committing a configuration file for running ND-LAr track finding, name it NDLAr_trackfinder_v0.cfg rather than giving it a generic name like reco.cfg. In the future we may add further organziation to these directories if they become too messy.

# 2x2_sim
Wrappers for ArgonCube 2x2 simulation designed to be run at NERSC.

Support for other computing clusters/environments using Singularity is now available and is configured by environment variable(s). Certain parts of the simulation chain (e.g. edep-sim) require large input files and need to be downloaded from NERSC or regenerated.

The repository wiki has a variety of useful information related to running and using the 2x2 simulation:

+ A tutorial on how to run the simulation can be found at [Tutorial on running 2x2_sim](https://github.com/DUNE/2x2_sim/wiki/Tutorial-on-running-2x2_sim)
+ Information on the data/variables inside the different output files can be found at [File data definitions](https://github.com/DUNE/2x2_sim/wiki/File-data-definitions)

Additional information may be found on the [ND-Prototype Analysis page(s)](https://wiki.dunescience.org/wiki/ND_Prototype_Analysis) on the DUNE wiki.



## Copyright and Licensing
Copyright © 2023 FERMI NATIONAL ACCELERATOR LABORATORY for the benefit of the DUNE Collaboration.

This repository, and all software contained within, is licensed under
the Apache License, Version 2.0 (the "License"); you may not use this
file except in compliance with the License. You may obtain a copy of
the License at
    http://www.apache.org/licenses/LICENSE-2.0

Copyright is granted to FERMI NATIONAL ACCELERATOR LABORATORY on behalf
of the Deep Underground Neutrino Experiment (DUNE). Unless required by
applicable law or agreed to in writing, software distributed under the
License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for
the specific language governing permissions and limitations under the
License.
