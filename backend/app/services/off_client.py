"""
Client for the Open Food Facts public API (https://openfoodfacts.org).
This is the real data source for barcode lookups - replaces the frontend's
MOCK_PRODUCT entirely. No API key required.
"""

import requests
from flask import current_app


class ProductNotFoundError(Exception):
    pass


def _nutriment(n: dict, key: str, unit: str = "g") -> str:
    val = n.get(f"{key}_100g")
    if val is None:
        return f"0{unit}"
    if key == "energy-kcal":
        return f"{val:g} kcal"
    return f"{val:g}{unit}"


def fetch_product_by_barcode(barcode: str) -> dict:
    """
    Look up a product by barcode via Open Food Facts.
    Raises ProductNotFoundError if the barcode is not in the database.
    Returns a normalized dict matching our Product schema.
    """
    base = current_app.config["OFF_API_BASE"]
    url = f"{base}/product/{barcode}.json"

    try:
        resp = requests.get(
            url,
            params={
                "fields": "code,product_name,brands,categories,image_front_url,"
                          "ingredients_text,nutriments"
            },
            timeout=10,
            headers={"User-Agent": "NutriCheck-App/1.0 (contact@nutricheck.app)"},
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        raise ProductNotFoundError(f"Could not reach product database: {exc}")

    data = resp.json()
    if data.get("status") != 1 or "product" not in data:
        raise ProductNotFoundError(f"No product found for barcode {barcode}")

    p = data["product"]
    n = p.get("nutriments", {})

    name = p.get("product_name") or "Unknown Product"
    if not p.get("product_name"):
        raise ProductNotFoundError(f"Product {barcode} has no usable name in database")

    return {
        "barcode": barcode,
        "name": name,
        "brand": p.get("brands", "") or "",
        "category": (p.get("categories", "") or "").split(",")[0].strip(),
        "image": p.get("image_front_url", "") or "",
        "ingredients_text": p.get("ingredients_text", "") or "",
        "nutrition": {
            "energy": _nutriment(n, "energy-kcal", ""),
            "fat": _nutriment(n, "fat"),
            "saturatedFat": _nutriment(n, "saturated-fat"),
            "carbs": _nutriment(n, "carbohydrates"),
            "sugars": _nutriment(n, "sugars"),
            "fiber": _nutriment(n, "fiber"),
            "protein": _nutriment(n, "proteins"),
            "salt": _nutriment(n, "salt"),
        },
    }


def search_products(query: str, page_size: int = 15) -> list:
    base = current_app.config["OFF_API_BASE"].replace("/api/v2", "")
    url = f"{base}/cgi/search.pl"
    try:
        resp = requests.get(
            url,
            params={
                "search_terms": query,
                "search_simple": 1,
                "action": "process",
                "json": 1,
                "page_size": page_size,
            },
            timeout=10,
            headers={"User-Agent": "NutriCheck-App/1.0 (contact@nutricheck.app)"},
        )
        resp.raise_for_status()
        data = resp.json()
    except (requests.RequestException, ValueError):
        return []

    results = []
    for p in data.get("products", []):
        if not p.get("product_name") or not p.get("code"):
            continue
        results.append({
            "barcode": p["code"],
            "name": p["product_name"],
            "brand": p.get("brands", "") or "",
            "image": p.get("image_front_url", "") or "",
        })
    return results
