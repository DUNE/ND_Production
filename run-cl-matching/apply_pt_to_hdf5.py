#!/usr/bin/env python3
"""Apply a `.pt` built by aggregate_v1_to_pt.py into a FLOW HDF5 file in-place.

Writes t_0 / t_cluster_id / t_confidence into
  charge/calib_prompt_hits/data   (size = pt["n_calib_prompt_hits"])
  charge/calib_final_hits/data    (size = pt["n_calib_final_hits"])

Every run of the ND CL matching wrapper ends by calling this script -- whether
the .pt was freshly built from a pipeline run or loaded from an existing cache.
The .pt is the ONE source of truth; this script is deterministic.

WARN + overwrite policy: if any of the target fields has non-default entries
before the write, this script emits a one-line warning with the count and
overwrites regardless (the fields are reserved for QL matching to fill).

Refuses to write if the .pt's array lengths don't match the target HDF5's
dataset sizes -- that's the safety net against the wrong .pt being applied to
the wrong flow file.
"""

from __future__ import annotations
import argparse, json, sys
from pathlib import Path

import numpy as np
import h5py
import torch


PROMPT_DSET = "charge/calib_prompt_hits/data"
FINAL_DSET = "charge/calib_final_hits/data"
FIELDS = ("t_0", "t_cluster_id", "t_confidence")


def _as_numpy(obj) -> np.ndarray:
    """Accept torch tensor OR numpy array in the .pt."""
    if isinstance(obj, torch.Tensor):
        return obj.detach().cpu().numpy()
    return np.asarray(obj)


def _count_nondefault(arr: np.ndarray) -> int:
    if arr.dtype.kind == "f":
        return int(np.count_nonzero(np.nan_to_num(arr, nan=0.0)))
    return int((arr != 0).sum())


def apply_one(pt_path: Path, hdf5_path: Path, *, verbose: bool = True) -> dict:
    pt = torch.load(pt_path, map_location="cpu", weights_only=False)
    info = {
        "pt_path": str(pt_path),
        "hdf5_path": str(hdf5_path),
        "version": pt.get("version"),
        "src_basename_expected": pt.get("src_basename"),
        "prompt": {"wrote_fields": [], "prewrite_nondefault": {}, "size_mismatch": None},
        "final":  {"wrote_fields": [], "prewrite_nondefault": {}, "size_mismatch": None},
    }

    with h5py.File(hdf5_path, "r+") as h:
        for key, dset_path in (("calib_prompt_hits", PROMPT_DSET),
                                ("calib_final_hits", FINAL_DSET)):
            info_key = "prompt" if key == "calib_prompt_hits" else "final"
            if dset_path not in h:
                if verbose:
                    print(f"  {dset_path}: MISSING; skipping ({key})", flush=True)
                continue
            if key not in pt:
                if verbose:
                    print(f"  {dset_path}: pt has no '{key}'; skipping", flush=True)
                continue

            dset = h[dset_path]
            n_hdf5 = int(dset.shape[0])
            fields_in_pt = pt[key]
            # Size check via ANY populated field (they should all be same length).
            sample = next(iter(fields_in_pt.values()))
            n_pt = int(_as_numpy(sample).shape[0])
            if n_pt != n_hdf5:
                info[info_key]["size_mismatch"] = {"pt": n_pt, "hdf5": n_hdf5}
                raise RuntimeError(
                    f"{dset_path}: pt array length {n_pt} != HDF5 dataset length {n_hdf5}"
                    f"  (pt was built for '{pt.get('src_basename')}' at "
                    f"'{pt.get('input_file')}')"
                )

            data = dset[:]
            for field in FIELDS:
                if field not in fields_in_pt:
                    continue
                if field not in data.dtype.names:
                    if verbose:
                        print(f"  {dset_path}[{field}]: dtype lacks field; skipping",
                              flush=True)
                    continue
                new_val = _as_numpy(fields_in_pt[field])
                nz = _count_nondefault(data[field])
                info[info_key]["prewrite_nondefault"][field] = nz
                if nz > 0 and verbose:
                    print(f"  WARN: {dset_path}[{field}] had {nz} non-default entries "
                          "before v1 PT-fill; overwriting all values.", flush=True)
                # Coerce to the HDF5 field's dtype in case pt stored a wider type.
                target_dtype = data.dtype[field]
                data[field] = new_val.astype(target_dtype, copy=False)
                info[info_key]["wrote_fields"].append(field)
            dset[:] = data

    if verbose:
        p_a = int(np.asarray(fields_in_pt["t_0"]).__ne__(-1).sum()) if False else pt.get(
            "n_prompt_assigned", "?")
        f_a = pt.get("n_final_assigned", "?")
        print(f"  applied {pt_path.name} -> {hdf5_path.name}  "
              f"prompt={p_a}/{pt.get('n_calib_prompt_hits','?')}  "
              f"final={f_a}/{pt.get('n_calib_final_hits','?')}", flush=True)
    return info


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    ap.add_argument("--pt", required=True, type=Path,
                    help="Path to the .pt built by aggregate_v1_to_pt.py.")
    ap.add_argument("--hdf5", required=True, type=Path,
                    help="Target FLOW HDF5 file (modified in-place).")
    ap.add_argument("--summary-json", default=None, type=Path)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not args.pt.is_file():
        print(f"ERROR: pt not found: {args.pt}", file=sys.stderr)
        return 2
    if not args.hdf5.is_file():
        print(f"ERROR: HDF5 not found: {args.hdf5}", file=sys.stderr)
        return 2

    try:
        info = apply_one(args.pt, args.hdf5, verbose=not args.quiet)
    except Exception as exc:
        print(f"ERROR applying pt: {exc}", file=sys.stderr)
        return 1
    info["status"] = "ok"
    if args.summary_json is not None:
        args.summary_json.parent.mkdir(parents=True, exist_ok=True)
        with open(args.summary_json, "w") as fj:
            json.dump({"applier": "apply_pt_to_hdf5", "result": info},
                      fj, indent=1, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
