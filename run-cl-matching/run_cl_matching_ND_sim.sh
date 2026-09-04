#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation) -- v1.0 pipeline, .PT-FIRST.
#
# Input  : run-ndlar-flow/<IN_NAME>/FLOW/<subDir>/<inName>.FLOW.hdf5
# Output : run-cl-matching/<OUT_NAME>/FLOW/<subDir>/<outName>.FLOW.hdf5     (HDF5, fields filled)
#          run-cl-matching/<OUT_NAME>/PT/<subDir>/<outName>.qlmatchND_v1.pt (source of truth)
#
# Workflow (per file):
#   1. Check if the .pt already exists at the canonical PT/<subDir>/<outName>.qlmatchND_v1.pt.
#   2. If yes  -> skip the v1 pipeline entirely; the .pt is the source of truth.
#      If no   -> copy input flow file to tmp; run the v1 pipeline; aggregate NPZs into .pt.
#   3. Regardless: apply the .pt into a fresh copy of the flow HDF5 and move it
#      to the canonical FLOW/<subDir>/ output.
#
# The .pt ALWAYS exists on disk after a successful run. Re-running against the
# same OUT_NAME is idempotent -- and free from the pipeline's perspective if
# the .pt is already there.

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

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

flowDstDir=$outDir/FLOW/$subDir
ptDstDir=$outDir/PT/$subDir
ptFile=$ptDstDir/${outName}.qlmatchND_v1.pt
outFile=$tmpOutDir/${outName}.FLOW.hdf5
workDir=$tmpOutDir/${outName}_work
dumpDir=$workDir/dump
rm -f "$outFile"
rm -rf "$workDir"

set -o errexit
mkdir -p "$flowDstDir" "$ptDstDir" "$workDir"

# ---- Stage 1: ensure the .pt exists ----
if [[ -f "$ptFile" ]]; then
    echo "PT cache hit: $ptFile"
    echo "  Skipping v1 pipeline; PT is the source of truth for this file."
else
    echo "PT cache miss: building $ptFile"
    mkdir -p "$dumpDir"
    echo "Copying input flow file for pipeline read:"
    echo "  $inFile -> $outFile"
    cp "$inFile" "$outFile"

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

    PIDS=()
    for w in $(seq 0 $((N_WORKERS - 1))); do
        g=$((w % N_GPUS))
        log="$workDir/worker${w}_gpu${g}.log"
        (
            CUDA_VISIBLE_DEVICES="$g" "$PY" testing/overflow_rescue_pipeline.py \
                --files "$outFile" \
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
        --src-file "$outFile" \
        --out "$ptFile" \
        --summary-json "$workDir/v1_aggregator_summary.json"

    if [[ ! -f "$ptFile" ]]; then
        echo "ERROR: aggregate_v1_to_pt did not produce $ptFile" >&2
        exit 3
    fi
fi

# ---- Stage 2: apply .pt to a fresh copy of the flow HDF5, then publish ----
echo "Copying input flow file for fill:"
echo "  $inFile -> $outFile"
[[ -f "$outFile" ]] || cp "$inFile" "$outFile"

run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/apply_pt_to_hdf5.py" \
    --pt "$ptFile" \
    --hdf5 "$outFile" \
    --summary-json "$workDir/v1_applier_summary.json"

"$PY" - <<PY
import h5py, sys
with h5py.File("$outFile", "r") as h:
    for path in ("charge/calib_prompt_hits/data", "charge/calib_final_hits/data"):
        d = h[path]
        if "t_0" not in d.dtype.names or "t_cluster_id" not in d.dtype.names:
            print(f"WARN: {path} dtype lacks t_0/t_cluster_id; skipping check.")
            continue
        nz = int((d["t_cluster_id"][:] != 0).any() or (d["t_0"][:] != 0).any())
        if not nz:
            print(f"ERROR: {path} still all zero after PT-fill.", file=sys.stderr)
            sys.exit(2)
print("PT-fill verified: t_0 and t_cluster_id populated in HDF5.")
PY

mv "$outFile" "$flowDstDir/"

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
