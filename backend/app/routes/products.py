from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from app.models.product import Product
from app.services.off_client import fetch_product_by_barcode, ProductNotFoundError, search_products

products_bp = Blueprint("products", __name__, url_prefix="/api/products")


@products_bp.get("/barcode/<barcode>")
@jwt_required()
def get_by_barcode(barcode):
    barcode = barcode.strip()

    cached = Product.objects(barcode=barcode).first()
    if cached:
        return jsonify({"product": cached.to_dict(), "cached": True})

    try:
        product_data = fetch_product_by_barcode(barcode)
    except ProductNotFoundError as exc:
        return jsonify({"error": str(exc), "not_found": True}), 404

    product = Product(**product_data)
    product.save()

    return jsonify({"product": product.to_dict(), "cached": False})


@products_bp.get("/search")
@jwt_required()
def search():
    query = request.args.get("q", "").strip()
    if not query:
        return jsonify({"results": []})
    results = search_products(query)
    return jsonify({"results": results})
