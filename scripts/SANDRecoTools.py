# Script to setup SAND detsim and reco

def get_sand_reco_install_commands_string() -> str:
  cmds = "git clone https://baltig.infn.it/dune/sand-reco.git\n"
  cmds += "cd sand-reco\n"
  cmds += "mkdir build\n"
  cmds += "cd build\n"
  cmds += "cmake -DCMAKE_INSTALL_PREFIX=./.. ./..\n"
  cmds += "make\n"
  cmds += "make install\n"
  return cmds

def get_dune_env_setup_string() -> str:
  return "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh\n"

def get_cmake_setup_string() -> str:
  return "setup cmake v3_24_0\n"

def get_root_setup_string() -> str:
  return "setup root v6_22_08d -q e20:p392:prof\n"

def get_edepsim_setup_string() -> str:
  return "setup edepsim v3_2_0 -q e20:prof\n"

if __name__ == "__main__":
  outfile = open("test.sh", 'w', encoding = 'utf-8')
  cmds = ""
  cmds += get_dune_env_setup_string() 
  cmds += get_cmake_setup_string()
  #cmds += get_root_setup_string()
  cmds += get_edepsim_setup_string()
  cmds += get_sand_reco_install_commands_string()
  outfile.write(cmds)

