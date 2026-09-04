#!/usr/bin/env python3
"""Aggregate per-event NPZ shards from CLMatching_v1's overflow_rescue_pipeline
back into the source FLOW HDF5 file, populating the reserved fields
  charge/calib_prompt_hits.data.{t_0, t_cluster_id, t_confidence}
  charge/calib_final_hits.data.{t_0, t_cluster_id, t_confidence}

v1 pipeline dump-dir NPZ layout (see overflow_rescue_pipeline.py ~L2527):
  hit_refs   int64 array of indices into charge/calib_prompt_hits/data
  ts_final   float64 per-hit reconstructed t0 (matching ticks; sentinel < 0)
  labels     int (per-hit cluster id; -1 = unassigned)
  hit_conf93 float32 (per-hit confidence; present when --conf-cluster; NaN
                       for light-blind clusters). Optional.

For each prompt-hit index the following is written:
  t_0            int16   clipped(ts_final)   (sentinel -1 for unassigned)
  t_cluster_id   int16   clipped(labels)      (sentinel -1)
  t_confidence   float32 hit_conf93 or 0.0 if unavailable  (NaN allowed)

The calib_final_hits fields are then derived through the same
prompt->final ref used by the alpha aggregator (final hit's fields = column-0
prompt hit's fields) so consumers get consistent per-final-hit values.

The HDF5 is opened in r+ mode. WARN (and count) if any of the three fields
is non-zero before writing; overwrite regardless (matches the user's stated
policy: fields are reserved and left empty for QL matching to fill).
"""

from __future__ import annotations
import argparse, json, sys, os
from pathlib import Path
from typing import Any

import numpy as np
import h5py


T0_SENTINEL_I2 = -1
CLUSTER_SENTINEL_I2 = -1
CONF_UNAVAILABLE_F4 = 0.0  # zero = "not filled" (matches init default)

PROMPT_DSET = "charge/calib_prompt_hits/data"
FINAL_DSET = "charge/calib_final_hits/data"
FINAL_TO_PROMPT_REF = "charge/calib_prompt_hits/ref/charge/calib_final_hits/ref"

WRITEBACK_FIELDS = ("t_0", "t_cluster_id", "t_confidence")


def _clip_float_to_i2(arr: np.ndarray) -> tuple[np.ndarray, int, int, int]:
    lo, hi = np.iinfo(np.int16).min, np.iinfo(np.int16).max
    finite = np.isfinite(arr)
    n_high = int((finite & (arr > hi)).sum())
    n_low = int((finite & (arr < lo)).sum())
    max_abs = int(np.nanmax(np.abs(arr))) if finite.any() else 0
    # Non-finite -> sentinel.
    out = np.where(finite, np.clip(arr, lo, hi), T0_SENTINEL_I2).astype(np.int16)
    return out, n_high, n_low, max_abs


def _clip_int_to_i2(arr: np.ndarray) -> tuple[np.ndarray, int]:
    lo, hi = np.iinfo(np.int16).min, np.iinfo(np.int16).max
    n_over = int(((arr > hi) | (arr < lo)).sum())
    return np.clip(arr, lo, hi).astype(np.int16), n_over


def _calib_final_to_prompt_indices(h: h5py.File) -> np.ndarray:
    """Per calib_final_hits row -> the source calib_prompt_hits row (col-0 of
    the ref dset, same convention as the alpha aggregator)."""
    final = h[FINAL_DSET]
    n_final = int(final.shape[0])
    if FINAL_TO_PROMPT_REF in h and int(h[FINAL_TO_PROMPT_REF].shape[0]) == n_final:
        return np.asarray(h[FINAL_TO_PROMPT_REF][:, 0], dtype=np.int64)
    if "id" in final.dtype.names:
        return np.asarray(final["id"], dtype=np.int64)
    raise RuntimeError(
        f"cannot derive final->prompt mapping: neither {FINAL_TO_PROMPT_REF} "
        "nor a well-formed 'id' field on calib_final_hits/data"
    )


def _gather_shards(shard_dir: Path) -> list[Path]:
    """v1 dump-dir names shards <ftag>_ev<ev_id>.npz. Return them sorted."""
    return sorted(p for p in shard_dir.glob("*_ev*.npz")
                  if "_ev" in p.stem and not p.stem.endswith("_backup"))


def _load_shard(npz_path: Path) -> dict[str, Any] | None:
    try:
        d = np.load(npz_path, allow_pickle=False)
    except Exception as exc:
        print(f"  SKIP unreadable shard {npz_path.name}: {exc}", file=sys.stderr)
        return None
    for req in ("hit_refs", "ts_final", "labels"):
        if req not in d.files:
            print(f"  SKIP shard {npz_path.name}: missing field '{req}'", file=sys.stderr)
            return None
    src_file = str(d.get("src_file", "")) if "src_file" in d.files else ""
    return {
        "path": npz_path,
        "src_file": src_file,
        "hit_refs": np.asarray(d["hit_refs"], dtype=np.int64),
        "ts_final": np.asarray(d["ts_final"], dtype=np.float64),
        "labels": np.asarray(d["labels"], dtype=np.int64),
        "hit_conf93": (np.asarray(d["hit_conf93"], dtype=np.float32)
                       if "hit_conf93" in d.files else None),
    }


def _warn_and_count_nonzero(dset: h5py.Dataset, label: str) -> dict[str, int]:
    """Peek at each writeback field; count non-zero entries; emit WARN if any."""
    counts: dict[str, int] = {}
    names = dset.dtype.names or ()
    for field in WRITEBACK_FIELDS:
        if field not in names:
            continue
        arr = dset[field][:]
        # Treat NaN as "not filled" for the confidence float; only real nonzeros count.
        if arr.dtype.kind == "f":
            nz = int(np.count_nonzero(np.nan_to_num(arr, nan=0.0)))
        else:
            nz = int((arr != 0).sum())
        counts[field] = nz
        if nz > 0:
            print(f"  WARNING: {label}[{field}] had {nz} non-default entries "
                  "before v1 writeback; overwriting all values.", flush=True)
    return counts


def aggregate_one_file(src_file: Path, shards: list[dict], *, verbose: bool) -> dict:
    """Do the full read-modify-write on ONE source flow file."""
    with h5py.File(src_file, "r") as h:
        n_prompt = int(h[PROMPT_DSET].shape[0])
        n_final = int(h[FINAL_DSET].shape[0]) if FINAL_DSET in h else 0
        final_to_prompt = _calib_final_to_prompt_indices(h) if n_final else np.zeros(0, np.int64)

    # File-level aggregate: sentinel-init, then scatter each shard via hit_refs.
    prompt_t0_f = np.full(n_prompt, np.nan, dtype=np.float64)
    prompt_label_i = np.full(n_prompt, CLUSTER_SENTINEL_I2, dtype=np.int64)
    prompt_conf_f = np.full(n_prompt, np.nan, dtype=np.float32)

    n_events, n_assigned = 0, 0
    for sh in shards:
        refs = sh["hit_refs"]
        ts = sh["ts_final"]
        lb = sh["labels"]
        cf = sh["hit_conf93"]
        if refs.size != ts.size or refs.size != lb.size:
            print(f"  SKIP shard {sh['path'].name}: shape mismatch "
                  f"(hit_refs={refs.size} ts_final={ts.size} labels={lb.size})",
                  file=sys.stderr)
            continue
        valid_ref = (refs >= 0) & (refs < n_prompt)
        if not valid_ref.all():
            bad = int((~valid_ref).sum())
            print(f"  WARNING: shard {sh['path'].name}: {bad} hit_refs "
                  f"out of range [0,{n_prompt}); those will be skipped.",
                  file=sys.stderr)
        # Only scatter finite ts >= 0 (matches v1's assignment semantics).
        good = valid_ref & np.isfinite(ts) & (ts >= 0)
        prompt_t0_f[refs[good]] = ts[good]
        # Cluster labels: scatter all valid refs (labels can be -1 = unassigned).
        prompt_label_i[refs[valid_ref]] = lb[valid_ref]
        # Confidence: scatter valid refs; leave NaN elsewhere.
        if cf is not None and cf.size == refs.size:
            prompt_conf_f[refs[valid_ref]] = cf[valid_ref]
        n_events += 1
        n_assigned += int(good.sum())

    # Convert to on-disk dtypes with clipping / sentinel handling.
    p_t0_i2, oh_high, oh_low, oh_max = _clip_float_to_i2(prompt_t0_f)
    p_cl_i2, cl_over = _clip_int_to_i2(prompt_label_i)
    # Confidence: NaN -> "not filled" (0.0). Callers can distinguish assigned-with-NaN
    # (light-blind cluster) from unassigned by checking t_0 != -1.
    p_conf_out = np.where(np.isnan(prompt_conf_f), CONF_UNAVAILABLE_F4,
                          prompt_conf_f).astype(np.float32)

    # Derive final-hit fields from the prompt-hit mapping.
    f_t0_i2 = np.full(n_final, T0_SENTINEL_I2, dtype=np.int16)
    f_cl_i2 = np.full(n_final, CLUSTER_SENTINEL_I2, dtype=np.int16)
    f_conf_out = np.full(n_final, CONF_UNAVAILABLE_F4, dtype=np.float32)
    if n_final:
        in_range = (final_to_prompt >= 0) & (final_to_prompt < n_prompt)
        f_t0_i2[in_range] = p_t0_i2[final_to_prompt[in_range]]
        f_cl_i2[in_range] = p_cl_i2[final_to_prompt[in_range]]
        f_conf_out[in_range] = p_conf_out[final_to_prompt[in_range]]

    # Read-modify-write the compound datasets.
    info = {
        "src_file": str(src_file),
        "n_shards": len(shards),
        "n_events": n_events,
        "n_prompt_hits": n_prompt,
        "n_prompt_assigned": int((p_t0_i2 != T0_SENTINEL_I2).sum()),
        "n_final_hits": n_final,
        "n_final_assigned": int((f_t0_i2 != T0_SENTINEL_I2).sum()) if n_final else 0,
        "t0_overflow_high": oh_high,
        "t0_overflow_low": oh_low,
        "t0_max_abs_ticks": oh_max,
        "cluster_id_overflow": cl_over,
    }
    with h5py.File(src_file, "r+") as h:
        # Prompt hits
        pdset = h[PROMPT_DSET]
        info["prompt_prewrite_nonzero"] = _warn_and_count_nonzero(pdset, PROMPT_DSET)
        pdata = pdset[:]
        for name, arr in (("t_0", p_t0_i2),
                          ("t_cluster_id", p_cl_i2),
                          ("t_confidence", p_conf_out)):
            if name in pdata.dtype.names:
                pdata[name] = arr
        pdset[:] = pdata
        # Final hits (only if the dataset exists AND has the fields)
        if n_final:
            fdset = h[FINAL_DSET]
            info["final_prewrite_nonzero"] = _warn_and_count_nonzero(fdset, FINAL_DSET)
            fdata = fdset[:]
            for name, arr in (("t_0", f_t0_i2),
                              ("t_cluster_id", f_cl_i2),
                              ("t_confidence", f_conf_out)):
                if name in fdata.dtype.names:
                    fdata[name] = arr
            fdset[:] = fdata
    if verbose:
        print(f"  {src_file.name}: shards={len(shards)} events={n_events}  "
              f"prompt {info['n_prompt_assigned']}/{n_prompt} "
              f"({100.0*info['n_prompt_assigned']/max(n_prompt,1):.2f}%)  "
              f"final {info['n_final_assigned']}/{n_final}"
              + (f"  t0-overflow(>i2)={oh_high+oh_low} max|t0|={oh_max}"
                 if (oh_high + oh_low) > 0 else ""),
              flush=True)
    return info


def group_shards_by_source(shards: list[dict], *,
                            explicit_src: Path | None) -> dict[str, list[dict]]:
    """Bucket shards by their source-file path.

    If --src-file is given, ALL shards are attributed to that path. Otherwise
    each shard's own `src_file` field (recorded by the pipeline) is used.
    """
    groups: dict[str, list[dict]] = {}
    for sh in shards:
        key = str(explicit_src) if explicit_src is not None else sh["src_file"]
        if not key:
            print(f"  SKIP shard {sh['path'].name}: no src_file recorded and no --src-file",
                  file=sys.stderr)
            continue
        groups.setdefault(key, []).append(sh)
    return groups


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    ap.add_argument("--dump-dir", required=True, type=Path,
                    help="Directory containing v1 pipeline NPZ shards.")
    ap.add_argument("--src-file", default=None, type=Path,
                    help="Force all shards to write into this HDF5. If omitted, "
                         "each shard's src_file field is used (grouping by source).")
    ap.add_argument("--summary-json", default=None, type=Path,
                    help="Optional JSON file to write per-source aggregation summary.")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    shard_paths = _gather_shards(args.dump_dir)
    if not shard_paths:
        print(f"ERROR: no NPZ shards under {args.dump_dir}", file=sys.stderr)
        return 1
    shards = [s for s in (_load_shard(p) for p in shard_paths) if s is not None]

    groups = group_shards_by_source(shards, explicit_src=args.src_file)
    if not groups:
        print("ERROR: no shards had a resolvable source file.", file=sys.stderr)
        return 1

    summaries = []
    for src_str, sh_list in groups.items():
        src = Path(src_str)
        if not src.exists():
            print(f"ERROR: source file missing: {src}", file=sys.stderr)
            summaries.append({"src_file": str(src), "status": "no_source_file"})
            continue
        try:
            info = aggregate_one_file(src, sh_list, verbose=not args.quiet)
            info["status"] = "ok"
            summaries.append(info)
        except Exception as exc:
            print(f"ERROR aggregating {src}: {exc}", file=sys.stderr)
            summaries.append({"src_file": str(src), "status": "error", "error": repr(exc)})

    if args.summary_json is not None:
        args.summary_json.parent.mkdir(parents=True, exist_ok=True)
        with open(args.summary_json, "w") as fj:
            json.dump({"aggregator": "aggregate_v1_to_hdf5", "results": summaries},
                      fj, indent=1, default=str)

    n_ok = sum(1 for s in summaries if s.get("status") == "ok")
    n_err = len(summaries) - n_ok
    if not args.quiet:
        print(f"aggregate_v1_to_hdf5: ok={n_ok} err={n_err}", flush=True)
    return 0 if n_err == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
