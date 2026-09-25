#!/usr/bin/env python3
"""Validate Shadowborn CharacterRecipe v0.1 without third-party dependencies."""

from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

RECIPE_VERSION = "character_recipe_v0.1"
RECIPE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,63}$")
MAX_SEED = 2_147_483_647
REQUIRED_KEYS = {
    "recipe_version", "recipe_id", "seed", "skeleton_profile_id",
    "body_profile_id", "armor_recipe_id", "weapon_module_ids",
    "material_preset_ids", "animation_profile_id", "platform_target",
    "quality_target",
}
OPTIONAL_KEYS = {"face_profile_id_optional", "hair_id_optional", "notes"}
REFERENCE_FIELDS = {
    "skeleton_profile_id": "skeleton_profile_ids",
    "body_profile_id": "body_profile_ids",
    "armor_recipe_id": "armor_recipe_ids",
    "animation_profile_id": "animation_profile_ids",
    "platform_target": "platform_targets",
    "quality_target": "quality_targets",
}

def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

def canonical_recipe_bytes(recipe: dict[str, Any]) -> bytes:
    return json.dumps(recipe, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")

def recipe_hash(recipe: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_recipe_bytes(recipe)).hexdigest()

def _check_id_list(errors, recipe, field, registry, registry_field, *, min_items, max_items):
    value = recipe.get(field)
    if not isinstance(value, list):
        errors.append(f"{field}: expected array")
        return
    if not min_items <= len(value) <= max_items:
        errors.append(f"{field}: expected {min_items}..{max_items} items")
    if any(not isinstance(item, str) or not item for item in value):
        errors.append(f"{field}: every entry must be a non-empty string")
        return
    if len(value) != len(set(value)):
        errors.append(f"{field}: duplicate IDs are not allowed")
    allowed = set(registry.get(registry_field, []))
    unknown = sorted(set(value) - allowed)
    if unknown:
        errors.append(f"{field}: unknown IDs: {', '.join(unknown)}")

def validate_recipe(recipe: Any, registry: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(recipe, dict):
        return ["root: expected JSON object"]
    if not isinstance(registry, dict):
        return ["registry: expected JSON object"]
    keys = set(recipe)
    missing = sorted(REQUIRED_KEYS - keys)
    unknown = sorted(keys - REQUIRED_KEYS - OPTIONAL_KEYS)
    if missing:
        errors.append("root: missing required keys: " + ", ".join(missing))
    if unknown:
        errors.append("root: unknown keys: " + ", ".join(unknown))
    if recipe.get("recipe_version") != RECIPE_VERSION:
        errors.append(f"recipe_version: expected {RECIPE_VERSION!r}")
    recipe_id = recipe.get("recipe_id")
    if not isinstance(recipe_id, str) or RECIPE_ID_RE.fullmatch(recipe_id) is None:
        errors.append("recipe_id: expected immutable lowercase ID matching ^[a-z0-9][a-z0-9._-]{2,63}$")
    seed = recipe.get("seed")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= MAX_SEED:
        errors.append(f"seed: expected integer in range 0..{MAX_SEED}")
    for field, registry_field in REFERENCE_FIELDS.items():
        value = recipe.get(field)
        if not isinstance(value, str) or not value:
            errors.append(f"{field}: expected non-empty string")
            continue
        if value not in set(registry.get(registry_field, [])):
            errors.append(f"{field}: unresolved ID {value!r}")
    for optional_field, registry_field in (("face_profile_id_optional", "face_profile_ids"), ("hair_id_optional", "hair_ids")):
        if optional_field in recipe:
            value = recipe[optional_field]
            if not isinstance(value, str) or not value:
                errors.append(f"{optional_field}: expected non-empty string when present")
            elif value not in set(registry.get(registry_field, [])):
                errors.append(f"{optional_field}: unresolved ID {value!r}")
    notes = recipe.get("notes")
    if notes is not None and (not isinstance(notes, str) or len(notes) > 500):
        errors.append("notes: expected string with at most 500 characters")
    _check_id_list(errors, recipe, "weapon_module_ids", registry, "weapon_module_ids", min_items=1, max_items=4)
    _check_id_list(errors, recipe, "material_preset_ids", registry, "material_preset_ids", min_items=1, max_items=8)
    weapons = recipe.get("weapon_module_ids")
    required_weapons = registry.get("required_weapon_module_ids", [])
    if isinstance(weapons, list) and sorted(weapons) != sorted(required_weapons):
        errors.append("weapon_module_ids: MVP requires exactly " + ", ".join(required_weapons))
    body_id = recipe.get("body_profile_id")
    armor_id = recipe.get("armor_recipe_id")
    fit_class = registry.get("body_fit_classes", {}).get(body_id)
    armor = registry.get("armor_recipes", {}).get(armor_id)
    if isinstance(armor, dict) and fit_class not in armor.get("allowed_fit_classes", []):
        errors.append(f"compatibility: {armor_id!r} does not support body fit class {fit_class!r}")
    return errors

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recipes", nargs="+", type=Path)
    parser.add_argument("--registry", type=Path, default=Path(__file__).with_name("registries") / "mvp_profile_registry_v0_1.json")
    parser.add_argument("--print-hash", action="store_true")
    args = parser.parse_args(argv)
    try:
        registry = load_json(args.registry)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"registry error: {exc}", file=sys.stderr)
        return 2
    failed = False
    for path in args.recipes:
        try:
            recipe = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"{path}: parse error: {exc}", file=sys.stderr)
            failed = True
            continue
        errors = validate_recipe(recipe, registry)
        if errors:
            failed = True
            for error in errors:
                print(f"{path}: {error}", file=sys.stderr)
        else:
            suffix = f" sha256={recipe_hash(recipe)}" if args.print_hash else ""
            print(f"{path}: OK{suffix}")
    return 1 if failed else 0

if __name__ == "__main__":
    raise SystemExit(main())
