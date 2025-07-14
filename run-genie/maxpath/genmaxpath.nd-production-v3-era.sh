#!/usr/bin/env bash

# run me from run-edep-sim

export ND_PRODUCTION_CONTAINER=mjkramer/sim2x2:genie_edep.3_04_00.20230912
tune=AR23_20i_00_000

./GENIE_max_path_length_gen.sh /dvs_ro/cfs/cdirs/dune/users/abooth/gdml/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.1.0.gdml $tune
./GENIE_max_path_length_gen.sh /dvs_ro/cfs/cdirs/dune/users/abooth/gdml/anti_fiducial_nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.1.0.gdml $tune
topvol=volArgonCubeDetector75
./GENIE_max_path_length_gen.sh /dvs_ro/cfs/cdirs/dune/users/abooth/gdml/nd_hall_with_lar_tms_sand_TDR_Production_geometry_v_1.1.0.gdml $tune $topvol
