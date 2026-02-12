import json
import os
import sys
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Add parent directory to path for lib imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.db import init_db
from lib.gemini import fetch_and_store

CRON_SECRET = os.environ.get("CRON_SECRET", "")
VALID_CATEGORIES = ("general", "tech", "economy", "entertainment")


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Vercel Cron uses GET requests
        self._handle()

    def do_POST(self):
        self._handle()

    def _handle(self):
        # 인증 검증: Vercel Cron은 Authorization 헤더에 Bearer <CRON_SECRET>을 보냄
        auth_header = self.headers.get("Authorization", "")
        expected = f"Bearer {CRON_SECRET}"

        if not CRON_SECRET or auth_header != expected:
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": "Unauthorized"},
                ensure_ascii=False,
            ).encode("utf-8"))
            return

        init_db()

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        region = params.get("region", [None])[0]
        category = params.get("category", [None])[0]

        try:
            if region and region not in ("us", "kr"):
                raise ValueError("Invalid region")
            if category and category not in VALID_CATEGORIES:
                raise ValueError("Invalid category")

            if region and category:
                # 단일 리전 + 단일 카테고리 (cron에서 호출)
                fetch_and_store(region, category)
            elif region:
                # 단일 리전, 모든 카테고리 (하위 호환)
                fetch_and_store(region, category or "general")
            else:
                # 전체 갱신 - general만 (안전장치)
                for r in ["us", "kr"]:
                    fetch_and_store(r, "general")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"status": "ok", "message": f"뉴스 갱신 완료: {region or 'all'}/{category or 'general'}"},
                ensure_ascii=False,
            ).encode("utf-8"))
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": f"뉴스 갱신 실패: {str(e)}"},
                ensure_ascii=False,
            ).encode("utf-8"))
