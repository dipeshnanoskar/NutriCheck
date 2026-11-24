"""
Seed script for the health-condition feature.

Safe to run multiple times - uses get-or-create everywhere, never
duplicates. Does NOT touch users, products, or scan_history.

Run from the backend folder with the venv active:
    python -m app.services.seed_health_data
"""

from app import create_app
from app.models.health import (
    HealthCondition, IngredientCategory, Ingredient, IngredientAlias,
    IngredientRiskRule, NutritionRiskRule,
)


def get_or_create_condition(name, description):
    obj = HealthCondition.objects(condition_name=name).first()
    if obj:
        return obj
    return HealthCondition(condition_name=name, description=description).save()


def get_or_create_category(name):
    obj = IngredientCategory.objects(category_name=name).first()
    if obj:
        return obj
    return IngredientCategory(category_name=name).save()


def get_or_create_ingredient(name, normalized, category):
    obj = Ingredient.objects(normalized_name=normalized).first()
    if obj:
        return obj
    return Ingredient(ingredient_name=name, normalized_name=normalized, category=category).save()


def get_or_create_alias(ingredient, alias, normalized_alias):
    obj = IngredientAlias.objects(normalized_alias=normalized_alias).first()
    if obj:
        return obj
    return IngredientAlias(ingredient=ingredient, alias_name=alias, normalized_alias=normalized_alias).save()


def run():
    app = create_app()
    with app.app_context():
        # --- Health conditions ---
        diabetes = get_or_create_condition("Diabetes", "Blood sugar management condition.")
        hbp = get_or_create_condition("High Blood Pressure", "Hypertension.")
        heart = get_or_create_condition("Heart-related conditions", "Cardiovascular conditions.")

        # --- Categories ---
        cat_sugar = get_or_create_category("Sugar")
        cat_sweet = get_or_create_category("Sweet Ingredient")
        cat_salt = get_or_create_category("Salt/Sodium")
        cat_fat = get_or_create_category("Fat/Oil")

        # --- Ingredients + aliases ---
        sugar = get_or_create_ingredient("Sugar", "sugar", cat_sugar)
        for alias in ["sucrose", "white sugar", "table sugar", "cane sugar", "invert sugar"]:
            get_or_create_alias(sugar, alias, alias)

        glucose_syrup = get_or_create_ingredient("Glucose Syrup", "glucose syrup", cat_sweet)
        for alias in ["corn syrup", "high fructose corn syrup", "honey", "molasses", "rice syrup"]:
            get_or_create_alias(glucose_syrup, alias, alias)

        salt = get_or_create_ingredient("Salt", "salt", cat_salt)
        for alias in ["sodium chloride", "sea salt", "rock salt", "table salt"]:
            get_or_create_alias(salt, alias, alias)

        saturated_fat_ingredient = get_or_create_ingredient(
            "Palm Oil", "palm oil", cat_fat
        )

        # --- Ingredient risk rules ---
        if not IngredientRiskRule.objects(ingredient=sugar, condition=diabetes).first():
            IngredientRiskRule(
                ingredient=sugar, condition=diabetes, severity="Limit",
                reason="High-sugar ingredients may be unsuitable for people managing diabetes.",
                recommendation="People with diabetes should limit or avoid this product.",
            ).save()

        if not IngredientRiskRule.objects(ingredient=glucose_syrup, condition=diabetes).first():
            IngredientRiskRule(
                ingredient=glucose_syrup, condition=diabetes, severity="Limit",
                reason="Glucose/corn syrups raise blood sugar quickly.",
                recommendation="People with diabetes should limit or avoid this product.",
            ).save()

        if not IngredientRiskRule.objects(ingredient=salt, condition=hbp).first():
            IngredientRiskRule(
                ingredient=salt, condition=hbp, severity="Caution",
                reason="Added salt contributes to sodium intake.",
                recommendation="People with high blood pressure may need to limit high-sodium products.",
            ).save()

        # --- Nutrition risk rules ---
        if not NutritionRiskRule.objects(nutrient_name="sugars", applicable_condition=diabetes).first():
            NutritionRiskRule(
                nutrient_name="sugars", minimum_value=22.5, severity="Limit",
                applicable_condition=diabetes,
                description="High-sugar ingredients may make blood-glucose management more difficult.",
                recommendation="People with diabetes should limit or avoid this product.",
            ).save()

        if not NutritionRiskRule.objects(nutrient_name="salt", applicable_condition=hbp).first():
            NutritionRiskRule(
                nutrient_name="salt", minimum_value=1.5, severity="Caution",
                applicable_condition=hbp,
                description="High salt content (>1.5g/100g).",
                recommendation="People with high blood pressure may need to limit high-sodium products.",
            ).save()

        if not NutritionRiskRule.objects(nutrient_name="saturatedFat", applicable_condition=heart).first():
            NutritionRiskRule(
                nutrient_name="saturatedFat", minimum_value=5, severity="Caution",
                applicable_condition=heart,
                description="High saturated fat content (>5g/100g).",
                recommendation="People with heart-related conditions may need to limit saturated fat intake.",
            ).save()

        print("Health-condition seed data ready (idempotent - safe to rerun).")


if __name__ == "__main__":
    run()