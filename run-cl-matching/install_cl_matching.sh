#!/usr/bin/env bash
# Install the CLMatching_AlphaRelease repo into this directory.
#
# Usage:
#   ./install_cl_matching.sh              # clones into ./CLMatching_AlphaRelease
#   ./install_cl_matching.sh /some/dir    # clones into /some/dir/CLMatching_AlphaRelease
#
# Notes:
#   * We do NOT build a dedicated venv here. The CL matching code uses the
#     shared NERSC nersc-python (which already includes torch + cuda). The
#     runtime scripts pin the python via the PY env var.
#   * On a fresh clone the 2x2 perceiver / pulse / variance assets ship
#     in-repo. The ND-LAr perceiver and a few pulse/variance files live on
#     GitHub Releases and need to be downloaded; check_install.py reports
#     what's missing and prints the download commands.

source ../util/prelude.inc.sh

installDir=${1:-.}
repoName=CLMatching_AlphaRelease
repoURL=https://github.com/MadivB/CLMatching_AlphaRelease.git
repoBranch=${ND_PRODUCTION_CLMATCH_BRANCH:-main}

if [[ -e "$installDir/$repoName" ]]; then
  echo "$installDir/$repoName already exists; delete it then run me again"
  exit 1
fi

mkdir -p "$installDir"
cd "$installDir"

git clone -b "$repoBranch" "$repoURL" "$repoName"

PY=${PY:-/global/common/software/nersc/pe/conda-envs/26.1.0/python-3.13/nersc-python/bin/python}

cd "$repoName"

echo
echo "--- Validating required assets via scripts/check_install.py ---"
"$PY" scripts/check_install.py || {
    echo
    echo "ERROR: one or more required CL matching assets are missing."
    echo "       Run the download command(s) printed above, then re-run:"
    echo "         $PY scripts/check_install.py"
    echo
    echo "       The 2x2 assets are bundled in-repo (should always resolve)."
    echo "       The ND-LAr perceiver is hosted on GitHub Releases."
    exit 1
}
echo "--- CLMatching install OK ---"
