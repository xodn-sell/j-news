import json
import os
import re
from datetime import datetime

import httpx
from google import genai
from google.genai import types

from .db import save_news

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

SYSTEM_INSTRUCTION = """
너는 뉴스 초보자를 위한 뉴스 브리핑 도우미다.
반드시 아래 JSON 형식으로만 답해라.

{
  "items": [
    {
      "title": "...",
      "body": "...",
      "source_label": "...",
      "source_url": "https://...",
      "glossary": [
        {"term": "...", "definition": "..."}
      ]
    }
  ],
  "insight": "..."
}

규칙:
- items는 5개를 목표로 작성한다.
- source_url은 실제 기사 원문 URL을 넣는다.
- glossary는 각 뉴스에 1~2개.
- 문장은 한국어로 간결하게.
- JSON 외 텍스트 금지.
"""

PROMPTS = {
    "us": {
        "general": "오늘의 미국 주요 뉴스를 5개 선정해 요약해줘.",
        "tech": "오늘의 미국 IT/테크 뉴스를 5개 선정해 요약해줘.",
        "economy": "오늘의 미국 경제/금융 뉴스를 5개 선정해 요약해줘.",
        "entertainment": "오늘의 미국 연예/문화/스포츠 뉴스를 5개 선정해 요약해줘.",
    },
    "kr": {
        "general": "오늘의 한국 주요 뉴스를 5개 선정해 요약해줘.",
        "tech": "오늘의 한국 IT/테크 뉴스를 5개 선정해 요약해줘.",
        "economy": "오늘의 한국 경제/금융 뉴스를 5개 선정해 요약해줘.",
        "entertainment": "오늘의 한국 연예/문화/스포츠 뉴스를 5개 선정해 요약해줘.",
    },
}


def resolve_redirect(url: str) -> str:
    """Resolve known redirect URLs to final destination."""
    google_domains = ["google.com/url", "vertexaisearch.cloud.google.com", "news.google.com"]
    if not any(domain in url for domain in google_domains):
        return url
    try:
        with httpx.Client(follow_redirects=True, timeout=10.0) as client:
            resp = client.head(url)
            return str(resp.url)
    except Exception:
        return url


def _extract_json_object(text: str):
    text = (text or "").strip()
    if not text:
        return None

    # 1) direct JSON
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except Exception:
        pass

    # 2) fenced JSON
    fenced = re.sub(r"^```json\s*|^```|```$", "", text, flags=re.IGNORECASE | re.MULTILINE).strip()
    if fenced != text:
        try:
            data = json.loads(fenced)
            if isinstance(data, dict):
                return data
        except Exception:
            pass

    # 3) object fragment
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        fragment = text[start : end + 1]
        try:
            data = json.loads(fragment)
            if isinstance(data, dict):
                return data
        except Exception:
            return None

    return None


def _normalize_payload(payload: dict) -> dict:
    items = payload.get("items")
    if not isinstance(items, list):
        items = []

    normalized_items = []
    for item in items[:5]:
        if not isinstance(item, dict):
            continue
        glossary = item.get("glossary")
        if not isinstance(glossary, list):
            glossary = []
        normalized_glossary = []
        for g in glossary[:2]:
            if isinstance(g, dict):
                normalized_glossary.append(
                    {
                        "term": str(g.get("term", "")).strip(),
                        "definition": str(g.get("definition", "")).strip(),
                    }
                )
        normalized_items.append(
            {
                "title": str(item.get("title", "")).strip(),
                "body": str(item.get("body", "")).strip(),
                "source_label": str(item.get("source_label", "")).strip(),
                "source_url": str(item.get("source_url", "")).strip(),
                "glossary": normalized_glossary,
            }
        )

    return {
        "items": normalized_items,
        "insight": str(payload.get("insight", "")).strip(),
    }


def fetch_and_store(region: str, category: str = "general"):
    """Fetch briefing via Gemini and save into DB."""
    print(f"[{datetime.now()}] {region} [{category}] fetching...")

    if not GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is missing")

    prompt = PROMPTS[region][category]

    client = genai.Client(api_key=GEMINI_API_KEY)
    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            tools=[types.Tool(google_search=types.GoogleSearch())],
            system_instruction=SYSTEM_INSTRUCTION,
        ),
    )

    payload = _extract_json_object(response.text or "")
    if payload is None:
        raise RuntimeError("Model response was not valid JSON")

    data = _normalize_payload(payload)

    for item in data.get("items", []):
        url = item.get("source_url", "")
        if url:
            item["source_url"] = resolve_redirect(url)

    full_json_str = json.dumps(data, ensure_ascii=False)
    sources_json = json.dumps(
        [
            {"title": item.get("source_label", ""), "link": item.get("source_url", "")}
            for item in data.get("items", [])
        ],
        ensure_ascii=False,
    )

    save_news(region, category, full_json_str, sources_json)
    print(f"[{datetime.now()}] {region} [{category}] saved")

