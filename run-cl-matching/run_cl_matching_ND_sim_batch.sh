#!/usr/bin/env bash
#
# ND-LAr charge-light matching (simulation) -- v1.0 pipeline, BATCH .PT-FIRST,
# IN-PLACE FLOW EDIT.
#
# Processes MULTIPLE indices on ONE node in a single pipeline invocation.
# Per index:
#   * If <outDir>/PT/<subDir>/<outName>.qlmatchND_v1.pt already exists,
#     the pipeline is skipped for that index -- only the fill step runs.
#   * Otherwise the input flow file is added to the pipeline's --files list,
#     then the .pt is built afterwards from the NPZ shards.
#
# Every index ALWAYS ends with a .pt on disk (either pre-existing or newly
# built) AND its INPUT flow file modified in place to have the t_0 /
# t_cluster_id / t_confidence fields filled from that .pt. No FLOW/ subdir is
# created under this step's output dir.
#
# Usage:
#   ND_PRODUCTION_IN_NAME=... ND_PRODUCTION_OUT_NAME=... \
#   ND_PRODUCTION_OUTDIR_BASE=... ND_PRODUCTION_LOGDIR_BASE=... \
#   ND_PRODUCTION_CLMATCH_INDICES="0 1 2 3" ./run_cl_matching_ND_sim_batch.sh
#   OR
#   ./run_cl_matching_ND_sim_batch.sh 0 1 2 3

source ../util/reload_in_container.inc.sh
source ../util/init.inc.sh

# See run_cl_matching_ND_sim.sh for the rationale; keeping the wrappers
# consistent: force python/3.13 back so the pytorch env's user-site (with
# plotly and other v1 deps) is reachable.
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
declare -A IDX_IN     # index -> upstream flow path (in-place edit target)
declare -A IDX_PT     # index -> canonical PT path
declare -A IDX_ONAME  # index -> "<OUT_NAME>.<NNNNNNN>"

INDICES_TO_RUN=()
FILES_ARGS=()
for idx in "${INDICES[@]}"; do
    gidx=$(printf "%07d" "$idx")
    sdir=$(printf "%07d" $((idx / 1000 * 1000)))
    inName=$ND_PRODUCTION_IN_NAME.$gidx
    inFile=$(realpath "$inDir/FLOW/$sdir/${inName}.FLOW.hdf5")
    onm=$ND_PRODUCTION_OUT_NAME.$gidx
    pt_d="$ND_PRODUCTION_OUTDIR_BASE/$stepname/$ND_PRODUCTION_OUT_NAME/PT/$sdir"
    pt_f="$pt_d/${onm}.qlmatchND_v1.pt"
    mkdir -p "$pt_d"

    IDX_IN[$idx]=$inFile
    IDX_PT[$idx]=$pt_f
    IDX_ONAME[$idx]=$onm

    if [[ -f "$pt_f" ]]; then
        echo "  idx=$idx: CLMatching .pt found, algorithm output already exists at $pt_f"
    else
        FILES_ARGS+=("$inFile")
        INDICES_TO_RUN+=("$idx")
        echo "  idx=$idx: CLMatching .pt not found, running the full algorithm"
    fi
done
echo "batch: ${#INDICES_TO_RUN[@]} indices need pipeline run; ${#INDICES[@]} total."

# ---- Stage 2: pipeline for the queued indices (if any) ----
# Pipeline reads input HDF5s read-only and writes NPZ shards to $DUMP_DIR;
# the flow files themselves are never mutated by the pipeline.
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
        in_f="${IDX_IN[$idx]}"
        pt_f="${IDX_PT[$idx]}"
        run "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/aggregate_v1_to_pt.py" \
            --dump-dir "$DUMP_DIR" \
            --src-file "$in_f" \
            --out "$pt_f" \
            --summary-json "$BATCH_WORKDIR/idx${idx}_aggregator_summary.json"
        [[ -f "$pt_f" ]] || { echo "ERROR idx=$idx: aggregator did not produce $pt_f" >&2; exit 4; }
    done
fi

# ---- Stage 3: apply .pt into each INPUT flow file in place ----
FILLED=0
for idx in "${INDICES[@]}"; do
    onm="${IDX_ONAME[$idx]}"
    pt_f="${IDX_PT[$idx]}"
    in_f="${IDX_IN[$idx]}"
    echo "  idx=$idx: CLMatching .pt at $pt_f, filling the flow file in place at $in_f"
    applier_summary="$BATCH_WORKDIR/idx${idx}_applier_summary.json"
    "$PY" "$ND_PRODUCTION_DIR/run-cl-matching/apply_pt_to_hdf5.py" \
        --pt "$pt_f" --hdf5 "$in_f" \
        --summary-json "$applier_summary"
    "$PY" - "$applier_summary" "$pt_f" "$idx" <<'PY'
import json, sys
sp, ptp, idx = sys.argv[1], sys.argv[2], sys.argv[3]
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
    print(f"  idx={idx}: flow file does not contain the required field(s):")
    for s in skipped:
        print(f"    - {s}")
    if wrote:
        print(f"    (some fields were filled OK: {', '.join(wrote)})")
    else:
        print(f"    skipping the fill-in stage. .pt file completed at {ptp}")
PY
    FILLED=$((FILLED + 1))
done
echo "batch: filled $FILLED / ${#INDICES[@]} input flow files in place."

if [[ -n "${logDir:-}" ]]; then
    mkdir -p "$logDir/${outName}_batch_logs"
    cp "$BATCH_WORKDIR"/worker*.log "$logDir/${outName}_batch_logs/" 2>/dev/null || true
    cp "$BATCH_WORKDIR"/idx*_summary.json "$logDir/" 2>/dev/null || true
fi
rm -rf "$BATCH_WORKDIR"
[[ "$FILLED" -eq "${#INDICES[@]}" ]] || exit 3
