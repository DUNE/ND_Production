#!/usr/bin/env python3
"""Aggregate CLMatching v1 NPZ shards into a `.pt` that carries the exact
per-hit values that go into the FLOW HDF5.

The `.pt` is the AUTHORITATIVE source of the ND CL-matching result. The
production workflow is:

  1. Check if the .pt exists at the canonical output location. If yes: skip
     the pipeline entirely.
  2. If no: run the v1 pipeline to produce NPZ shards, then this script
     collapses them into the .pt. The .pt is the ONE thing every run must
     leave on disk.
  3. Fill the flow HDF5 by loading the .pt and writing its arrays into the
     `charge/calib_prompt_hits` and `charge/calib_final_hits` compound
     datasets (t_0, t_cluster_id, t_confidence). That fill step lives in
     apply_pt_to_hdf5.py.

Schema of the .pt (torch.save of a dict):

  {
    "version":                  "clmatchND_v1",
    "input_file":               "<abs path to source FLOW.hdf5>",
    "src_basename":             "<basename of source>",
    "n_calib_prompt_hits":      int,
    "n_calib_final_hits":       int,
    "n_prompt_assigned":        int,   # count of prompt hits with t_0 != UNASSIGNED
    "n_final_assigned":         int,
    "n_events":                 int,   # number of shards aggregated
    "t0_units":                 "ns",  # units of the t_0 field (nanoseconds)
    "ticks_per_ns":             16,    # LArPix clock: 1 tick = 16 ns
    "cluster_id_overflow":      int,   # count of labels outside int16 range
    "unassigned_sentinel":      -10000,# uniform sentinel across all three fields

    # Per-prompt-hit arrays, size = n_calib_prompt_hits, matching the ndlar_flow
    # HDF5 field dtypes. Uniform sentinel -10000 for unassigned / unavailable
    # (unphysical for all three fields).
    #   t_0            float32 nanoseconds (v1's ts_final ticks * 16.0);
    #                  -10000.0 = unassigned.
    #   t_cluster_id   int16    -10000 = unassigned.
    #   t_confidence   float32  -10000.0 = unavailable.
    "calib_prompt_hits": {
      "t_0":            torch.float32 tensor,
      "t_cluster_id":   torch.int16 tensor,
      "t_confidence":   torch.float32 tensor,
    },

    # Per-final-hit arrays, size = n_calib_final_hits. Derived by gathering
    # from the prompt arrays via the col-0 of
    # charge/calib_prompt_hits/ref/charge/calib_final_hits/ref
    "calib_final_hits": {
      "t_0":            torch.float32 tensor,
      "t_cluster_id":   torch.int16 tensor,
      "t_confidence":   torch.float32 tensor,
    },
  }
"""

from __future__ import annotations
import argparse, json, os, sys
from pathlib import Path
from typing import Any

import numpy as np
import h5py
import torch


SCHEMA_VERSION = "clmatchND_v1"
# Uniform sentinel -10000 across all three writeback fields. Unphysical for
# all of them: t_0 (ns) is naturally non-negative in real physics; t_cluster_id
# is a non-negative cluster label; t_confidence lives in [0, 1]. -10000 is
# easy to check for and distinguishes "CL matching ran and didn't assign this
# hit" from the pre-CL-matching HDF5 default of 0.
UNASSIGNED = -10000
T0_SENTINEL_F4 = float(UNASSIGNED)          # float32 ns
CLUSTER_SENTINEL_I2 = int(UNASSIGNED)       # int16 (well within -32768..32767)
CONF_UNAVAILABLE_F4 = float(UNASSIGNED)     # float32
NS_PER_TICK = 16.0                          # LArPix clock: 1 tick = 16 ns

PROMPT_DSET = "charge/calib_prompt_hits/data"
FINAL_DSET = "charge/calib_final_hits/data"
FINAL_TO_PROMPT_REF = "charge/calib_prompt_hits/ref/charge/calib_final_hits/ref"


def _ticks_to_ns_f4(arr_ticks: np.ndarray) -> np.ndarray:
    """Convert per-hit ts_final (ticks) into per-hit t_0 (ns, float32).

    Non-finite (NaN/inf) and unassigned entries land at the -10000 sentinel
    (unphysical for real drift ns). We do NOT clip -- t_0 is now stored as
    float32 nanoseconds, which comfortably covers the full drift window.
    """
    finite = np.isfinite(arr_ticks) & (arr_ticks >= 0)
    out = np.full(arr_ticks.shape, T0_SENTINEL_F4, dtype=np.float32)
    out[finite] = (arr_ticks[finite] * NS_PER_TICK).astype(np.float32)
    return out


def _clip_int_to_i2(arr: np.ndarray) -> tuple[np.ndarray, int]:
    lo, hi = np.iinfo(np.int16).min, np.iinfo(np.int16).max
    n_over = int(((arr > hi) | (arr < lo)).sum())
    return np.clip(arr, lo, hi).astype(np.int16), n_over


def _calib_final_to_prompt_indices(h: h5py.File) -> np.ndarray:
    final = h[FINAL_DSET]
    n_final = int(final.shape[0])
    if FINAL_TO_PROMPT_REF in h and int(h[FINAL_TO_PROMPT_REF].shape[0]) == n_final:
        return np.asarray(h[FINAL_TO_PROMPT_REF][:, 0], dtype=np.int64)
    if "id" in final.dtype.names:
        return np.asarray(final["id"], dtype=np.int64)
    raise RuntimeError(
        f"cannot derive final->prompt mapping: neither {FINAL_TO_PROMPT_REF} nor 'id'."
    )


def _gather_shards(shard_dir: Path) -> list[Path]:
    return sorted(p for p in shard_dir.glob("*_ev*.npz") if "_ev" in p.stem)


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
    return {
        "path": npz_path,
        "src_file": str(d.get("src_file", "")) if "src_file" in d.files else "",
        "hit_refs": np.asarray(d["hit_refs"], dtype=np.int64),
        "ts_final": np.asarray(d["ts_final"], dtype=np.float64),
        "labels": np.asarray(d["labels"], dtype=np.int64),
        "hit_conf93": (np.asarray(d["hit_conf93"], dtype=np.float32)
                       if "hit_conf93" in d.files else None),
    }


def build_pt_for_file(src_file: Path, shards: list[dict], *, verbose: bool = True) -> dict:
    """Scatter shards' hit-level arrays into per-file arrays, package as a dict
    ready for torch.save."""
    with h5py.File(src_file, "r") as h:
        n_prompt = int(h[PROMPT_DSET].shape[0])
        n_final = int(h[FINAL_DSET].shape[0]) if FINAL_DSET in h else 0
        final_to_prompt = (_calib_final_to_prompt_indices(h)
                           if n_final else np.zeros(0, np.int64))

    prompt_t0_f = np.full(n_prompt, np.nan, dtype=np.float64)
    prompt_lab_i = np.full(n_prompt, CLUSTER_SENTINEL_I2, dtype=np.int64)
    prompt_conf_f = np.full(n_prompt, np.nan, dtype=np.float32)

    n_events, n_assigned = 0, 0
    for sh in shards:
        refs, ts, lb, cf = sh["hit_refs"], sh["ts_final"], sh["labels"], sh["hit_conf93"]
        if refs.size != ts.size or refs.size != lb.size:
            print(f"  SKIP {sh['path'].name}: shape mismatch", file=sys.stderr)
            continue
        valid = (refs >= 0) & (refs < n_prompt)
        good = valid & np.isfinite(ts) & (ts >= 0)
        prompt_t0_f[refs[good]] = ts[good]
        prompt_lab_i[refs[valid]] = lb[valid]
        if cf is not None and cf.size == refs.size:
            prompt_conf_f[refs[valid]] = cf[valid]
        n_events += 1
        n_assigned += int(good.sum())

    p_t0_ns = _ticks_to_ns_f4(prompt_t0_f)
    p_cl_i2, cl_over = _clip_int_to_i2(prompt_lab_i)
    p_conf_out = np.where(np.isnan(prompt_conf_f),
                          CONF_UNAVAILABLE_F4, prompt_conf_f).astype(np.float32)

    f_t0_ns = np.full(n_final, T0_SENTINEL_F4, dtype=np.float32)
    f_cl_i2 = np.full(n_final, CLUSTER_SENTINEL_I2, dtype=np.int16)
    f_conf_out = np.full(n_final, CONF_UNAVAILABLE_F4, dtype=np.float32)
    if n_final:
        in_range = (final_to_prompt >= 0) & (final_to_prompt < n_prompt)
        f_t0_ns[in_range] = p_t0_ns[final_to_prompt[in_range]]
        f_cl_i2[in_range] = p_cl_i2[final_to_prompt[in_range]]
        f_conf_out[in_range] = p_conf_out[final_to_prompt[in_range]]

    n_p_assigned = int((p_t0_ns != T0_SENTINEL_F4).sum())
    n_f_assigned = int((f_t0_ns != T0_SENTINEL_F4).sum()) if n_final else 0

    out = {
        "version": SCHEMA_VERSION,
        "input_file": str(Path(src_file).resolve()),
        "src_basename": Path(src_file).name,
        "n_calib_prompt_hits": n_prompt,
        "n_calib_final_hits": n_final,
        "n_prompt_assigned": n_p_assigned,
        "n_final_assigned": n_f_assigned,
        "n_events": n_events,
        "t0_units": "ns",
        "ticks_per_ns": NS_PER_TICK,
        "unassigned_sentinel": UNASSIGNED,
        "cluster_id_overflow": cl_over,
        "calib_prompt_hits": {
            "t_0": torch.from_numpy(p_t0_ns),
            "t_cluster_id": torch.from_numpy(p_cl_i2),
            "t_confidence": torch.from_numpy(p_conf_out),
        },
        "calib_final_hits": {
            "t_0": torch.from_numpy(f_t0_ns),
            "t_cluster_id": torch.from_numpy(f_cl_i2),
            "t_confidence": torch.from_numpy(f_conf_out),
        },
    }
    if verbose:
        print(f"  {out['src_basename']}: shards={len(shards)} events={n_events}  "
              f"prompt {n_p_assigned}/{n_prompt} "
              f"({100.0*n_p_assigned/max(n_prompt,1):.2f}%)  "
              f"final {n_f_assigned}/{n_final}",
              flush=True)
    return out


def group_shards_by_source(shards: list[dict], *,
                            explicit_src: Path | None) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for sh in shards:
        key = str(explicit_src) if explicit_src is not None else sh["src_file"]
        if not key:
            print(f"  SKIP {sh['path'].name}: no src_file recorded", file=sys.stderr)
            continue
        groups.setdefault(key, []).append(sh)
    return groups


def resolve_out_path(src_file: Path, args) -> Path:
    """Where to save the .pt. Explicit --out wins; otherwise --out-dir + naming."""
    if args.out is not None:
        return args.out
    stem = src_file.name
    if stem.endswith(".hdf5"):
        stem = stem[:-len(".hdf5")]
    return args.out_dir / f"{stem}.qlmatchND_v1.pt"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    ap.add_argument("--dump-dir", required=True, type=Path,
                    help="Directory containing v1 pipeline NPZ shards.")
    ap.add_argument("--src-file", default=None, type=Path,
                    help="Force all shards to attribute to this source HDF5. "
                         "If omitted, each shard's own src_file is used.")
    ap.add_argument("--out", default=None, type=Path,
                    help="Explicit output .pt path (single-source mode only).")
    ap.add_argument("--out-dir", default=None, type=Path,
                    help="Directory to write per-source .pt files into.")
    ap.add_argument("--summary-json", default=None, type=Path)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if args.out is None and args.out_dir is None:
        print("ERROR: pass one of --out (single source) or --out-dir (per-source).",
              file=sys.stderr)
        return 2
    if args.out is not None and args.src_file is None:
        # Enforce that --out is used only when the destination file is unambiguous.
        # We accept it if a single source is found downstream.
        pass

    shard_paths = _gather_shards(args.dump_dir)
    if not shard_paths:
        print(f"ERROR: no NPZ shards under {args.dump_dir}", file=sys.stderr)
        return 1
    shards = [s for s in (_load_shard(p) for p in shard_paths) if s is not None]

    groups = group_shards_by_source(shards, explicit_src=args.src_file)
    if not groups:
        print("ERROR: no shards had a resolvable source file.", file=sys.stderr)
        return 1
    if args.out is not None and len(groups) != 1:
        print(f"ERROR: --out requires a single source file; found {len(groups)}.",
              file=sys.stderr)
        return 2

    summaries = []
    for src_str, sh_list in groups.items():
        src = Path(src_str)
        if not src.exists():
            print(f"ERROR: source file missing: {src}", file=sys.stderr)
            summaries.append({"input_file": str(src), "status": "no_source_file"})
            continue
        out_path = resolve_out_path(src, args)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            pt = build_pt_for_file(src, sh_list, verbose=not args.quiet)
            torch.save(pt, out_path)
            summaries.append({
                "input_file": pt["input_file"],
                "out_path": str(out_path),
                "n_calib_prompt_hits": pt["n_calib_prompt_hits"],
                "n_prompt_assigned": pt["n_prompt_assigned"],
                "n_calib_final_hits": pt["n_calib_final_hits"],
                "n_final_assigned": pt["n_final_assigned"],
                "status": "ok",
            })
        except Exception as exc:
            print(f"ERROR building .pt for {src}: {exc}", file=sys.stderr)
            summaries.append({"input_file": str(src),
                              "status": "error", "error": repr(exc)})

    if args.summary_json is not None:
        args.summary_json.parent.mkdir(parents=True, exist_ok=True)
        with open(args.summary_json, "w") as fj:
            json.dump({"aggregator": "aggregate_v1_to_pt", "results": summaries},
                      fj, indent=1, default=str)

    n_ok = sum(1 for s in summaries if s.get("status") == "ok")
    n_err = len(summaries) - n_ok
    if not args.quiet:
        print(f"aggregate_v1_to_pt: ok={n_ok} err={n_err}", flush=True)
    return 0 if n_err == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
