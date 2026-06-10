import json
import os
import sys
import time
from collections import defaultdict
from http.server import BaseHTTPRequestHandler

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from google import genai
from google.genai import types

ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "").split(",")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

RATE_LIMIT = 30
RATE_WINDOW = 60
_request_counts = defaultdict(list)

MAX_HISTORY = 12  # 마지막 12턴까지만 컨텍스트 유지
MAX_MESSAGE_LEN = 500

SYSTEM_INSTRUCTION = """너는 지음. 사용자와 함께 뉴스를 읽고 같이 생각을 넓혀가는 AI 토론 친구다.

대화 원칙:
- 한국어, 친근한 반말 톤 ("~야", "~지", "~네")
- 1회 답변은 2~4문장 (장황 금지)
- 균형잡힌 시각: 한쪽 의견만 강요하지 않음. 찬반 모두 보여주기
- 사용자가 의견 물으면 양쪽 입장 짚어주고 "너는 어떻게 봐?" 식으로 되묻기
- 뉴스 사실 모르면 솔직히 "그건 잘 모르겠어" 인정. 추측하지 말 것
- 정치/종교/민감 이슈는 중립 유지. 단정 금지
- 이모지 1~2개까지만 사용 (남발 금지)
- 뉴스 맥락(왜 중요한지 포함)을 바탕으로 구체적으로 답할 것. 뉴스와 동떨어진 추상적 답변 금지
- 용어 설명이 뉴스 컨텍스트에 제공된 경우, 그 용어가 대화에 나오면 쉽고 자연스럽게 풀어 설명할 것
- 소크라테스식 접근: 답변 끝에 사용자 사고를 넓히는 후속 질문이나 다른 관점을 가볍게 한 줄 던져. 단 매번 강제하지 말고, 자연스러울 때만."""


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

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        if self._check_rate_limit():
            self._json_response(
                429,
                {"detail": "Too many requests. Please retry shortly."},
                extra_headers={"Retry-After": str(RATE_WINDOW)},
            )
            return

        if not GEMINI_API_KEY:
            self._json_response(500, {"detail": "GEMINI_API_KEY not configured"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length > 0 else b""
            body = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            self._json_response(400, {"detail": "Invalid JSON body"})
            return

        message = (body.get("message") or "").strip()
        if not message:
            self._json_response(400, {"detail": "message is required"})
            return
        if len(message) > MAX_MESSAGE_LEN:
            self._json_response(400, {"detail": f"message too long (max {MAX_MESSAGE_LEN})"})
            return

        news_context = body.get("news_context") or {}
        history = body.get("history") or []
        if not isinstance(history, list):
            history = []
        history = history[-MAX_HISTORY:]

        contents = []

        # 뉴스 컨텍스트를 첫 turn으로 주입
        if isinstance(news_context, dict) and news_context:
            title = (news_context.get("title") or "").strip()
            body_text = (news_context.get("body") or "").strip()
            if title or body_text:
                ctx_lines = ["[지금 보고 있는 뉴스]"]
                if title:
                    ctx_lines.append(f"제목: {title}")
                if body_text:
                    ctx_lines.append(f"내용: {body_text}")

                why_matters = (news_context.get("why_matters") or "").strip()
                if why_matters:
                    ctx_lines.append(f"왜 중요한가: {why_matters}")

                glossary = news_context.get("glossary")
                if isinstance(glossary, list) and glossary:
                    terms = []
                    for item in glossary:
                        if not isinstance(item, dict):
                            continue
                        term = (item.get("term") or "").strip()
                        definition = (item.get("definition") or "").strip()
                        if term and definition:
                            terms.append(f"{term} - {definition}")
                    if terms:
                        ctx_lines.append(f"용어: {' / '.join(terms)}")

                ctx_lines.append("\n이 뉴스에 대해 사용자랑 자연스럽게 대화 시작해.")
                context_msg = "\n".join(ctx_lines)
                contents.append(types.Content(role="user", parts=[types.Part(text=context_msg)]))
                contents.append(types.Content(role="model", parts=[types.Part(text="응, 이 뉴스 같이 봤지! 궁금한 거 있으면 편하게 물어봐.")]))

        # 이전 대화 히스토리
        for turn in history:
            if not isinstance(turn, dict):
                continue
            role = turn.get("role")
            content = (turn.get("content") or "").strip()
            if not content:
                continue
            if role == "user":
                contents.append(types.Content(role="user", parts=[types.Part(text=content)]))
            elif role == "assistant" or role == "model":
                contents.append(types.Content(role="model", parts=[types.Part(text=content)]))

        # 최신 유저 메시지
        contents.append(types.Content(role="user", parts=[types.Part(text=message)]))

        try:
            client = genai.Client(api_key=GEMINI_API_KEY)
            response = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_INSTRUCTION,
                    temperature=0.8,
                    max_output_tokens=400,
                ),
            )
            reply = (response.text or "").strip()
            if not reply:
                reply = "잠깐, 다시 한번 말해줄래?"
        except Exception as e:
            self._json_response(500, {"detail": f"AI 응답 실패: {str(e)[:120]}"})
            return

        self._json_response(200, {"reply": reply})
