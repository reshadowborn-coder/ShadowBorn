#!/usr/bin/env python3
"""Acquire one approved Poly Haven PBR texture family for Shadowborn.

Downloads only the selected 2K PNG maps used by the Godot Mobile pipeline:
diffuse/albedo, OpenGL normal, and packed ARM (AO/Roughness/Metallic).

The Poly Haven assets are CC0. Access to their public API has separate terms;
see SOURCE.json and https://polyhaven.com/license before redistributing tools.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
import urllib.request

API_ROOT = "https://api.polyhaven.com"
DEFAULT_ASSET = "cobblestone_01"
DEFAULT_RESOLUTION = "2k"
USER_AGENT = "Shadowborn-Production-Asset-Pipeline/1.0"

MAP_TOKENS = {
    "diff": "_diff_",
    "nor_gl": "_nor_gl_",
    "arm": "_arm_",
}


def _get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def _walk_files(node):
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            yield node
        for value in node.values():
            yield from _walk_files(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk_files(value)


def _select_png(files: dict, asset: str, resolution: str, token: str) -> dict:
    needle = MAP_TOKENS[token]
    candidates = []
    for record in _walk_files(files):
        url = record["url"]
        lower = url.lower()
        if (
            f"/png/{resolution}/" in lower
            and f"/{asset}/" in lower
            and needle in lower
            and lower.endswith(".png")
        ):
            candidates.append(record)
    if len(candidates) != 1:
        raise RuntimeError(
            f"Expected exactly one {resolution} PNG {token} map for {asset}, "
            f"found {len(candidates)}"
        )
    return candidates[0]


def _download(record: dict, destination: pathlib.Path) -> None:
    request = urllib.request.Request(record["url"], headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()

    expected = record.get("md5")
    if expected:
        actual = hashlib.md5(data).hexdigest()
        if actual.lower() != str(expected).lower():
            raise RuntimeError(f"MD5 mismatch for {destination.name}: {actual} != {expected}")

    destination.write_bytes(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", default=DEFAULT_ASSET)
    parser.add_argument("--resolution", default=DEFAULT_RESOLUTION)
    parser.add_argument(
        "--output",
        default="assets/production/materials/cemetery_wet_cobble",
    )
    args = parser.parse_args()

    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=True)

    files = _get_json(f"{API_ROOT}/files/{args.asset}")
    selected = {
        key: _select_png(files, args.asset, args.resolution, key)
        for key in MAP_TOKENS
    }

    output_names = {
        "diff": f"{args.asset}_diff_{args.resolution}.png",
        "nor_gl": f"{args.asset}_nor_gl_{args.resolution}.png",
        "arm": f"{args.asset}_arm_{args.resolution}.png",
    }

    for key, record in selected.items():
        target = out / output_names[key]
        print(f"Downloading {key}: {record['url']} -> {target}")
        _download(record, target)

    provenance = {
        "asset": args.asset,
        "resolution": args.resolution,
        "provider": "Poly Haven",
        "asset_page": f"https://polyhaven.com/a/{args.asset}",
        "asset_license": "CC0",
        "license_url": "https://polyhaven.com/license",
        "api": f"{API_ROOT}/files/{args.asset}",
        "api_credit": "Powered by Poly Haven",
        "maps": {
            key: {
                "file": output_names[key],
                "source_url": selected[key]["url"],
                "md5": selected[key].get("md5"),
            }
            for key in selected
        },
    }
    (out / "SOURCE.json").write_text(
        json.dumps(provenance, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print("Acquisition complete. Review SOURCE.json before committing binary assets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
