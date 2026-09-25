from __future__ import annotations
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("validate_recipe", ROOT / "validate_recipe.py")
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
REGISTRY = VALIDATOR.load_json(ROOT / "registries" / "mvp_profile_registry_v0_1.json")
FIXTURES = sorted((ROOT / "recipes" / "mvp").glob("*.json"))

class CharacterRecipeV01Tests(unittest.TestCase):
    def test_all_three_mvp_recipes_validate(self):
        self.assertEqual(3, len(FIXTURES))
        for path in FIXTURES:
            with self.subTest(path=path.name):
                self.assertEqual([], VALIDATOR.validate_recipe(VALIDATOR.load_json(path), REGISTRY))

    def test_hash_is_deterministic_and_order_independent(self):
        recipe = VALIDATOR.load_json(FIXTURES[0])
        self.assertEqual(VALIDATOR.recipe_hash(recipe), VALIDATOR.recipe_hash(dict(reversed(list(recipe.items())))))

    def test_three_body_recipes_have_distinct_hashes(self):
        self.assertEqual(3, len({VALIDATOR.recipe_hash(VALIDATOR.load_json(path)) for path in FIXTURES}))

    def test_unknown_top_level_key_fails_closed(self):
        recipe = VALIDATOR.load_json(FIXTURES[0]); recipe["gameplay_attack"] = 999999
        self.assertTrue(any("unknown keys" in e for e in VALIDATOR.validate_recipe(recipe, REGISTRY)))

    def test_unknown_reference_fails_preflight(self):
        recipe = VALIDATOR.load_json(FIXTURES[0]); recipe["body_profile_id"] = "BODY_NOT_REGISTERED"
        self.assertTrue(any("body_profile_id: unresolved" in e for e in VALIDATOR.validate_recipe(recipe, REGISTRY)))

    def test_duplicate_weapon_ids_fail(self):
        recipe = VALIDATOR.load_json(FIXTURES[0]); recipe["weapon_module_ids"] = ["WPN_SWORD_1H", "WPN_SWORD_1H"]
        self.assertTrue(any("duplicate IDs" in e for e in VALIDATOR.validate_recipe(recipe, REGISTRY)))

    def test_mvp_weapon_contract_rejects_partial_loadout(self):
        recipe = VALIDATOR.load_json(FIXTURES[0]); recipe["weapon_module_ids"] = ["WPN_SWORD_1H"]
        self.assertTrue(any("MVP requires exactly" in e for e in VALIDATOR.validate_recipe(recipe, REGISTRY)))

    def test_invalid_recipe_id_and_seed_fail(self):
        recipe = VALIDATOR.load_json(FIXTURES[0]); recipe["recipe_id"] = "Bad Recipe ID"; recipe["seed"] = -1
        errors = VALIDATOR.validate_recipe(recipe, REGISTRY)
        self.assertTrue(any(e.startswith("recipe_id:") for e in errors))
        self.assertTrue(any(e.startswith("seed:") for e in errors))

if __name__ == "__main__":
    unittest.main()
