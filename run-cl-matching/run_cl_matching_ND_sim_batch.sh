#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation) -- v1.0 pipeline, BATCH .PT-FIRST.
#
# Processes MULTIPLE indices on ONE node in a single pipeline invocation.
# Per index:
#   * If <outDir>/PT/<subDir>/<outName>.qlmatchND_v1.pt already exists,
#     the pipeline is skipped for that index -- only the fill step runs.
#   * Otherwise the input flow file is copied to tmp and included in the
#     pipeline's --files list, then the .pt is built afterwards.
#
# Every index ALWAYS ends with a .pt on disk (either pre-existing or newly
# built) AND an HDF5 in outDir/FLOW/<subDir>/ with fields filled from the .pt.
#
# Usage:
#   ND_PRODUCTION_IN_NAME=... ND_PRODUCTION_OUT_NAME=... \
#   ND_PRODUCTION_OUTDIR_BASE=... ND_PRODUCTION_LOGDIR_BASE=... \
#   ND_PRODUCTION_CLMATCH_INDICES="0 1 2 3" ./run_cl_matching_ND_sim_batch.sh
#   OR
#   ./run_cl_matching_ND_sim_batch.sh 0 1 2 3

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

CLMATCH_V1=${ND_PRODUCTION_CLMATCH_V1_REPO:-"$ND_PRODUCTION_INSTALL_DIR/CLMatching_v1"}
FRONTEND=${ND_PRODUCTION_CLMATCH_FRONTEND:-"$ND_PRODUCTION_INSTALL_DIR/clmatching-frontend"}
SMALL_CKPT=${ND_PRODUCTION_CLMATCH_SMALL_CKPT:-/global/cfs/cdirs/dune/users/yuxuan/NDLAr-full/NewMLSection/runs/ndfull_small4x/best_model_arch.pt}
PY=${PY:-/global/common/software/nersc9/pytorch/2.8.0/bin/python}
N_WORKERS=${ND_PRODUCTION_CLMATCH_WORKERS:-8}
N_GPUS=${ND_PRODUCTION_CLMATCH_GPUS:-4}

for r in "$CLMATCH_V1" "$FRONTEND"; do
    [[ -d "$r" ]] || { echo "ERROR: required repo missing at $r" >&2; exit 1; }
done
[[ -r "$SMALL_CKPT" ]] || { echo "ERROR: small light checkpoint not readable at $SMALL_CKPT" >&2; exit 1; }

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

inDir=${ND_PRODUCTION_OUTDIR_BASE}/run-ndlar-flow/$ND_PRODUCTION_IN_NAME
BATCH_WORKDIR=$tmpOutDir/batch_$$_$(date +%s)
DUMP_DIR=$BATCH_WORKDIR/dump
mkdir -p "$BATCH_WORKDIR" "$DUMP_DIR"

set -o errexit

# ---- Stage 1: enumerate indices; decide which need pipeline (missing PT) ----
declare -A IDX_IN     # index -> upstream flow path
declare -A IDX_TMP    # index -> tmp copy path (only for pipeline-needed ones)
declare -A IDX_PT     # index -> canonical PT path
declare -A IDX_FLOW_D # index -> canonical FLOW dir
declare -A IDX_ONAME  # index -> "<OUT_NAME>.<NNNNNNN>"

INDICES_TO_RUN=()
FILES_ARGS=()
for idx in "${INDICES[@]}"; do
    gidx=$(printf "%07d" "$idx")
    sdir=$(printf "%07d" $((idx / 1000 * 1000)))
    inName=$ND_PRODUCTION_IN_NAME.$gidx
    inFile=$(realpath "$inDir/FLOW/$sdir/${inName}.FLOW.hdf5")
    onm=$ND_PRODUCTION_OUT_NAME.$gidx
    flow_d="$ND_PRODUCTION_OUTDIR_BASE/$stepname/$ND_PRODUCTION_OUT_NAME/FLOW/$sdir"
    pt_d="$ND_PRODUCTION_OUTDIR_BASE/$stepname/$ND_PRODUCTION_OUT_NAME/PT/$sdir"
    pt_f="$pt_d/${onm}.qlmatchND_v1.pt"
    mkdir -p "$flow_d" "$pt_d"

    IDX_IN[$idx]=$inFile
    IDX_PT[$idx]=$pt_f
    IDX_FLOW_D[$idx]=$flow_d
    IDX_ONAME[$idx]=$onm

    if [[ -f "$pt_f" ]]; then
        echo "  idx=$idx: PT cache hit ($pt_f)"
    else
        tmp="$BATCH_WORKDIR/${onm}.FLOW.hdf5"
        cp "$inFile" "$tmp"
        IDX_TMP[$idx]=$tmp
        FILES_ARGS+=("$tmp")
        INDICES_TO_RUN+=("$idx")
        echo "  idx=$idx: PT cache MISS -> queued for pipeline"
    fi
done
echo "batch: ${#INDICES_TO_RUN[@]} indices need pipeline run; ${#INDICES[@]} total."

# ---- Stage 2: pipeline for the queued indices (if any) ----
if [[ ${#FILES_ARGS[@]} -gt 0 ]]; then
    V1_ARGS=(--backbone stack2 --merge-p2 --sigma-mode poisson --max-clip-ticks 4
             --police locked --merge-vertex --skip-baseline --phase3 joint
             --pass2-trade --pass2-light-nom --force-coverage --swap-fix
             --swap-ratio-max 0.85 --p2-threshold 30 --predict-min-energy 1.5
             --skip-v2 --gate-support --force-simple --isolate-cm 25 --fast-scan
             --edge-penalty --subtick --conf-cluster
             --light-ckpt "$SMALL_CKPT" --frontend-repo "$FRONTEND")

    cd "$CLMATCH_V1"
    export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1
    echo "Launching $N_WORKERS workers on $N_GPUS GPUs for ${#FILES_ARGS[@]} files..."
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

    # Aggregate per source file into per-index .pt at the canonical PT paths.
    for idx in "${INDICES_TO_RUN[@]}"; do
        tmp="${IDX_TMP[$idx]}"
        pt_f="${IDX_PT[$idx]}"
        run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/aggregate_v1_to_pt.py" \
            --dump-dir "$DUMP_DIR" \
            --src-file "$tmp" \
            --out "$pt_f" \
            --summary-json "$BATCH_WORKDIR/idx${idx}_aggregator_summary.json"
        [[ -f "$pt_f" ]] || { echo "ERROR idx=$idx: aggregator did not produce $pt_f" >&2; exit 4; }
    done
fi

# ---- Stage 3: apply .pt to a fresh HDF5 copy per index, move to canonical ----
MOVED=0
for idx in "${INDICES[@]}"; do
    onm="${IDX_ONAME[$idx]}"
    pt_f="${IDX_PT[$idx]}"
    flow_d="${IDX_FLOW_D[$idx]}"
    fill_src="${IDX_TMP[$idx]:-}"
    if [[ -z "$fill_src" ]]; then
        # cache-hit index: we didn't cp earlier. Copy input now for fill.
        fill_src="$BATCH_WORKDIR/${onm}.FLOW.hdf5"
        cp "${IDX_IN[$idx]}" "$fill_src"
    fi
    "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/apply_pt_to_hdf5.py" \
        --pt "$pt_f" --hdf5 "$fill_src" \
        --summary-json "$BATCH_WORKDIR/idx${idx}_applier_summary.json"
    mv "$fill_src" "$flow_d/${onm}.FLOW.hdf5"
    MOVED=$((MOVED + 1))
done
echo "batch: moved $MOVED / ${#INDICES[@]} results into canonical outDirs."

if [[ -n "${logDir:-}" ]]; then
    mkdir -p "$logDir/${outName}_batch_logs"
    cp "$BATCH_WORKDIR"/worker*.log "$logDir/${outName}_batch_logs/" 2>/dev/null || true
    cp "$BATCH_WORKDIR"/idx*_summary.json "$logDir/" 2>/dev/null || true
fi
rm -rf "$BATCH_WORKDIR"
[[ "$MOVED" -eq "${#INDICES[@]}" ]] || exit 3
