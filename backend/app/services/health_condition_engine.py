"""
Health-condition rule engine.

Pure product-warning logic - never diagnoses the user. Reads from the
new reference collections (health_conditions, ingredient_risk_rules,
nutrition_risk_rules, ingredients, ingredient_aliases). If none of
these collections have data yet, this returns an empty list and the
rest of the app keeps working exactly as before.
"""

import re
from app.models.health import (
    HealthCondition, Ingredient, IngredientAlias,
    IngredientRiskRule, NutritionRiskRule,
)

SEVERITY_RANK = {"Safe": 0, "Caution": 1, "Limit": 2, "Avoid": 3}


def _normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", text.lower()).strip()


def _find_matching_ingredient_ids(ingredients_text: str):
    """Best-effort substring match of ingredient/alias normalized names
    against the raw ingredients text. Safe no-op if no ingredients are
    configured yet."""
    if not ingredients_text:
        return set()
    haystack = _normalize(ingredients_text)
    matched = set()

    try:
        for ing in Ingredient.objects(active=True):
            needle = _normalize(ing.normalized_name or ing.ingredient_name)
            if needle and needle in haystack:
                matched.add(ing.id)

        for alias in IngredientAlias.objects():
            needle = _normalize(alias.normalized_alias or alias.alias_name)
            if needle and needle in haystack:
                matched.add(alias.ingredient.id)
    except Exception:
        # Collections not yet seeded / reachable - fail safe, no warnings.
        return set()

    return matched


def _parse_numeric(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    m = re.search(r"-?\d+(?:\.\d+)?", str(value))
    return float(m.group()) if m else None


def _worse(a: str, b: str) -> str:
    return a if SEVERITY_RANK.get(a, 0) >= SEVERITY_RANK.get(b, 0) else b


def evaluate_health_conditions(ingredients_text: str, nutrition: dict, age_group: str | None = None) -> list:
    """
    Returns a list of dicts:
      {"condition_name", "severity", "reason", "recommendation"}
    One entry per health condition that has at least one matching rule.
    Returns [] if no rules are configured - never raises to the caller.
    """
    nutrition = nutrition or {}
    warnings_by_condition = {}  # condition_id -> {severity, reasons:set, recommendation}

    try:
        matched_ingredient_ids = _find_matching_ingredient_ids(ingredients_text)

        # --- Ingredient-based rules ---
        if matched_ingredient_ids:
            rules = IngredientRiskRule.objects(
                ingredient__in=list(matched_ingredient_ids), active=True
            )
            for rule in rules:
                if age_group and rule.age_group_name and rule.age_group_name != age_group:
                    continue
                if rule.condition is None:
                    continue  # broad/non-condition rules aren't shown as health-condition warnings
                cid = str(rule.condition.id)
                entry = warnings_by_condition.setdefault(cid, {
                    "condition": rule.condition,
                    "severity": "Safe",
                    "reasons": [],
                    "recommendation": "",
                })
                entry["severity"] = _worse(entry["severity"], rule.severity)
                if rule.reason:
                    entry["reasons"].append(rule.reason)
                if rule.recommendation:
                    entry["recommendation"] = rule.recommendation

        # --- Nutrition-based rules ---
        nutrient_rules = NutritionRiskRule.objects(active=True)
        for rule in nutrient_rules:
            if rule.applicable_condition is None:
                continue
            value = _parse_numeric(nutrition.get(rule.nutrient_name))
            if value is None:
                continue
            triggered = False
            if rule.minimum_value is not None and value >= rule.minimum_value:
                triggered = True
            if rule.maximum_value is not None and value <= rule.maximum_value and rule.minimum_value is None:
                triggered = True
            if not triggered:
                continue
            cid = str(rule.applicable_condition.id)
            entry = warnings_by_condition.setdefault(cid, {
                "condition": rule.applicable_condition,
                "severity": "Safe",
                "reasons": [],
                "recommendation": "",
            })
            entry["severity"] = _worse(entry["severity"], rule.severity)
            if rule.description:
                entry["reasons"].append(rule.description)
            if rule.recommendation:
                entry["recommendation"] = rule.recommendation

    except Exception:
        # Any unexpected issue (e.g. collections not migrated yet) -
        # degrade gracefully instead of breaking product analysis.
        return []

    results = []
    for entry in warnings_by_condition.values():
        if entry["severity"] == "Safe":
            continue
        results.append({
            "condition_name": entry["condition"].condition_name,
            "severity": entry["severity"],
            "reason": " ".join(entry["reasons"]) or "Based on this product's ingredients or nutrition profile.",
            "recommendation": entry["recommendation"] or
                f"People with {entry['condition'].condition_name.lower()} should check this product carefully.",
        })
    return results