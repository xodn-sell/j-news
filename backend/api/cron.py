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


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Vercel Cron uses GET requests
        self._handle()

    def do_POST(self):
        self._handle()

    def _handle(self):
        # ?몄쬆 寃利? Vercel Cron? Authorization ?ㅻ뜑??Bearer <CRON_SECRET>??蹂대깂
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

        try:
            if region:
                if region not in ("us", "kr"):
                    raise ValueError("Invalid region")
                for cat in ["general", "tech", "economy", "entertainment"]:
                    fetch_and_store(region, cat)
            else:
                # 吏?????섎㈃ ?꾩껜 媛깆떊
                for r in ["us", "kr"]:
                    for cat in ["general", "tech", "economy", "entertainment"]:
                        fetch_and_store(r, cat)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"status": "ok", "message": "?댁뒪媛 ?깃났?곸쑝濡?媛깆떊?섏뿀?듬땲??"},
                ensure_ascii=False,
            ).encode("utf-8"))
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(
                {"detail": f"?댁뒪 媛깆떊 ?ㅽ뙣: {str(e)}"},
                ensure_ascii=False,
            ).encode("utf-8"))

