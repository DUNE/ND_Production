# Script to setup SAND detsim and reco

import os
import stat
import subprocess

def get_copy_folder_function_definition_string():
  cmds =  "function copy_folder() {\n"
  cmds += "  local folder=${1}\n"
  cmds += "  local dest=${2}\n"
  cmds += "  local level=${3}\n"
  cmds += "\n"
  cmds += "  for item in $(ls ${folder})\n"
  cmds += "  do\n"
  cmds += "    local item_path=${folder}/${item}\n"
  cmds += "    local dest_item_path=${dest}/${item}\n"
  cmds += "    if [[ -d ${item_path} ]]\n"
  cmds += "    then\n"
  cmds += "      copy_folder ${item_path} ${dest_item_path} $((level+1))\n"
  cmds += "    else\n"
  cmds += "      ifdh cp ${item_path} ${dest_item_path} &> /dev/null\n"
  cmds += "    fi\n"
  cmds += "  done\n"
  cmds += "}\n"
  return cmds

def get_copy_back_string(folder):
  cmds =  "voms-proxy-init -rfc -noregen -voms=dune:/dune/Role=Analysis -valid 120:00\n"
  cmds += "setup ifdhc\n"
  cmds += "copy_folder ${PWD}/{} root://fndca1.fnal.gov:1094/pnfs/fnal.gov/usr/dune/scratch/users/mtenti/output/${JOBSUBJOBID}\n".format(folder)
  return cmds

#def get_sandreco_install_commands_string() -> str: ## not compatible with python2
def get_sandreco_install_commands_string():
  '''
  Provide the bash command to clone sand-reco repository,
  configure the project with cmake, then compile, install and setup
  '''
  cmds = "export CC=$(which gcc)\n"
  cmds += "export CXX=$(which g++)\n"
  cmds += "export LD_LIBRARY_PATH=${CXX/bin\/g++/lib64}:${LD_LIBRARY_PATH}\n"
  cmds += "unset LB_LIBRARY_PATH\n"
  cmds += "unset LIBRARY_PATH\n"
  cmds += "if [ -d sand-reco ]\n"
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
  return cmds

#def get_fastreco_install_commands_string() -> str: ## not compatible with python2
def get_fastreco_install_commands_string():
  '''
  Provide the bash command to clone FastReco repository,
  configure the project with cmake, then compile, install and setup
  '''
  cmds = "export CC=$(which gcc)\n"
  cmds += "export CXX=$(which g++)\n"
  cmds += "export LD_LIBRARY_PATH=${CXX/bin\/g++/lib64}:${LD_LIBRARY_PATH}\n"
  cmds += "unset LB_LIBRARY_PATH\n"
  cmds += "unset LIBRARY_PATH\n"
  cmds += "if [ -d FastReco ]\n"
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
  cmds += "ln -s FastReco/data data\n"
  return cmds

#def get_dune_env_setup_string() -> str: ## not compatible with python2
def get_dune_env_setup_string():
  return "source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh\n"

def get_git_setup_string():
  cmds = "setup git v2_37_3\n"
  cmds += "wget http://ftp.scientificlinux.org/linux/scientific/7.9/x86_64/os/Packages/pcre2-10.23-2.el7.x86_64.rpm\n"
  cmds += "wget http://ftp.scientificlinux.org/linux/scientific/7.9/x86_64/os/Packages/pcre2-devel-10.23-2.el7.x86_64.rpm\n"
  cmds += "rpm2cpio pcre2-10.23-2.el7.x86_64.rpm | cpio -idmv\n"
  cmds += "rpm2cpio pcre2-devel-10.23-2.el7.x86_64.rpm | cpio -idmv\n"
  cmds += "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${PWD}/usr/lib64\n"
  return cmds

#def get_cmake_setup_string() -> str: ## not compatible with python2
def get_cmake_setup_string():
  return "setup cmake v3_24_0\n"

#def get_root_setup_string() -> str: ## not compatible with python2
def get_root_setup_string():
  return "setup root v6_22_08d -q e20:p392:prof\n"

#def get_edepsim_setup_string() -> str: ## not compatible with python2
def get_edepsim_setup_string():
  return "setup edepsim v3_2_0 -q e20:prof\n"

#def get_env_setup_string() -> str: ## not compatible with python2
def get_env_setup_string():
  cmds = get_dune_env_setup_string()
  cmds += get_git_setup_string()
  cmds += get_cmake_setup_string()
  cmds += get_root_setup_string()
  cmds += get_edepsim_setup_string()
  return cmds

def compile_sandreco():
  '''
  Compile sand-reco
  '''
  script_name = "compile_sandreco.sh"
  cmds = get_env_setup_string()
  cmds += get_sandreco_install_commands_string()
  outfile = open(script_name, 'w')
  outfile.write(cmds)
  outfile.close()
  st = os.stat(script_name)
  os.chmod(script_name, st.st_mode | stat.S_IEXEC)
  subprocess.call("./{}".format(script_name), shell=True)

def compile_fastreco():
  '''
  Compile FastReco
  '''
  script_name = "compile_fastreco.sh"
  cmds = get_env_setup_string()
  cmds += get_sandreco_install_commands_string()
  cmds += get_fastreco_install_commands_string()
  outfile = open(script_name, 'w')
  outfile.write(cmds)
  outfile.close()
  st = os.stat(script_name)
  os.chmod(script_name, st.st_mode | stat.S_IEXEC)
  subprocess.call("./{}".format(script_name), shell=True)

if __name__ == "__main__":
  compile_sandreco()
  compile_fastreco()
