import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-jwt-secret-key")

    MONGODB_SETTINGS = {
        "host": os.environ.get("MONGODB_URI", "mongodb://localhost:27017/nutricheck")
    }

    JWT_ACCESS_TOKEN_EXPIRES = timedelta(
        minutes=int(os.environ.get("JWT_ACCESS_MINUTES", 60))
    )
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(
        days=int(os.environ.get("JWT_REFRESH_DAYS", 30))
    )
    JWT_TOKEN_LOCATION = ["headers"]

    OFF_API_BASE = os.environ.get(
        "OFF_API_BASE", "https://world.openfoodfacts.org/api/v2"
    )

    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "*")

    TESSERACT_CMD = os.environ.get("TESSERACT_CMD", "")

    MAX_CONTENT_LENGTH = 8 * 1024 * 1024  # 8 MB upload limit for OCR images


class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    DEBUG = False


class TestingConfig(Config):
    TESTING = True
    MONGODB_SETTINGS = {"host": "mongomock://localhost/nutricheck_test"}


config_by_name = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
}
