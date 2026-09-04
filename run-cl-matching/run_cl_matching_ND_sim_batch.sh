#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation) -- v1.0 pipeline, BATCH mode.
#
# Processes MULTIPLE indices on ONE node in a single pipeline invocation, so
# the model / frontend load cost (~20s per worker) is amortized across every
# file instead of paid per-file. Everything else matches run_cl_matching_ND_sim.sh.
#
# Usage as a normal ND production step (one salloc, many indices back-to-back):
#   ND_PRODUCTION_IN_NAME=... ND_PRODUCTION_OUT_NAME=... \
#   ND_PRODUCTION_OUTDIR_BASE=... ND_PRODUCTION_LOGDIR_BASE=... \
#   ND_PRODUCTION_CLMATCH_INDICES="0 1 2 3" ./run_cl_matching_ND_sim_batch.sh
#
# Or via positional args (indices only):
#   ./run_cl_matching_ND_sim_batch.sh 0 1 2 3
#
# Each index N produces the same output layout as the single-file wrapper:
#   run-cl-matching/<OUT_NAME>/FLOW/<subDir>/<OUT_NAME>.<NNNNNNN>.FLOW.hdf5
#
# Requires a 4-GPU node.

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
        exit 1
    fi
done
if [[ ! -r "$SMALL_CKPT" ]]; then
    echo "ERROR: small light checkpoint not readable at $SMALL_CKPT" >&2
    exit 1
fi

# Resolve the list of indices to process (positional args OR env var).
if [[ $# -gt 0 ]]; then
    INDICES=("$@")
elif [[ -n "${ND_PRODUCTION_CLMATCH_INDICES:-}" ]]; then
    # shellcheck disable=SC2206
    INDICES=(${ND_PRODUCTION_CLMATCH_INDICES})
else
    echo "ERROR: no indices given. Pass positional args OR set ND_PRODUCTION_CLMATCH_INDICES=\"0 1 2 3\"" >&2
    exit 1
fi
echo "Batch mode: ${#INDICES[@]} indices: ${INDICES[*]}"

# For each index, resolve upstream flow file and stage a per-index tmp copy.
inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/$ND_PRODUCTION_IN_NAME
declare -A IDX_OUTFILE   # index -> tmp copy path
declare -A IDX_OUTDIR    # index -> canonical destination dir
declare -A IDX_OUTNAME   # index -> "<OUT_NAME>.<NNNNNNN>"
BATCH_WORKDIR=$tmpOutDir/batch_$$_$(date +%s)
DUMP_DIR=$BATCH_WORKDIR/dump

set -o errexit
mkdir -p "$BATCH_WORKDIR" "$DUMP_DIR"

FILES_ARGS=()
for idx in "${INDICES[@]}"; do
    gidx=$(printf "%07d" "$idx")
    sdir=$(printf "%07d" $((idx / 1000 * 1000)))
    inName=$ND_PRODUCTION_IN_NAME.$gidx
    inFile=$(realpath "$inDir/FLOW/$sdir/${inName}.FLOW.hdf5")
    idxOutName=$ND_PRODUCTION_OUT_NAME.$gidx
    tmpFile="$BATCH_WORKDIR/${idxOutName}.FLOW.hdf5"
    canonicalDir="$ND_PRODUCTION_OUTDIR_BASE/$stepname/$ND_PRODUCTION_OUT_NAME/FLOW/$sdir"
    echo "  idx=$idx: $inFile -> $tmpFile"
    cp "$inFile" "$tmpFile"
    IDX_OUTFILE[$idx]=$tmpFile
    IDX_OUTDIR[$idx]=$canonicalDir
    IDX_OUTNAME[$idx]=$idxOutName
    FILES_ARGS+=("$tmpFile")
done

# --- flag set copied verbatim from CLMatching_v1/run_v1.sh (V09 block) ---
V1_ARGS=(--backbone stack2 --merge-p2 --sigma-mode poisson --max-clip-ticks 4
         --police locked --merge-vertex --skip-baseline --phase3 joint
         --pass2-trade --pass2-light-nom --force-coverage --swap-fix
         --swap-ratio-max 0.85 --p2-threshold 30 --predict-min-energy 1.5
         --skip-v2 --gate-support --force-simple --isolate-cm 25 --fast-scan
         --edge-penalty --subtick --conf-cluster
         --light-ckpt "$SMALL_CKPT" --frontend-repo "$FRONTEND")

cd "$CLMATCH_V1"
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1

echo "Launching $N_WORKERS workers on $N_GPUS GPUs across ${#FILES_ARGS[@]} files..."
nvidia-smi -L 2>&1 | head -8 || echo "no nvidia-smi"

PIDS=()
for w in $(seq 0 $((N_WORKERS - 1))); do
    g=$((w % N_GPUS))
    log="$BATCH_WORKDIR/worker${w}_gpu${g}.log"
    (
        CUDA_VISIBLE_DEVICES="$g" "$PY" testing/overflow_rescue_pipeline.py \
            --files "${FILES_ARGS[@]}" \
            --out "$BATCH_WORKDIR/groups_worker${w}.jsonl" \
            --dump-dir "$DUMP_DIR" \
            --event-stride "$N_WORKERS" --event-offset "$w" \
            "${V1_ARGS[@]}"
    ) > "$log" 2>&1 &
    PIDS+=("$!")
    echo "  worker $w -> GPU $g  log=$log"
done

FAIL=0
for p in "${PIDS[@]}"; do wait "$p" || FAIL=$((FAIL + 1)); done
n_dump=$(ls "$DUMP_DIR"/*.npz 2>/dev/null | wc -l)
echo "workers done; failures=$FAIL  npz-shards=$n_dump"

# --- aggregate NPZs per source file ---
run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/aggregate_v1_to_hdf5.py" \
    --dump-dir "$DUMP_DIR" \
    --summary-json "$BATCH_WORKDIR/v1_aggregator_summary.json"

# --- verify + move each per-index file into its canonical location ---
MOVED=0
for idx in "${INDICES[@]}"; do
    of="${IDX_OUTFILE[$idx]}"
    od="${IDX_OUTDIR[$idx]}"
    on="${IDX_OUTNAME[$idx]}"
    if [[ ! -f "$of" ]]; then
        echo "WARN idx=$idx: staged file vanished at $of" >&2
        continue
    fi
    populated=$("$PY" - "$of" <<'PY'
import sys, h5py
p = sys.argv[1]
with h5py.File(p, "r") as h:
    d = h["charge/calib_prompt_hits/data"]
    if "t_0" not in d.dtype.names:
        print("no-field"); sys.exit(0)
    if (d["t_cluster_id"][:] != 0).any() or (d["t_0"][:] != 0).any():
        print("yes")
    else:
        print("no")
PY
)
    if [[ "$populated" == "yes" ]]; then
        mkdir -p "$od"
        mv "$of" "$od/${on}.FLOW.hdf5"
        MOVED=$((MOVED + 1))
    else
        echo "WARN idx=$idx: HDF5 fields not populated (populated=$populated); LEFT at $of" >&2
    fi
done
echo "batch: moved $MOVED / ${#INDICES[@]} results into canonical outDirs."

# Preserve logs; drop shards.
if [[ -n "${logDir:-}" ]]; then
    mkdir -p "$logDir/${outName}_batch_logs"
    cp "$BATCH_WORKDIR"/worker*.log "$logDir/${outName}_batch_logs/" 2>/dev/null || true
    [[ -f "$BATCH_WORKDIR/v1_aggregator_summary.json" ]] && \
        cp "$BATCH_WORKDIR/v1_aggregator_summary.json" \
           "$logDir/${outName}_v1_aggregator_summary.json"
fi
rm -rf "$BATCH_WORKDIR"
[[ "$MOVED" -eq "${#INDICES[@]}" ]] || exit 3
