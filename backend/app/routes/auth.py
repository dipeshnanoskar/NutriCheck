from flask import Blueprint, request, jsonify
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    jwt_required,
    get_jwt_identity,
)
from mongoengine.errors import NotUniqueError, ValidationError
from app.models.user import User

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@auth_bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    age = data.get("age")

    errors = {}
    if not name:
        errors["name"] = "Name is required."
    if not email:
        errors["email"] = "Email is required."
    if not password or len(password) < 6:
        errors["password"] = "Password must be at least 6 characters."
    try:
        age = int(age)
        if age < 1 or age > 120:
            raise ValueError
    except (TypeError, ValueError):
        errors["age"] = "A valid age is required."

    if errors:
        return jsonify({"errors": errors}), 400

    user = User(name=name, email=email, age=age)
    user.age_group = User.compute_age_group(age)
    user.set_password(password)

    try:
        user.save()
    except NotUniqueError:
        return jsonify({"errors": {"email": "An account with this email already exists."}}), 409
    except ValidationError as exc:
        return jsonify({"errors": {"validation": str(exc)}}), 400

    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))
    return jsonify({
        "user": user.to_public_dict(),
        "access_token": access_token,
        "refresh_token": refresh_token,
    }), 201


@auth_bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    user = User.objects(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Invalid email or password."}), 401

    access_token = create_access_token(identity=str(user.id))
    refresh_token = create_refresh_token(identity=str(user.id))
    return jsonify({
        "user": user.to_public_dict(),
        "access_token": access_token,
        "refresh_token": refresh_token,
    })


@auth_bp.post("/refresh")
@jwt_required(refresh=True)
def refresh():
    identity = get_jwt_identity()
    new_access_token = create_access_token(identity=identity)
    return jsonify({"access_token": new_access_token})


@auth_bp.get("/me")
@jwt_required()
def me():
    user = User.objects(id=get_jwt_identity()).first()
    if not user:
        return jsonify({"error": "User not found."}), 404
    return jsonify({"user": user.to_public_dict()})


@auth_bp.put("/me")
@jwt_required()
def update_me():
    user = User.objects(id=get_jwt_identity()).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    data = request.get_json(silent=True) or {}
    if "name" in data and data["name"].strip():
        user.name = data["name"].strip()
    if "age" in data:
        try:
            age = int(data["age"])
            if 1 <= age <= 120:
                user.age = age
                user.age_group = User.compute_age_group(age)
        except (TypeError, ValueError):
            pass
    user.save()
    return jsonify({"user": user.to_public_dict()})
