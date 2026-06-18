"""개념 학습 엔드포인트 — 노출/복습 기록 + 진척 조회.

POST /api/concepts   body { action, uid, ... }
  - action="exposure": { uid, concept_ids: [int, ...] }  카드 노출 시 패시브 기록
  - action="review":   { uid, concept_id: int, correct: bool }  퀴즈/복습 결과
GET  /api/concepts?uid=<uid>   → 진척 시각화용 집계 (완독보너스 자리)
"""

import json
import os
import sys
import time
from collections import defaultdict
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.concepts_db import (
    init_concepts_db,
    record_exposure,
    record_review,
    get_user_progress,
)

ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "").split(",")

RATE_LIMIT = 60
RATE_WINDOW = 60
_request_counts = defaultdict(list)

MAX_EXPOSURE_IDS = 50  # 1회 요청당 노출 기록 상한


def _get_cors_origin(request_origin: str) -> str:
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == [""]:
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
        self.send_header("Vary", "Origin")

    def _json_response(self, status_code: int, payload: dict, extra_headers=None):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self._send_cors_headers()
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
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

    def _uid(self, body: dict) -> str:
        uid = (body.get("uid") or "").strip()
        if uid:
            return uid
        forwarded = self.headers.get("X-Forwarded-For", "")
        client_ip = forwarded.split(",")[0].strip() if forwarded else self.client_address[0]
        return f"ip:{client_ip}"

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self._check_rate_limit():
            self._json_response(429, {"detail": "Too many requests."},
                                extra_headers={"Retry-After": str(RATE_WINDOW)})
            return
        params = parse_qs(urlparse(self.path).query)
        uid = (params.get("uid", [""])[0]).strip()
        if not uid:
            self._json_response(400, {"detail": "uid is required"})
            return
        try:
            init_concepts_db()
            self._json_response(200, get_user_progress(uid))
        except Exception as e:
            self._json_response(500, {"detail": f"progress 조회 실패: {str(e)[:120]}"})

    def do_POST(self):
        if self._check_rate_limit():
            self._json_response(429, {"detail": "Too many requests."},
                                extra_headers={"Retry-After": str(RATE_WINDOW)})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length > 0 else b""
            body = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            self._json_response(400, {"detail": "Invalid JSON body"})
            return

        action = (body.get("action") or "").strip()
        uid = self._uid(body)

        try:
            init_concepts_db()
        except Exception as e:
            self._json_response(500, {"detail": f"DB init 실패: {str(e)[:120]}"})
            return

        if action == "exposure":
            ids = body.get("concept_ids") or []
            if not isinstance(ids, list):
                self._json_response(400, {"detail": "concept_ids must be a list"})
                return
            clean = []
            for x in ids[:MAX_EXPOSURE_IDS]:
                try:
                    clean.append(int(x))
                except (TypeError, ValueError):
                    continue
            recorded = 0
            for cid in clean:
                try:
                    record_exposure(uid, cid)
                    recorded += 1
                except Exception:
                    continue
            self._json_response(200, {"recorded": recorded})

        elif action == "review":
            try:
                concept_id = int(body.get("concept_id"))
            except (TypeError, ValueError):
                self._json_response(400, {"detail": "concept_id (int) is required"})
                return
            correct = bool(body.get("correct"))
            try:
                record_review(uid, concept_id, correct)
            except Exception as e:
                self._json_response(500, {"detail": f"review 기록 실패: {str(e)[:120]}"})
                return
            # 갱신된 진척 함께 반환 → 앱이 즉시 viz 업데이트
            self._json_response(200, {"ok": True, "progress": get_user_progress(uid)})

        else:
            self._json_response(400, {"detail": "action must be 'exposure' or 'review'"})
