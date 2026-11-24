import bcrypt
from datetime import datetime
from mongoengine import (
    Document,
    StringField,
    EmailField,
    IntField,
    DateTimeField,
)


class User(Document):
    name = StringField(required=True, max_length=100)
    email = EmailField(required=True, unique=True)
    password_hash = StringField(required=True)
    age = IntField(required=True, min_value=1, max_value=120)
    age_group = StringField(choices=["Child", "Teenager", "Adult"])
    created_at = DateTimeField(default=datetime.utcnow)
    updated_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "users", "indexes": ["email"]}

    def set_password(self, raw_password: str):
        self.password_hash = bcrypt.hashpw(
            raw_password.encode("utf-8"), bcrypt.gensalt()
        ).decode("utf-8")

    def check_password(self, raw_password: str) -> bool:
        return bcrypt.checkpw(
            raw_password.encode("utf-8"), self.password_hash.encode("utf-8")
        )

    @staticmethod
    def compute_age_group(age: int) -> str:
        if age < 13:
            return "Child"
        if age < 18:
            return "Teenager"
        return "Adult"

    def to_public_dict(self):
        return {
            "id": str(self.id),
            "name": self.name,
            "email": self.email,
            "age": self.age,
            "age_group": self.age_group,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
