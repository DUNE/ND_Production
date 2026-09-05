#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation) -- v1.0 pipeline, .PT-FIRST,
# IN-PLACE FLOW EDIT.
#
# Input : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
#         (opened r+ and MODIFIED IN PLACE -- the CL matching results are
#          written back into the reserved t_0 / t_cluster_id / t_confidence
#          fields that ndlar_flow left as placeholders)
# Output: run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatchND_v1.pt
#         (the ONLY new artifact under this step's output dir; no FLOW/ subdir
#          is created -- CL matching does not duplicate the flow file)
#
# Workflow (per file):
#   1. Check if the .pt exists at <outDir>/PT/<subDir>/<outName>.qlmatchND_v1.pt.
#      If yes -> skip the v1 pipeline (the .pt is the source of truth).
#      If no  -> run the pipeline reading the input flow file directly,
#                aggregate NPZ shards into the canonical .pt.
#   2. Apply the .pt into the INPUT flow file in place, overwriting whatever
#      values the reserved fields (t_0, t_cluster_id, t_confidence) held --
#      those fields are placeholders reserved by ndlar_flow for us to fill.
#
# Re-runs against the same OUT_NAME are idempotent: the .pt is cached, and
# re-applying it produces the same field values (with a warn about the now
# non-default entries, which is expected on the 2nd+ run).

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# ND_Production's util/prelude.inc.sh setup_cuda() loads python/3.11 which
# clobbers PYTHONUSERBASE for Python 3.12 -- CLMatching v1 uses the NERSC
# pytorch env (Python 3.12) and needs to reach the python/3.13 module's user
# site-packages (where plotly and other deps live). Force it back.
if [[ "$LMOD_SYSTEM_NAME" == "perlmutter" ]]; then
    module load python/3.13-26.8.0 2>/dev/null || true
fi

CLMATCH_V1=${ND_PRODUCTION_CLMATCH_V1_REPO:-"$ND_PRODUCTION_INSTALL_DIR/CLMatching_v1"}
FRONTEND=${ND_PRODUCTION_CLMATCH_FRONTEND:-"$ND_PRODUCTION_INSTALL_DIR/clmatching-frontend"}
SMALL_CKPT=${ND_PRODUCTION_CLMATCH_SMALL_CKPT:-/global/cfs/cdirs/dune/users/yuxuan/NDLAr-full/NewMLSection/runs/ndfull_small4x/best_model_arch.pt}
PY=${PY:-/global/common/software/nersc9/pytorch/2.8.0/bin/python}
N_WORKERS=${ND_PRODUCTION_CLMATCH_WORKERS:-8}
N_GPUS=${ND_PRODUCTION_CLMATCH_GPUS:-4}

for r in "$CLMATCH_V1" "$FRONTEND"; do
    if [[ ! -d "$r" ]]; then
        echo "ERROR: required repo missing at $r" >&2
        echo "       Run ./install_cl_matching.sh first, or override with" >&2
        echo "       ND_PRODUCTION_CLMATCH_V1_REPO / ND_PRODUCTION_CLMATCH_FRONTEND." >&2
        exit 1
    fi
done
if [[ ! -r "$SMALL_CKPT" ]]; then
    echo "ERROR: small light checkpoint not readable at $SMALL_CKPT" >&2
    exit 1
fi

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/$ND_PRODUCTION_IN_NAME
inName=$ND_PRODUCTION_IN_NAME.$globalIdx
inFile=$(realpath $inDir/FLOW/$subDir/${inName}.FLOW.hdf5)

ptDstDir=$outDir/PT/$subDir
ptFile=$ptDstDir/${outName}.qlmatchND_v1.pt
workDir=$tmpOutDir/${outName}_work
dumpDir=$workDir/dump
rm -rf "$workDir"

set -o errexit
mkdir -p "$ptDstDir" "$workDir"

# ---- Stage 1: ensure the .pt exists ----
if [[ -f "$ptFile" ]]; then
    echo "CLMatching .pt found, algorithm output already exists at $ptFile"
else
    echo "CLMatching .pt not found, running the full algorithm"
    mkdir -p "$dumpDir"

    V1_ARGS=(--backbone stack2 --merge-p2 --sigma-mode poisson --max-clip-ticks 4
             --police locked --merge-vertex --skip-baseline --phase3 joint
             --pass2-trade --pass2-light-nom --force-coverage --swap-fix
             --swap-ratio-max 0.85 --p2-threshold 30 --predict-min-energy 1.5
             --skip-v2 --gate-support --force-simple --isolate-cm 25 --fast-scan
             --edge-penalty --subtick --conf-cluster
             --light-ckpt "$SMALL_CKPT" --frontend-repo "$FRONTEND")

    cd "$CLMATCH_V1"
    export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
    echo "Launching $N_WORKERS workers on $N_GPUS GPUs..."
    nvidia-smi -L 2>&1 | head -8 || echo "no nvidia-smi"

    # Pipeline reads $inFile directly (read-only): it dumps NPZ shards into
    # dumpDir and never mutates the input HDF5.
    PIDS=()
    for w in $(seq 0 $((N_WORKERS - 1))); do
        g=$((w % N_GPUS))
        log="$workDir/worker${w}_gpu${g}.log"
        (
            CUDA_VISIBLE_DEVICES="$g" "$PY" testing/overflow_rescue_pipeline.py \
                --files "$inFile" \
                --out "$workDir/groups_worker${w}.jsonl" \
                --dump-dir "$dumpDir" \
                --event-stride "$N_WORKERS" --event-offset "$w" \
                "${V1_ARGS[@]}"
        ) > "$log" 2>&1 &
        PIDS+=("$!")
        echo "  worker $w -> GPU $g  log=$log"
    done
    FAIL=0
    for p in "${PIDS[@]}"; do wait "$p" || FAIL=$((FAIL + 1)); done
    n_dump=$(ls "$dumpDir"/*.npz 2>/dev/null | wc -l)
    echo "workers done; failures=$FAIL  npz-shards=$n_dump"
    if [[ "$FAIL" -gt 0 && "$n_dump" -eq 0 ]]; then
        echo "ERROR: all workers failed and no shards produced." >&2
        exit 2
    fi

    run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/aggregate_v1_to_pt.py" \
        --dump-dir "$dumpDir" \
        --src-file "$inFile" \
        --out "$ptFile" \
        --summary-json "$workDir/v1_aggregator_summary.json"

    if [[ ! -f "$ptFile" ]]; then
        echo "ERROR: aggregate_v1_to_pt did not produce $ptFile" >&2
        exit 3
    fi
fi

# ---- Stage 2: apply .pt into the INPUT flow file, in place ----
echo "CLMatching .pt at $ptFile, filling the flow file in place at $inFile"

applier_summary="$workDir/v1_applier_summary.json"
run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/apply_pt_to_hdf5.py" \
    --pt "$ptFile" \
    --hdf5 "$inFile" \
    --summary-json "$applier_summary"

# Report any skipped fields (e.g. flow file predates the ndlar_flow t_0 dtype
# bump, so its compound dtype doesn't reserve the fields we would fill, or the
# HDF5 was not writable).
"$PY" - "$applier_summary" "$ptFile" <<'PY'
import json, sys
sp, ptp = sys.argv[1], sys.argv[2]
d = json.load(open(sp))
res = d.get("result", {})
skipped, wrote = [], []
for section in ("prompt", "final"):
    sec = res.get(section, {}) or {}
    for f, why in (sec.get("skipped_fields") or {}).items():
        skipped.append(f"{section}.{f} ({why})")
    for f in (sec.get("wrote_fields") or []):
        wrote.append(f"{section}.{f}")
if skipped:
    print("flow file does not contain the required field(s):")
    for s in skipped:
        print(f"  - {s}")
    if wrote:
        print(f"  (some fields were filled OK: {', '.join(wrote)})")
    else:
        print(f"  skipping the fill-in stage. .pt file completed at {ptp}")
PY

# preserve logs, drop bulky shards
mkdir -p "$logDir"
if compgen -G "$workDir/worker*.log" > /dev/null; then
    mkdir -p "$logDir/${outName}_worker_logs"
    cp "$workDir"/worker*.log "$logDir/${outName}_worker_logs/" 2>/dev/null || true
fi
for f in v1_aggregator_summary.json v1_applier_summary.json; do
    [[ -f "$workDir/$f" ]] && cp "$workDir/$f" "$logDir/${outName}_$f"
done
rm -rf "$workDir"
