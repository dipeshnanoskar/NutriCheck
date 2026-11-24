from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.history import ScanHistory
from app.models.health import AnalysisResult, HealthConditionWarning, HealthCondition
from app.services.nutrition_analyzer import analyze
from app.services.ocr_service import extract_ingredients_from_image, extract_nutrition_from_image
from app.services.health_condition_engine import evaluate_health_conditions

analysis_bp = Blueprint("analysis", __name__, url_prefix="/api/analyze")


def _store_health_conditions(scan_id: str, overall: str, health_conditions: list):
    """Additive persistence for the health-condition feature. Never
    raises - if this fails for any reason, the main analysis response
    still goes back to the client unaffected."""
    try:
        existing = AnalysisResult.objects(scan_id=scan_id).first()
        if existing:
            analysis_result = existing
        else:
            # Simple health score: start at 100, subtract per severity.
            score = 100
            for w in health_conditions:
                score -= 30 if w["severity"] == "Avoid" else 15
            score = max(0, min(100, score))

            analysis_result = AnalysisResult(
                scan_id=scan_id,
                overall_result=overall,
                health_score=score,
                summary=f"{len(health_conditions)} health condition warning(s) generated." if health_conditions else "No specific health condition warnings.",
            ).save()

        for w in health_conditions:
            condition = HealthCondition.objects(condition_name=w["condition_name"]).first()
            if not condition:
                continue
            already = HealthConditionWarning.objects(
                analysis_id=str(analysis_result.id), condition=condition
            ).first()
            if already:
                continue
            HealthConditionWarning(
                analysis_id=str(analysis_result.id),
                condition=condition,
                severity=w["severity"],
                recommendation=w["recommendation"],
                reason=w["reason"],
            ).save()
    except Exception:
        # Fail silently - health-condition persistence is additive and
        # must never break the primary analysis response.
        pass


@analysis_bp.post("/product")
@jwt_required()
def analyze_product():
    """Analyze a product already resolved via barcode lookup and save to history."""
    data = request.get_json(silent=True) or {}
    ingredients = data.get("ingredients", "")
    nutrition = data.get("nutrition", {})
    category = data.get("category", "food")

    if not ingredients and not nutrition:
        return jsonify({"error": "ingredients or nutrition data is required."}), 400

    result = analyze(ingredients, nutrition, category)

    history = ScanHistory(
        user=get_jwt_identity(),
        source="barcode",
        product_name=data.get("name", "Unknown Product"),
        brand=data.get("brand", ""),
        image=data.get("image", ""),
        barcode=data.get("barcode", ""),
        ingredients_text=ingredients,
        nutrition=nutrition,
        overall=result["overall"],
        age_groups=result["age_groups"],
        flags=result["flags"],
        nutrition_concerns=result["nutrition_concerns"],
    )
    history.save()

    # --- Additive: health-condition warnings (existing fields above unchanged) ---
    health_conditions = evaluate_health_conditions(ingredients, nutrition)
    _store_health_conditions(str(history.id), result["overall"], health_conditions)
    result["health_conditions"] = health_conditions  # always present, [] if none

    return jsonify({"result": result, "history_id": str(history.id)})


@analysis_bp.post("/ocr")
@jwt_required()
def analyze_ocr():
    """Accept a photographed label, run OCR, analyze, and save to history."""
    if "image" not in request.files:
        return jsonify({"error": "An 'image' file is required."}), 400

    image_file = request.files["image"]
    image_bytes = image_file.read()
    if not image_bytes:
        return jsonify({"error": "Uploaded image is empty."}), 400

    ingredients_text = extract_ingredients_from_image(image_bytes)
    if not ingredients_text:
        return jsonify({"error": "Could not read any text from the image. Try a clearer, well-lit photo."}), 422

    category = request.form.get("category", "food")
    product_name = request.form.get("name", "Scanned Label")

    result = analyze(ingredients_text, {}, category)

    history = ScanHistory(
        user=get_jwt_identity(),
        source="ocr",
        product_name=product_name,
        ingredients_text=ingredients_text,
        nutrition={},
        overall=result["overall"],
        age_groups=result["age_groups"],
        flags=result["flags"],
        nutrition_concerns=result["nutrition_concerns"],
    )
    history.save()

    # --- Additive: health-condition warnings ---
    health_conditions = evaluate_health_conditions(ingredients_text, {})
    _store_health_conditions(str(history.id), result["overall"], health_conditions)
    result["health_conditions"] = health_conditions

    return jsonify({
        "result": result,
        "ingredients_text": ingredients_text,
        "history_id": str(history.id),
    })


@analysis_bp.post("/ocr-full")
@jwt_required()
def analyze_ocr_full():
    """Two-photo OCR flow: ingredients label + nutrition table.
    Used when a product isn't found in Open Food Facts. The nutrition
    photo is optional - if missing or unreadable, analysis proceeds with
    ingredients only, same as the existing /ocr route, just with a
    nutrition dict attached when available."""
    if "ingredients_image" not in request.files:
        return jsonify({"error": "An 'ingredients_image' file is required."}), 400

    ingredients_image_bytes = request.files["ingredients_image"].read()
    if not ingredients_image_bytes:
        return jsonify({"error": "Uploaded ingredients image is empty."}), 400

    ingredients_text = extract_ingredients_from_image(ingredients_image_bytes)
    if not ingredients_text:
        return jsonify({"error": "Could not read any text from the ingredients image. Try a clearer, well-lit photo."}), 422

    nutrition = {}
    if "nutrition_image" in request.files:
        nutrition_image_bytes = request.files["nutrition_image"].read()
        if nutrition_image_bytes:
            try:
                nutrition = extract_nutrition_from_image(nutrition_image_bytes)
            except Exception:
                # Nutrition OCR is best-effort - never block the whole
                # analysis if it fails for any reason.
                nutrition = {}

    category = request.form.get("category", "food")
    product_name = request.form.get("name", "Scanned Label")

    result = analyze(ingredients_text, nutrition, category)

    history = ScanHistory(
        user=get_jwt_identity(),
        source="ocr",
        product_name=product_name,
        ingredients_text=ingredients_text,
        nutrition=nutrition,
        overall=result["overall"],
        age_groups=result["age_groups"],
        flags=result["flags"],
        nutrition_concerns=result["nutrition_concerns"],
    )
    history.save()

    # --- Additive: health-condition warnings (same pattern as /ocr) ---
    health_conditions = evaluate_health_conditions(ingredients_text, nutrition)
    _store_health_conditions(str(history.id), result["overall"], health_conditions)
    result["health_conditions"] = health_conditions

    return jsonify({
        "result": result,
        "ingredients_text": ingredients_text,
        "nutrition": nutrition,
        "history_id": str(history.id),
    })