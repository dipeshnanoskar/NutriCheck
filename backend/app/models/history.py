from datetime import datetime
from mongoengine import (
    Document,
    StringField,
    DictField,
    ListField,
    ReferenceField,
    DateTimeField,
    CASCADE,
)
from app.models.user import User


class ScanHistory(Document):
    user = ReferenceField(User, required=True, reverse_delete_rule=CASCADE)
    source = StringField(choices=["barcode", "ocr"], required=True)
    product_name = StringField(required=True)
    brand = StringField(default="")
    image = StringField(default="")
    barcode = StringField(default="")
    ingredients_text = StringField(default="")
    nutrition = DictField(default=dict)
    overall = StringField(
        choices=["Generally Suitable", "Use Caution", "Avoid"], required=True
    )
    age_groups = ListField(DictField(), default=list)
    flags = ListField(DictField(), default=list)
    nutrition_concerns = ListField(DictField(), default=list)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {
        "collection": "scan_history",
        "indexes": ["user", "-created_at"],
        "ordering": ["-created_at"],
    }

    def to_dict(self):
        return {
            "id": str(self.id),
            "source": self.source,
            "product_name": self.product_name,
            "brand": self.brand,
            "image": self.image,
            "barcode": self.barcode,
            "ingredients": self.ingredients_text,
            "nutrition": self.nutrition,
            "overall": self.overall,
            "age_groups": self.age_groups,
            "flags": self.flags,
            "nutrition_concerns": self.nutrition_concerns,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
