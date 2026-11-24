"""
OCR service - extracts ingredients text and nutrition values from a
photographed label using Tesseract OCR. Used by the OCR-camera flow when a
product has no barcode or the barcode isn't in the product database.

Public API (unchanged):
    extract_ingredients_from_image(image_bytes) -> str
    extract_nutrition_from_image(image_bytes)   -> dict
    parse_nutrition_text(raw_text)              -> dict

New helpers (optional to use from routes):
    looks_like_ingredients(text)  -> bool
    nutrition_is_usable(nutrition) -> bool
"""

import io
import re
import pytesseract
from PIL import Image, ImageOps, ImageFilter
from flask import current_app

_TARGET_WIDTH = 2000   # upscale small photos to roughly this width
_MAX_WIDTH = 3200      # downscale huge phone photos (faster, no accuracy loss)


# --- Image preprocessing ------------------------------------------------

def _otsu_threshold(gray: Image.Image) -> int:
    """Pick a black/white threshold automatically (Otsu's method)."""
    hist = gray.histogram()[:256]
    total = sum(hist)
    sum_all = sum(i * h for i, h in enumerate(hist))
    sum_b = 0
    w_b = 0
    best = 0.0
    threshold = 128
    for i in range(256):
        w_b += hist[i]
        if w_b == 0:
            continue
        w_f = total - w_b
        if w_f == 0:
            break
        sum_b += i * hist[i]
        m_b = sum_b / w_b
        m_f = (sum_all - sum_b) / w_f
        between = w_b * w_f * (m_b - m_f) ** 2
        if between > best:
            best = between
            threshold = i
    return threshold


def _preprocess(image: Image.Image) -> Image.Image:
    image = ImageOps.exif_transpose(image)
    image = image.convert("L")  # grayscale

    # Normalise size: Tesseract works best when text is ~25-35px tall.
    if image.width < _TARGET_WIDTH:
        scale = _TARGET_WIDTH / image.width
        image = image.resize(
            (int(image.width * scale), int(image.height * scale)),
            Image.LANCZOS,
        )
    elif image.width > _MAX_WIDTH:
        scale = _MAX_WIDTH / image.width
        image = image.resize(
            (int(image.width * scale), int(image.height * scale)),
            Image.LANCZOS,
        )

    image = ImageOps.autocontrast(image, cutoff=2)
    image = image.filter(ImageFilter.MedianFilter(3))  # remove speckle noise
    image = image.filter(ImageFilter.SHARPEN)
    return image


def _binarize(gray: Image.Image) -> Image.Image:
    threshold = _otsu_threshold(gray)
    return gray.point(lambda p: 255 if p > threshold else 0)


def _score(text: str) -> float:
    """Rough 'how readable is this' score: real words + numbers."""
    words = len(re.findall(r"[A-Za-z]{3,}", text))
    numbers = len(re.findall(r"\d+(?:[.,]\d+)?", text))
    return words + 0.5 * numbers


def _run_ocr(image_bytes: bytes) -> str:
    """Run Tesseract a few different ways and keep the most readable result."""
    tesseract_cmd = current_app.config.get("TESSERACT_CMD")
    if tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    image = Image.open(io.BytesIO(image_bytes))
    gray = _preprocess(image)
    binary = _binarize(gray)

    attempts = [
        (gray, 6),
        (binary, 6),
        (gray, 4),
    ]

    best_text = ""
    best_score = -1.0
    for img, psm in attempts:
        config = f"--oem 3 --psm {psm} -c preserve_interword_spaces=1"
        try:
            text = pytesseract.image_to_string(img, config=config)
        except pytesseract.TesseractError:
            continue
        score = _score(text)
        if score > best_score:
            best_score = score
            best_text = text
    return best_text


# --- Ingredients --------------------------------------------------------

# Tolerant of OCR slips such as "Ingredlents" / "Ingredients."
_INGREDIENTS_HEADER = re.compile(r"ingr[a-z0-9]{2,6}ts?\s*[:\-.]?", re.I)

# Things that usually come right AFTER the ingredients list on a label.
_INGREDIENTS_STOP = re.compile(
    r"(nutrition(al)?\s*(information|facts|value)|allergen|manufactured|"
    r"marketed|mfd|mfg|best\s*before|fssai|net\s*(wt|weight|qty|quantity)|"
    r"store\s+in|customer\s*care|use\s+by)",
    re.I,
)


def _clean_text(raw: str) -> str:
    text = re.sub(r"[ \t]+", " ", raw or "")
    text = re.sub(r"\n{2,}", "\n", text)
    text = text.strip()

    # Isolate the ingredients section if the label has an "Ingredients" header.
    match = _INGREDIENTS_HEADER.search(text)
    if match:
        text = text[match.end():].strip()
        stop = _INGREDIENTS_STOP.search(text)
        if stop and stop.start() > 20:
            text = text[:stop.start()].strip()

    # Re-join words broken across lines ("emul-\nsifier").
    text = re.sub(r"-\n(?=[a-z])", "", text)
    # Ingredients are comma separated, so line wraps are just spaces.
    if text.count(",") >= 2:
        text = re.sub(r"\s*\n\s*", " ", text)

    return text.strip()


def extract_ingredients_from_image(image_bytes: bytes) -> str:
    raw_text = _run_ocr(image_bytes)
    return _clean_text(raw_text)


def looks_like_ingredients(text: str) -> bool:
    """True if the text plausibly is an ingredients list (not just a brand
    name or random noise). Use this in the route to avoid showing a
    'Suitable' verdict when nothing useful was read."""
    if not text:
        return False
    words = re.findall(r"[A-Za-z]{3,}", text)
    separators = text.count(",") + text.count(";")
    return len(words) >= 6 and separators >= 2


# --- Nutrition table OCR -----------------------------------------------

_NUM = r"(\d+(?:[.,]\d+)?)"
# Gap between a label and its number. Allows units like "(g)", ":", "|", "kcal"
# but NOT digits or line breaks, so we never grab the next row's number.
_GAP = r"[^0-9\n]{0,25}"

# Each nutrient maps to label variants that might appear on a real
# packaging nutrition table, tolerant of common OCR misreads and of both
# "Fat 5 g" and "Fat (g) 5" layouts.
_NUTRITION_LABEL_PATTERNS = {
    "energy": [
        r"energy[^\n]{0,30}?" + _NUM + r"\s*k?cal",
        r"calories" + _GAP + _NUM,
        r"energy" + _GAP + _NUM,
    ],
    "fat": [
        r"total\s+fat" + _GAP + _NUM,
        r"(?<!saturated\s)(?<!sat\.\s)(?<!trans\s)\bfat\b" + _GAP + _NUM,
    ],
    "saturatedFat": [
        r"saturated" + _GAP + _NUM,
        r"sat\.?\s*fat" + _GAP + _NUM,
    ],
    "carbs": [
        r"(?:total\s+)?carbohydrates?" + _GAP + _NUM,
        r"carbs" + _GAP + _NUM,
    ],
    "sugars": [
        r"total\s+sugars?" + _GAP + _NUM,
        r"(?<!added\s)sugars?" + _GAP + _NUM,
    ],
    "fiber": [
        r"(?:dietary\s+)?fib(?:er|re)" + _GAP + _NUM,
    ],
    "protein": [
        r"proteins?" + _GAP + _NUM,
    ],
    "salt": [
        r"\bsalt\b" + _GAP + _NUM,
    ],
    "sodium": [
        r"sodium" + _GAP + _NUM,
    ],
}

# Values per 100 g / 100 ml can't exceed these. Anything bigger is an OCR
# misread, so it's dropped instead of being trusted.
_MAX_VALUES = {
    "energy": 900,
    "fat": 100,
    "saturatedFat": 100,
    "carbs": 100,
    "sugars": 100,
    "fiber": 100,
    "protein": 100,
    "salt": 100,
}


def _find_first(patterns, text_lower):
    for pattern in patterns:
        match = re.search(pattern, text_lower, re.I)
        if match:
            value = match.group(1).replace(",", ".")
            try:
                return float(value)
            except ValueError:
                continue
    return None


def _normalize_numbers(text: str) -> str:
    """Fix the most common digit misreads, only when next to other digits."""
    text = re.sub(r"(?<=\d)[oO](?=\d)", "0", text)      # 1O5 -> 105
    text = re.sub(r"(?<=\d)[oO](?=\s*(?:g|mg|%))", "0", text)  # 5O g -> 50 g
    text = re.sub(r"(?<=\d)[lI|](?=\d)", "1", text)     # 1l5 -> 115
    return text


def parse_nutrition_text(raw_text: str) -> dict:
    """Best-effort extraction of per-100g/100ml nutrition values from raw
    OCR text of a nutrition table. Tolerant of label wording variants and
    OCR noise. Any nutrient not confidently found is simply omitted (None)
    rather than guessed - callers (analyze()) already treat missing
    nutrients as 'no concern flagged for this value', never as zero.

    Known limitation: does not reliably distinguish 'per serving' vs
    'per 100g' columns when both are present on the label - it takes the
    first plausible match for each nutrient.
    """
    text_lower = (raw_text or "").lower()
    text_lower = re.sub(r"[ \t]+", " ", text_lower)
    text_lower = _normalize_numbers(text_lower)

    nutrition = {}
    for key in ("energy", "fat", "saturatedFat", "carbs", "sugars", "fiber", "protein", "salt"):
        value = _find_first(_NUTRITION_LABEL_PATTERNS[key], text_lower)
        if value is not None and value <= _MAX_VALUES[key]:
            nutrition[key] = value

    # If salt wasn't found but sodium was, derive salt from sodium
    # (standard conversion: salt (g) = sodium (mg) x 2.5 / 1000).
    if "salt" not in nutrition:
        sodium_mg = _find_first(_NUTRITION_LABEL_PATTERNS["sodium"], text_lower)
        if sodium_mg is not None and sodium_mg <= 40000:
            nutrition["salt"] = round(sodium_mg * 2.5 / 1000, 2)

    return nutrition


def extract_nutrition_from_image(image_bytes: bytes) -> dict:
    raw_text = _run_ocr(image_bytes)
    return parse_nutrition_text(raw_text)


def nutrition_is_usable(nutrition: dict) -> bool:
    """True if at least 2 nutrient values were read. Use this in the route
    to avoid showing a 'Suitable' verdict based on an empty table."""
    return bool(nutrition) and len(nutrition) >= 2