import json
import os
import sys
import time
from collections import defaultdict
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

# Add parent directory to path for lib imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.db import get_latest_news, init_db

ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "").split(",")
VALID_CATEGORIES = ("general", "tech", "economy", "entertainment")

# In-memory rate limiting: max 30 req / 60s per IP
RATE_LIMIT = 30
RATE_WINDOW = 60
_request_counts = defaultdict(list)


def _get_cors_origin(request_origin: str) -> str:
    """Return allowed origin or empty string."""
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == [""]:
        # If no ALLOWED_ORIGINS is configured, allow non-browser clients.
        return request_origin if not request_origin else ""
    if request_origin in ALLOWED_ORIGINS:
        return request_origin
    return ""


def _try_json_loads(value):
    try:
        return json.loads(value)
    except Exception:
        return None


def _parse_summary_value(summary_value):
    """
    Normalize summary payload from DB into a dict with at least:
    {"items": [...], "insight": "..."}
    """
    if isinstance(summary_value, dict):
        return summary_value

    if not isinstance(summary_value, str):
        return {"items": [], "insight": str(summary_value or "")}

    # 1) direct JSON object string
    direct = _try_json_loads(summary_value)
    if isinstance(direct, dict):
        return direct

    # 2) double-encoded JSON string
    if isinstance(direct, str):
        nested = _try_json_loads(direct)
        if isinstance(nested, dict):
            return nested

    text = summary_value.strip()

    # 3) markdown fenced JSON
    if text.startswith("```"):
        text = text.replace("```json", "", 1).replace("```", "").strip()
        fenced = _try_json_loads(text)
        if isinstance(fenced, dict):
            return fenced

    # 4) extract first JSON object fragment
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        fragment = _try_json_loads(text[start : end + 1])
        if isinstance(fragment, dict):
            return fragment

    # 5) plain text fallback
    return {"items": [], "insight": text}


class handler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        origin = self.headers.get("Origin", "")
        allowed = _get_cors_origin(origin)
        if allowed:
            self.send_header("Access-Control-Allow-Origin", allowed)
        self.send_header("Vary", "Origin")

    def _json_response(self, status_code: int, payload: dict, extra_headers: dict | None = None):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self._send_cors_headers()
        if extra_headers:
            for key, value in extra_headers.items():
                self.send_header(key, value)
        self.end_headers()
        self.wfile.write(json.dumps(payload, ensure_ascii=False).encode("utf-8"))

    def _check_rate_limit(self) -> bool:
        client_ip = self.headers.get("X-Forwarded-For", self.client_address[0])
        now = time.time()
        _request_counts[client_ip] = [
            t for t in _request_counts[client_ip] if now - t < RATE_WINDOW
        ]
        if len(_request_counts[client_ip]) >= RATE_LIMIT:
            return True
        _request_counts[client_ip].append(now)
        return False

    def do_GET(self):
        if self._check_rate_limit():
            self._json_response(
                429,
                {"detail": "Too many requests. Please retry shortly."},
                extra_headers={"Retry-After": str(RATE_WINDOW)},
            )
            return

        init_db()

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        region = params.get("region", [None])[0]
        category = params.get("category", ["general"])[0]

        if region not in ("us", "kr"):
            self._json_response(400, {"detail": "region must be 'us' or 'kr'."})
            return

        if category not in VALID_CATEGORIES:
            self._json_response(
                400,
                {"detail": f"category must be one of: {', '.join(VALID_CATEGORIES)}"},
            )
            return

        row = get_latest_news(region, category)
        if not row:
            self._json_response(404, {"detail": "No briefing found yet."})
            return

        parsed_summary = _parse_summary_value(row["summary"])

        # Keep compatibility with existing app/client contracts.
        payload = {
            "summary": json.dumps(parsed_summary, ensure_ascii=False),
            "sources": json.loads(row["sources"]),
            "updated_at": row["created_at"],
        }

        # Also expose normalized fields directly for newer clients.
        payload["items"] = parsed_summary.get("items", [])
        payload["insight"] = parsed_summary.get("insight", "")

        self._json_response(200, payload)

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

