# NutriCheck Backend (Flask + MongoDB)

Production-ready REST API for the NutriCheck app. Real data only — no mocks:

- **Products**: resolved live from [Open Food Facts](https://world.openfoodfacts.org) on first scan, then cached in MongoDB.
- **Analysis**: a genuine rule-based engine (`app/services/nutrition_analyzer.py`) using WHO/UK-FSA-style sugar, salt, saturated-fat thresholds plus ingredient watch-lists (caffeine, artificial sweeteners/colors, allergens, additives) to produce Child / Teenager / Adult verdicts.
- **OCR**: Tesseract-based ingredient-label text extraction for products without a resolvable barcode.
- **Auth**: JWT (access + refresh tokens), bcrypt password hashing.
- **History**: per-user scan history stored in MongoDB.

## 1. Prerequisites

- Python 3.11+
- MongoDB running locally or an Atlas connection string
- Tesseract OCR engine installed on the host (needed for the `/api/analyze/ocr` endpoint)
  - macOS: `brew install tesseract`
  - Ubuntu/Debian: `sudo apt-get install tesseract-ocr`
  - Windows: install from https://github.com/UB-Mannheim/tesseract/wiki and set `TESSERACT_CMD` in `.env`

## 2. Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# edit .env: set SECRET_KEY, JWT_SECRET_KEY, MONGODB_URI
```

## 3. Run MongoDB

Local (Docker):
```bash
docker run -d -p 27017:27017 --name nutricheck-mongo mongo:7
```
Or point `MONGODB_URI` in `.env` at a MongoDB Atlas cluster.

## 4. Run the API

```bash
python run.py
# API now listening on http://0.0.0.0:5000
```

Production (Gunicorn):
```bash
gunicorn -w 4 -b 0.0.0.0:5000 run:app
```

Or with Docker Compose (spins up Mongo + backend together):
```bash
docker compose up --build
```

## 5. Verify

```bash
curl http://localhost:5000/api/health
# {"status":"ok","service":"nutricheck-backend"}
```

## API Reference

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/register` | – | Create account (name, email, password, age) |
| POST | `/api/auth/login` | – | Login, returns access + refresh JWT |
| POST | `/api/auth/refresh` | refresh token | Get a new access token |
| GET | `/api/auth/me` | access token | Current user profile |
| PUT | `/api/auth/me` | access token | Update name / age |
| GET | `/api/products/barcode/<barcode>` | access token | Real product lookup (Open Food Facts, cached) |
| GET | `/api/products/search?q=` | access token | Product text search |
| POST | `/api/analyze/product` | access token | Run suitability analysis on a resolved product, saves to history |
| POST | `/api/analyze/ocr` | access token | Multipart image upload → OCR → analysis, saves to history |
| GET | `/api/history` | access token | Paginated scan history |
| GET | `/api/history/<id>` | access token | Single history item |
| DELETE | `/api/history/<id>` | access token | Delete one history item |
| DELETE | `/api/history` | access token | Clear all history |

All authenticated endpoints expect `Authorization: Bearer <access_token>`.

## Notes on removing dummy data

The original Figma prototype always returned a single hard-coded `MOCK_PRODUCT` / `MOCK_RESULT`. This backend has **no such fallback** — every barcode is a real lookup against Open Food Facts, and every verdict is computed by `nutrition_analyzer.py` from the real ingredients/nutrition returned. If a barcode genuinely isn't in the Open Food Facts database, the API returns a real `404`, which the Flutter app surfaces as the "Product Not Found" screen with an OCR fallback.
