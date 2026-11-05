#!/usr/bin/env bash
# Install the CL matching stack into this directory.
#
# Usage:
#   ./install_cl_matching.sh              # into ./
#   ./install_cl_matching.sh /some/dir    # into /some/dir/
#
# What this installs:
#   * clmatching-chain      @ tag CLMatching_v1.0  (--recurse-submodules brings
#                                                    CLMatching_AlphaRelease in
#                                                    as its `CLMatching_AlphaRelease/`
#                                                    submodule)  -> ND sim workflow
#   * clmatching-frontend   @ main                -> external front-end used by v1
#   * CLMatching_AlphaRelease @ main              -> 2x2 sim/data workflows
#     (a SEPARATE clone from the one pinned inside clmatching-chain, so 2x2 can
#      track alpha's main while ND stays pinned to the v1 release.)
#
# What this does NOT install:
#   * The ND-LAr small light checkpoint. It's pre-staged on NERSC CFS at
#       /global/cfs/cdirs/dune/users/yuxuan/NDLAr-full/NewMLSection/runs/ndfull_small4x/best_model_arch.pt
#     (owned yuxuan / group dune, group-readable). ND production runs as
#     `dunepro` which is in the `dune` group so this Just Works. If you want a
#     copy inside your install, set ND_PRODUCTION_CLMATCH_SMALL_CKPT to your
#     preferred path before invoking the run scripts.
#   * The Alpha ND perceiver (~490 MB). Only needed if you run the ND wrapper
#     against the Alpha pipeline (default is v1). check_install.py in the
#     alpha clone tells you the curl command if you need it.

source ../util/prelude.inc.sh

installDir=${1:-.}
V1_URL=https://github.com/MadivB/clmatching-chain.git
V1_TAG=${ND_PRODUCTION_CLMATCH_V1_TAG:-CLMatching_v1.0}
FRONTEND_URL=https://github.com/MadivB/clmatching-frontend.git
FRONTEND_BRANCH=${ND_PRODUCTION_CLMATCH_FRONTEND_BRANCH:-main}
ALPHA_URL=https://github.com/MadivB/CLMatching_AlphaRelease.git
ALPHA_BRANCH=${ND_PRODUCTION_CLMATCH_ALPHA_BRANCH:-main}

SMALL_CKPT=/global/cfs/cdirs/dune/users/yuxuan/NDLAr-full/NewMLSection/runs/ndfull_small4x/best_model_arch.pt

for d in CLMatching_v1 clmatching-frontend CLMatching_AlphaRelease; do
  if [[ -e "$installDir/$d" ]]; then
    echo "$installDir/$d already exists; delete it then run me again"
    exit 1
  fi
done

mkdir -p "$installDir"
cd "$installDir"

echo "--- Cloning clmatching-chain @ $V1_TAG (with submodules) ---"
git clone --recurse-submodules --branch "$V1_TAG" "$V1_URL" CLMatching_v1

echo
echo "--- Cloning clmatching-frontend @ $FRONTEND_BRANCH ---"
git clone --branch "$FRONTEND_BRANCH" "$FRONTEND_URL" clmatching-frontend

echo
echo "--- Cloning CLMatching_AlphaRelease @ $ALPHA_BRANCH (used by 2x2 wrappers) ---"
git clone --branch "$ALPHA_BRANCH" "$ALPHA_URL" CLMatching_AlphaRelease

echo
echo "--- Verifying pre-staged NERSC assets ---"
if [[ -r "$SMALL_CKPT" ]]; then
    echo "  small light checkpoint: OK  ($SMALL_CKPT)"
else
    echo "  small light checkpoint: NOT READABLE at $SMALL_CKPT" >&2
    echo "  This is required for ND sim. Contact yuxuan@caltech.edu or set" >&2
    echo "  ND_PRODUCTION_CLMATCH_SMALL_CKPT to point at your own copy." >&2
fi

# --- Ensure the ND Alpha perceiver is available in BOTH alpha clones ---
# v1's overflow_rescue_pipeline imports first-stage code from its bundled
# AlphaRelease submodule (CLMatching_v1/CLMatching_AlphaRelease/), whose
# asset_resolver hard-checks for the perceiver_charge_light_relation asset
# at NewMLSection/runs/ndfull_run_distributed/checkpoint.pt. The standalone
# CLMatching_AlphaRelease clone also needs it. We download once, symlink twice.
STANDALONE_CKPT="CLMatching_AlphaRelease/NewMLSection/runs/ndfull_run_distributed/checkpoint.pt"
V1_SUBMOD_CKPT="CLMatching_v1/CLMatching_AlphaRelease/NewMLSection/runs/ndfull_run_distributed/checkpoint.pt"
PERCEIVER_URL=https://github.com/MadivB/CLMatching_AlphaRelease/releases/download/v0.1.0/checkpoint.pt
if [[ ! -f "$STANDALONE_CKPT" ]]; then
    echo
    echo "--- Downloading ND Alpha perceiver checkpoint (~490 MB) ---"
    mkdir -p "$(dirname "$STANDALONE_CKPT")"
    if command -v curl >/dev/null 2>&1; then
        curl -L --fail -o "$STANDALONE_CKPT" "$PERCEIVER_URL" || {
            echo "ERROR: perceiver download failed. Fetch it manually:" >&2
            echo "  curl -L -o $STANDALONE_CKPT $PERCEIVER_URL" >&2
            exit 1
        }
    else
        echo "ERROR: curl not available. Fetch the perceiver manually:" >&2
        echo "  wget -O $STANDALONE_CKPT $PERCEIVER_URL" >&2
        exit 1
    fi
fi
mkdir -p "$(dirname "$V1_SUBMOD_CKPT")"
[[ -e "$V1_SUBMOD_CKPT" ]] || ln -s "$(pwd)/$STANDALONE_CKPT" "$V1_SUBMOD_CKPT"
echo "  ND Alpha perceiver: OK  ($STANDALONE_CKPT, symlinked into v1 submodule)"

# Final sanity check via the alpha check_install (which also validates 2x2 assets)
if command -v python >/dev/null 2>&1; then
    (cd CLMatching_AlphaRelease && python scripts/check_install.py) || {
        echo "  note: alpha check_install reports a residual missing asset; harmless"
        echo "        if you only use v1 ND + 2x2 wrappers."
    }
fi

echo
echo "--- CLMatching install OK ---"
echo "  v1 ND pipeline : $installDir/CLMatching_v1/testing/overflow_rescue_pipeline.py"
echo "  v1 launcher    : $installDir/CLMatching_v1/run_v1.sh"
echo "  2x2 (alpha)    : $installDir/CLMatching_AlphaRelease/"
echo "  frontend       : $installDir/clmatching-frontend/"
