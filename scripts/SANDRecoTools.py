# Script to setup SAND detsim and reco

import os
import stat
import subprocess

def get_sandreco_install_commands_string() -> str:
  cmds = "if [ -d sand-reco ]\n"
  cmds += "then\n"
  cmds += "  rm -fr sand-reco\n"
  cmds += "fi\n"
  cmds += "git clone -b cxx17 https://baltig.infn.it/dune/sand-reco.git\n"
  cmds += "cd sand-reco\n"
  cmds += "if [ -d build ]\n"
  cmds += "then\n"
  cmds += "  rm -fr build\n"
  cmds += "fi\n"
  cmds += "mkdir build\n"
  cmds += "cd build\n"
  cmds += "cmake -DCMAKE_INSTALL_PREFIX=./.. ./..\n"
  cmds += "make\n"
  cmds += "make install\n"
  cmds += "cd ../..\n"
  cmds += "source sand-reco/setup.sh\n"
  cmds += "Digitize -h\n"
  return cmds

def get_fastreco_install_commands_string() -> str:
  cmds = "if [ -d FastReco ]\n"
  cmds += "then\n"
  cmds += "  rm -fr FastReco\n"
  cmds += "fi\n"
  cmds += "git clone https://baltig.infn.it/dune/FastReco.git\n"
  cmds += "cd FastReco\n"
  cmds += "if [ -d build ]\n"
  cmds += "then\n"
  cmds += "  rm -fr build\n"
  cmds += "fi\n"
  cmds += "mkdir build\n"
  cmds += "cd build\n"
  cmds += "export SandReco_DIR=../../sand-reco/lib/cmake/SandReco\n"
  cmds += "cmake -DCMAKE_INSTALL_PREFIX=./.. ./..\n"
  cmds += "make\n"
  cmds += "make install\n"
  cmds += "cd ../..\n"
  cmds += "source sand-reco/setup.sh\n"
  cmds += "export PATH=${PATH}:${PWD}/FastReco/bin\n"
  cmds += "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${PWD}/FastReco/lib\n"
  cmds += "sandSmearGo -h\n"
  return cmds

def get_dune_env_setup_string() -> str:
  return "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh\n"

def get_cmake_setup_string() -> str:
  return "setup cmake v3_24_0\n"

def get_root_setup_string() -> str:
  return "setup root v6_22_08d -q e20:p392:prof\n"

def get_edepsim_setup_string() -> str:
  return "setup edepsim v3_2_0 -q e20:prof\n"

def compile_sandreco():
  script_name = "compile_sandreco.sh"
  cmds = ""
  cmds += get_dune_env_setup_string()
  cmds += get_cmake_setup_string()
  cmds += get_root_setup_string()
  cmds += get_edepsim_setup_string()
  cmds += get_sandreco_install_commands_string()
  outfile = open(script_name, 'w', encoding = 'utf-8')
  outfile.write(cmds)
  outfile.close()
  st = os.stat(script_name)
  os.chmod(script_name, st.st_mode | stat.S_IEXEC)
  subprocess.call(f"./{script_name}", shell=True)

def compile_fastreco():
  script_name = "compile_fastreco.sh"
  cmds = ""
  cmds += get_dune_env_setup_string()
  cmds += get_cmake_setup_string()
  cmds += get_root_setup_string()
  cmds += get_edepsim_setup_string()
  cmds += get_fastreco_install_commands_string()
  outfile = open(script_name, 'w', encoding = 'utf-8')
  outfile.write(cmds)
  outfile.close()
  st = os.stat(script_name)
  os.chmod(script_name, st.st_mode | stat.S_IEXEC)
  subprocess.call(f"./{script_name}", shell=True)

if __name__ == "__main__":
  compile_sandreco()
  compile_fastreco()
