import json
import sys
import os
import time
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from collections import defaultdict

# Add parent directory to path for lib imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.db import get_latest_news, init_db

ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "").split(",")
VALID_CATEGORIES = ("general", "tech", "economy", "entertainment")

# 간단한 인메모리 Rate Limiting (IP당 분당 30회)
RATE_LIMIT = 30
RATE_WINDOW = 60  # seconds
_request_counts = defaultdict(list)


def _get_cors_origin(request_origin: str) -> str:
    """허용된 origin이면 그대로 반환, 아니면 빈 문자열"""
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == [""]:
        # 환경변수 미설정 시 앱 클라이언트만 허용 (모바일 앱은 origin 없음)
        return request_origin if not request_origin else ""
    if request_origin in ALLOWED_ORIGINS:
        return request_origin
    return ""


class handler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        origin = self.headers.get("Origin", "")
        allowed = _get_cors_origin(origin)
        if allowed:
            self.send_header("Access-Control-Allow-Origin", allowed)
        # 모바일 앱 요청 (Origin 없음)은 CORS 헤더 불필요
        self.send_header("Vary", "Origin")

    def _check_rate_limit(self) -> bool:
        """IP 기반 rate limit 체크. 초과 시 True 반환"""
        client_ip = self.headers.get("X-Forwarded-For", self.client_address[0])
        now = time.time()
        # 만료된 기록 제거
        _request_counts[client_ip] = [
            t for t in _request_counts[client_ip] if now - t < RATE_WINDOW
        ]
        if len(_request_counts[client_ip]) >= RATE_LIMIT:
            return True
        _request_counts[client_ip].append(now)
        return False

    def do_GET(self):
        # Rate limit 체크
        if self._check_rate_limit():
            self.send_response(429)
            self.send_header("Content-Type", "application/json")
            self.send_header("Retry-After", str(RATE_WINDOW))
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": "요청이 너무 많습니다. 잠시 후 다시 시도해주세요."},
                ensure_ascii=False,
            ).encode("utf-8"))
            return

        init_db()

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        region = params.get("region", [None])[0]
        category = params.get("category", ["general"])[0]

        if region not in ("us", "kr"):
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": "region은 'us' 또는 'kr'만 가능합니다."},
                ensure_ascii=False,
            ).encode("utf-8"))
            return

        # category 입력 검증
        if category not in VALID_CATEGORIES:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": f"category는 {', '.join(VALID_CATEGORIES)} 중 하나여야 합니다."},
                ensure_ascii=False,
            ).encode("utf-8"))
            return

        row = get_latest_news(region, category)
        if not row:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": "아직 뉴스가 준비되지 않았습니다."},
                ensure_ascii=False,
            ).encode("utf-8"))
            return

        sources = json.loads(row["sources"])
        body = json.dumps({
            "summary": row["summary"],
            "sources": sources,
            "updated_at": row["created_at"],
        }, ensure_ascii=False)

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
