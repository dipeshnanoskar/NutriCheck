from datetime import datetime
from mongoengine import (
    Document,
    StringField,
    DictField,
    DateTimeField,
)


class Product(Document):
    """
    Local cache of products resolved from the Open Food Facts database
    (https://world.openfoodfacts.org). Populated on-demand the first time
    a barcode is scanned so repeat scans are fast and work offline-ish.
    No hard-coded/dummy products ship with this app.
    """

    barcode = StringField(required=True, unique=True)
    name = StringField(required=True)
    brand = StringField(default="")
    category = StringField(default="")
    image = StringField(default="")
    ingredients_text = StringField(default="")
    nutrition = DictField(default=dict)  # energy, fat, saturatedFat, carbs, sugars, fiber, protein, salt
    source = StringField(default="openfoodfacts")
    fetched_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "products", "indexes": ["barcode"]}

    def to_dict(self):
        return {
            "barcode": self.barcode,
            "name": self.name,
            "brand": self.brand,
            "category": self.category,
            "image": self.image,
            "ingredients": self.ingredients_text,
            "nutrition": self.nutrition,
        }
