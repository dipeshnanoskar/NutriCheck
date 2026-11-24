import os
from flask import Flask, jsonify
from app.config import config_by_name
from app.extensions import db, jwt, cors


def create_app(config_name=None):
    config_name = config_name or os.environ.get("FLASK_ENV", "development")
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])

    db.init_app(app)
    jwt.init_app(app)
    cors.init_app(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})

    register_blueprints(app)
    register_error_handlers(app)
    register_health_check(app)

    return app


def register_blueprints(app):
    from app.routes.auth import auth_bp
    from app.routes.products import products_bp
    from app.routes.analysis import analysis_bp
    from app.routes.history import history_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(products_bp)
    app.register_blueprint(analysis_bp)
    app.register_blueprint(history_bp)


def register_health_check(app):
    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok", "service": "nutricheck-backend"})


def register_error_handlers(app):
    @app.errorhandler(404)
    def not_found(_e):
        return jsonify({"error": "Resource not found."}), 404

    @app.errorhandler(413)
    def too_large(_e):
        return jsonify({"error": "Uploaded file is too large."}), 413

    @app.errorhandler(500)
    def server_error(_e):
        return jsonify({"error": "Internal server error."}), 500

    @app.errorhandler(Exception)
    def handle_unexpected(e):
        app.logger.exception("Unhandled exception")
        return jsonify({"error": "Unexpected server error."}), 500
