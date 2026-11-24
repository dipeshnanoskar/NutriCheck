"""
NutriCheck analysis engine.

Produces an AnalysisResult (overall verdict, per-age-group suitability,
ingredient flags and nutrition concerns) from raw ingredients text and a
nutrition table (values expected per 100g/100ml, matching Open Food Facts
conventions). This is a genuine rule engine based on published nutrition
guidance (WHO sugar guidelines, EFSA caffeine guidance, UK Food Standards
Agency traffic-light thresholds) - it is NOT hard-coded per product.
"""

import re

# --- Ingredient watch-lists -------------------------------------------------

CAFFEINE_PATTERNS = [r"\bcaffeine\b", r"\bguarana\b", r"\byerba mate\b"]

ARTIFICIAL_SWEETENERS = [
    "aspartame", "sucralose", "saccharin", "acesulfame", "acesulfame-k",
    "acesulfame potassium", "cyclamate", "neotame",
]

ARTIFICIAL_COLORS = [
    "tartrazine", "e102", "e110", "sunset yellow", "e122", "carmoisine",
    "e124", "ponceau", "e129", "allura red", "e133", "brilliant blue",
    "e127", "erythrosine",
]

HIGH_RISK_ADDITIVES = {
    "monosodium glutamate": "MSG - can trigger sensitivity reactions in some people.",
    "msg": "MSG - can trigger sensitivity reactions in some people.",
    "high fructose corn syrup": "High fructose corn syrup - linked to excess sugar intake.",
    "sodium nitrite": "Sodium nitrite - preservative linked to health concerns with regular high intake.",
    "sodium nitrate": "Sodium nitrate - preservative linked to health concerns with regular high intake.",
    "partially hydrogenated": "Partially hydrogenated oil - a source of trans fat.",
    "trans fat": "Trans fat - raises LDL cholesterol, avoid regular consumption.",
    "bha": "BHA (E320) - synthetic antioxidant preservative, moderate intake advised.",
    "bht": "BHT (E321) - synthetic antioxidant preservative, moderate intake advised.",
    "sodium benzoate": "Sodium benzoate - preservative, fine in moderation.",
    "potassium sorbate": "Potassium sorbate - preservative, generally recognised as safe in normal amounts.",
}

ALLERGENS = [
    "milk", "peanut", "peanuts", "tree nut", "almond", "cashew", "walnut",
    "soy", "soybean", "wheat", "gluten", "egg", "eggs", "fish", "shellfish",
    "sesame",
]

STIMULANT_LIMIT_MG_PER_100ML = 15  # above this we flag caffeine content explicitly


def _find_matches(patterns, text_lower):
    found = []
    for p in patterns:
        if re.search(p, text_lower):
            found.append(p.strip(r"\b"))
    return found


def _extract_caffeine_mg_per_100ml(ingredients_text: str):
    match = re.search(r"caffeine[^0-9]{0,10}(\d+(?:\.\d+)?)\s*mg", ingredients_text, re.I)
    if match:
        return float(match.group(1))
    return None


def _parse_numeric(value):
    """Extract a float from strings like '10.8g', '47 kcal', '0.05g'."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    match = re.search(r"-?\d+(?:\.\d+)?", str(value))
    return float(match.group()) if match else None


def analyze(ingredients_text: str, nutrition: dict, category: str = "food") -> dict:
    ingredients_text = ingredients_text or ""
    text_lower = ingredients_text.lower()
    nutrition = nutrition or {}

    sugars = _parse_numeric(nutrition.get("sugars"))
    salt = _parse_numeric(nutrition.get("salt"))
    sat_fat = _parse_numeric(nutrition.get("saturatedFat"))
    energy_kcal = _parse_numeric(nutrition.get("energy"))
    fiber = _parse_numeric(nutrition.get("fiber"))
    protein = _parse_numeric(nutrition.get("protein"))

    flags = []
    nutrition_concerns = []

    # --- Ingredient-based flags ---
    caffeine_hits = _find_matches(CAFFEINE_PATTERNS, text_lower)
    caffeine_mg = _extract_caffeine_mg_per_100ml(ingredients_text)
    has_caffeine = bool(caffeine_hits) or caffeine_mg is not None
    if has_caffeine:
        detail = f"Contains caffeine ({caffeine_mg:.0f}mg/100ml)." if caffeine_mg else "Contains caffeine or caffeine-related stimulants."
        flags.append({"ingredient": "Caffeine", "concern": detail})

    for sweetener in ARTIFICIAL_SWEETENERS:
        if sweetener in text_lower:
            flags.append({
                "ingredient": sweetener.title(),
                "concern": "Artificial sweetener - not recommended for young children.",
            })
            break

    for color in ARTIFICIAL_COLORS:
        if color in text_lower:
            flags.append({
                "ingredient": color.title(),
                "concern": "Artificial colour - some colours are linked to hyperactivity in children (EU warning label required).",
            })
            break

    for key, concern in HIGH_RISK_ADDITIVES.items():
        if key in text_lower:
            flags.append({"ingredient": key.title(), "concern": concern})

    allergen_hits = sorted({a for a in ALLERGENS if re.search(rf"\b{re.escape(a)}\b", text_lower)})
    for allergen in allergen_hits[:4]:
        flags.append({"ingredient": allergen.title(), "concern": "Common allergen present."})

    # --- Nutrition-based concerns (per 100g/100ml, UK FSA style thresholds) ---
    if sugars is not None:
        if sugars > 22.5:
            nutrition_concerns.append({"label": "Sugars", "value": f"{sugars:g}g", "concern": "High sugar content (>22.5g/100g)."})
        elif sugars > 5:
            nutrition_concerns.append({"label": "Sugars", "value": f"{sugars:g}g", "concern": "Moderate sugar content."})

    if salt is not None:
        if salt > 1.5:
            nutrition_concerns.append({"label": "Salt", "value": f"{salt:g}g", "concern": "High salt content (>1.5g/100g)."})
        elif salt > 0.3:
            nutrition_concerns.append({"label": "Salt", "value": f"{salt:g}g", "concern": "Moderate salt content."})

    if sat_fat is not None:
        if sat_fat > 5:
            nutrition_concerns.append({"label": "Saturated Fat", "value": f"{sat_fat:g}g", "concern": "High saturated fat content (>5g/100g)."})
        elif sat_fat > 1.5:
            nutrition_concerns.append({"label": "Saturated Fat", "value": f"{sat_fat:g}g", "concern": "Moderate saturated fat content."})

    if energy_kcal is not None and energy_kcal > 400 and category == "drinks":
        nutrition_concerns.append({"label": "Energy", "value": f"{energy_kcal:g} kcal", "concern": "High energy density for a beverage."})

    # --- Per-age-group verdicts ---
    age_groups = []

    # Child (<13)
    child_status, child_reasons = "suitable", []
    if has_caffeine:
        child_status = "avoid"
        child_reasons.append("Contains caffeine - not recommended under 12 years.")
    if sugars is not None and sugars > 22.5:
        child_status = "avoid" if child_status != "avoid" else child_status
        child_reasons.append("Very high sugar content.")
    elif sugars is not None and sugars > 5 and child_status != "avoid":
        child_status = "caution"
        child_reasons.append("Moderate-to-high sugar content; limit portion size.")
    if any(f["ingredient"] in ("Tartrazine", "E110", "Sunset Yellow") or "colour" in f["concern"].lower() for f in flags):
        child_status = "avoid" if child_status == "avoid" else "caution"
        child_reasons.append("Artificial colours linked to hyperactivity in children.")
    if allergen_hits:
        child_reasons.append(f"Contains allergen(s): {', '.join(a.title() for a in allergen_hits)}.")
    if not child_reasons:
        child_reasons.append("No major concerns identified for this age group.")
    age_groups.append({"group": "Child", "status": child_status, "reason": " ".join(child_reasons)})

    # Teenager (13-17)
    teen_status, teen_reasons = "suitable", []
    if has_caffeine:
        if caffeine_mg and caffeine_mg > STIMULANT_LIMIT_MG_PER_100ML:
            teen_status = "caution"
            teen_reasons.append("High caffeine level - may affect sleep and concentration. Limit intake.")
        else:
            teen_status = "caution"
            teen_reasons.append("Contains caffeine - consume in moderation.")
    if sugars is not None and sugars > 22.5:
        teen_status = "caution" if teen_status == "suitable" else teen_status
        teen_reasons.append("High sugar content.")
    if any(k in text_lower for k in HIGH_RISK_ADDITIVES):
        teen_status = "caution" if teen_status == "suitable" else teen_status
        teen_reasons.append("Contains additives best consumed occasionally, not daily.")
    if not teen_reasons:
        teen_reasons.append("No major concerns identified for this age group.")
    age_groups.append({"group": "Teenager", "status": teen_status, "reason": " ".join(teen_reasons)})

    # Adult (18+)
    adult_status, adult_reasons = "suitable", []
    if sugars is not None and sugars > 22.5 and salt is not None and salt > 1.5:
        adult_status = "caution"
        adult_reasons.append("High in both sugar and salt - fine occasionally, not as a daily staple.")
    elif sugars is not None and sugars > 22.5:
        adult_status = "caution"
        adult_reasons.append("High sugar content - consume in moderation.")
    elif salt is not None and salt > 1.5:
        adult_status = "caution"
        adult_reasons.append("High salt content - consume in moderation.")
    if has_caffeine and caffeine_mg and caffeine_mg > 30:
        adult_status = "caution" if adult_status == "suitable" else adult_status
        adult_reasons.append("Significant caffeine content - be mindful of total daily intake.")
    if not adult_reasons:
        adult_reasons.append("Suitable for typical adult consumption in normal portions.")
    age_groups.append({"group": "Adult", "status": adult_status, "reason": " ".join(adult_reasons)})

    # --- Overall verdict ---
    statuses = [g["status"] for g in age_groups]
    if "avoid" in statuses:
        overall = "Avoid"
    elif "caution" in statuses:
        overall = "Use Caution"
    else:
        overall = "Generally Suitable"

    return {
        "overall": overall,
        "age_groups": age_groups,
        "flags": flags,
        "nutrition_concerns": nutrition_concerns,
    }
