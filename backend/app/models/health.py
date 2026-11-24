"""
Additive models for the health-condition analysis feature.

Nothing here touches User, Product, or ScanHistory - those collections
and their fields are untouched. Every collection name below matches
exactly what was specified: health_conditions, health_condition_warnings,
ingredients, ingredient_categories, ingredient_aliases,
ingredient_risk_rules, nutrition_risk_rules, product_ingredients,
nutrition, analysis_results, analysis_rules, ocr_scans.
"""

from datetime import datetime
from mongoengine import (
    Document, StringField, IntField, FloatField, BooleanField,
    DateTimeField, ReferenceField, ListField, DictField, NULLIFY, CASCADE
)


# ---------------------------------------------------------------------------
# Reference / configuration collections
# ---------------------------------------------------------------------------

class HealthCondition(Document):
    """Reference categories used for product analysis - NOT a user's
    personal medical record. e.g. Diabetes, High Blood Pressure."""
    condition_name = StringField(required=True, unique=True)
    description = StringField(default="")
    active = BooleanField(default=True)
    created_at = DateTimeField(default=datetime.utcnow)
    updated_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "health_conditions",
        "indexes": ["condition_name"],
    }


class IngredientCategory(Document):
    category_name = StringField(required=True, unique=True)
    description = StringField(default="")
    active = BooleanField(default=True)

    meta = {"collection": "ingredient_categories"}


class Ingredient(Document):
    ingredient_name = StringField(required=True)
    normalized_name = StringField(required=True)
    category = ReferenceField(IngredientCategory, null=True)
    risk_type = StringField(default="")
    description = StringField(default="")
    active = BooleanField(default=True)

    meta = {
        "collection": "ingredients",
        "indexes": ["normalized_name"],
    }


class IngredientAlias(Document):
    ingredient = ReferenceField(Ingredient, required=True, reverse_delete_rule=CASCADE)
    alias_name = StringField(required=True)
    normalized_alias = StringField(required=True)

    meta = {
        "collection": "ingredient_aliases",
        "indexes": ["normalized_alias"],
    }


class IngredientRiskRule(Document):
    """condition and age_group may be null when the rule applies broadly
    (not condition-specific)."""
    ingredient = ReferenceField(Ingredient, required=True)
    condition = ReferenceField(HealthCondition, null=True)
    age_group_name = StringField(null=True)  # "Child" / "Teenager" / "Adult" - kept simple, string not FK
    severity = StringField(choices=["Safe", "Caution", "Limit", "Avoid"], required=True)
    recommendation = StringField(default="")
    reason = StringField(default="")
    active = BooleanField(default=True)
    created_at = DateTimeField(default=datetime.utcnow)
    updated_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "ingredient_risk_rules",
        "indexes": ["ingredient", "condition"],
    }


class NutritionRiskRule(Document):
    nutrient_name = StringField(required=True)  # e.g. "sugars", "sodium"
    minimum_value = FloatField(null=True)
    maximum_value = FloatField(null=True)
    severity = StringField(choices=["Safe", "Caution", "Limit", "Avoid"], required=True)
    applicable_condition = ReferenceField(HealthCondition, null=True)
    recommendation = StringField(default="")
    description = StringField(default="")
    active = BooleanField(default=True)
    created_at = DateTimeField(default=datetime.utcnow)
    updated_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "nutrition_risk_rules",
        "indexes": ["nutrient_name"],
    }


class AnalysisRule(Document):
    """General-purpose rule slot for future non-health-condition logic.
    Not required for the health-condition feature to function."""
    rule_name = StringField(required=True)
    rule_type = StringField(default="")
    condition = StringField(default="")
    threshold = FloatField(null=True)
    severity = StringField(default="")
    recommendation = StringField(default="")
    description = StringField(default="")
    active = BooleanField(default=True)

    meta = {"collection": "analysis_rules"}


# ---------------------------------------------------------------------------
# Per-scan linkage collections
# ---------------------------------------------------------------------------

class ProductIngredient(Document):
    """Optional normalized link between a scanned product's raw ingredient
    text and the canonical Ingredient entry. Populated best-effort; the
    health-condition engine also works directly off ingredients_text if
    this hasn't been populated for a given product."""
    barcode = StringField(required=True)  # links to Product.barcode (no rename of Product needed)
    ingredient = ReferenceField(Ingredient, required=True)
    original_text = StringField(required=True)
    ingredient_order = IntField(default=0)

    meta = {
        "collection": "product_ingredients",
        "indexes": ["barcode", "ingredient"],
    }


class Nutrition(Document):
    """Optional normalized nutrition record, separate from the DictField
    already stored on Product/ScanHistory. Additive only - existing
    nutrition dicts on Product/ScanHistory are untouched and still used
    by the existing analyzer."""
    barcode = StringField(required=True)
    energy_kcal = FloatField(null=True)
    total_fat = FloatField(null=True)
    saturated_fat = FloatField(null=True)
    trans_fat = FloatField(null=True)
    carbohydrate = FloatField(null=True)
    sugars = FloatField(null=True)
    protein = FloatField(null=True)
    fiber = FloatField(null=True)
    sodium = FloatField(null=True)
    salt = FloatField(null=True)
    serving_size = StringField(default="")
    unit = StringField(default="g")
    created_at = DateTimeField(default=datetime.utcnow)
    updated_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "nutrition",
        "indexes": ["barcode"],
    }


class AnalysisResult(Document):
    """1:1 with a ScanHistory entry (referenced by scan_id = ScanHistory.id
    as a string, so we never need to modify the ScanHistory model)."""
    scan_id = StringField(required=True, unique=True)
    overall_result = StringField(required=True)
    health_score = IntField(null=True)
    summary = StringField(default="")
    analyzed_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "analysis_results",
        "indexes": ["scan_id"],
    }


class HealthConditionWarning(Document):
    analysis_id = StringField(required=True)  # AnalysisResult.id as string
    condition = ReferenceField(HealthCondition, required=True)
    severity = StringField(choices=["Safe", "Caution", "Limit", "Avoid"], required=True)
    recommendation = StringField(default="")
    reason = StringField(default="")
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "health_condition_warnings",
        "indexes": ["analysis_id", "condition"],
    }


class OcrScan(Document):
    """OCR-ready collection, unused by the health-condition feature today.
    product_id is intentionally optional per spec."""
    user_id = StringField(required=True)
    product_id = StringField(null=True)
    scan_type = StringField(choices=["Ingredient List", "Nutrition Table"], required=True)
    image_path = StringField(default="")
    extracted_text = StringField(default="")
    confidence_score = FloatField(null=True)
    status = StringField(default="pending")
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "ocr_scans"}