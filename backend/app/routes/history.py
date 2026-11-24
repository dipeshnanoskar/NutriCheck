from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.history import ScanHistory
from app.models.health import AnalysisResult, HealthConditionWarning

history_bp = Blueprint("history", __name__, url_prefix="/api/history")


def _get_health_conditions_for_scan(scan_id: str) -> list:
    """Additive read-side join: ScanHistory.id -> AnalysisResult.scan_id
    -> HealthConditionWarning.analysis_id. Mirrors the write side in
    analysis.py's _store_health_conditions. Never raises - returns []
    on any lookup failure so history retrieval is unaffected."""
    try:
        analysis_result = AnalysisResult.objects(scan_id=scan_id).first()
        if not analysis_result:
            return []
        warnings = HealthConditionWarning.objects(analysis_id=str(analysis_result.id))
        return [
            {
                "condition_name": w.condition.condition_name,
                "severity": w.severity,
                "reason": w.reason,
                "recommendation": w.recommendation,
            }
            for w in warnings
        ]
    except Exception:
        return []


@history_bp.get("")
@jwt_required()
def list_history():
    page = max(int(request.args.get("page", 1)), 1)
    per_page = min(int(request.args.get("per_page", 20)), 100)
    query = ScanHistory.objects(user=get_jwt_identity()).order_by("-created_at")
    total = query.count()
    items = query.skip((page - 1) * per_page).limit(per_page)
    items_data = []
    for item in items:
        d = item.to_dict()
        d["health_conditions"] = _get_health_conditions_for_scan(str(item.id))
        items_data.append(d)
    return jsonify({
        "items": items_data,
        "page": page,
        "per_page": per_page,
        "total": total,
    })


@history_bp.get("/<history_id>")
@jwt_required()
def get_history_item(history_id):
    item = ScanHistory.objects(id=history_id, user=get_jwt_identity()).first()
    if not item:
        return jsonify({"error": "History item not found."}), 404
    data = item.to_dict()
    data["health_conditions"] = _get_health_conditions_for_scan(str(item.id))
    return jsonify({"item": data})


@history_bp.delete("/<history_id>")
@jwt_required()
def delete_history_item(history_id):
    item = ScanHistory.objects(id=history_id, user=get_jwt_identity()).first()
    if not item:
        return jsonify({"error": "History item not found."}), 404
    item.delete()
    return jsonify({"deleted": True})


@history_bp.delete("")
@jwt_required()
def clear_history():
    ScanHistory.objects(user=get_jwt_identity()).delete()
    return jsonify({"deleted": True})