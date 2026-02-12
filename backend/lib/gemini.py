import os
import re
import json
import httpx
from datetime import datetime
from google import genai
from google.genai import types
from .db import save_news


GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

SYSTEM_INSTRUCTION = """너는 뉴스 요약 봇이다.
절대 규칙:
- 인사말 금지 (알겠습니다, 제공해 드리겠습니다, 죄송합니다 등)
- 서론/부연 설명 금지
- 첫 줄부터 바로 "1. **제목**" 으로 시작
- 지정된 형식만 출력
- 한국어로 작성
- 출처 URL은 반드시 실제 뉴스 기사의 원본 URL을 포함 (리다이렉트 URL 금지)
- 원문 표현을 그대로 사용하지 말고, 팩트만 간결하게 전달"""

PROMPTS = {
    "us": {
        "general": "오늘의 미국 주요 뉴스(정치, 사회, 국제 등) 5개를 검색해서 아래 형식 그대로 출력해.",
        "tech": """오늘의 미국 IT/테크/기술 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 기술 관련 뉴스만 포함할 것: AI, 소프트웨어, 하드웨어, 반도체, 스타트업, 빅테크(Apple, Google, Microsoft, Meta, Amazon, Tesla 등), 사이버보안, 클라우드 등.
정치/경제/연예 뉴스는 절대 포함하지 마.""",
        "economy": """오늘의 미국 경제/금융 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 경제 관련 뉴스만 포함할 것: 주식시장, 연준(Fed), 금리, 환율, GDP, 고용지표, 기업실적, 부동산, 무역, 관세 등.
정치/테크/연예 뉴스는 절대 포함하지 마.""",
        "entertainment": """오늘의 미국 연예/문화/스포츠 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 엔터테인먼트 관련 뉴스만 포함할 것: 할리우드, 영화, 음악, TV, 스포츠(NFL, NBA, MLB 등), 셀럽, 시상식 등.
정치/경제/테크 뉴스는 절대 포함하지 마.""",
    },
    "kr": {
        "general": "오늘의 한국 주요 뉴스(정치, 사회, 국제 등) 5개를 검색해서 아래 형식 그대로 출력해.",
        "tech": """오늘의 한국 IT/테크/기술 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 기술 관련 뉴스만 포함할 것: AI, 반도체, 삼성전자, SK하이닉스, 네이버, 카카오, 스타트업, 통신사, 게임 등.
정치/경제/연예 뉴스는 절대 포함하지 마.""",
        "economy": """오늘의 한국 경제/금융 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 경제 관련 뉴스만 포함할 것: 코스피, 코스닥, 한국은행, 금리, 환율, 부동산, 기업실적, 수출입, 물가 등.
정치/테크/연예 뉴스는 절대 포함하지 마.""",
        "entertainment": """오늘의 한국 연예/문화/스포츠 분야 뉴스만 5개를 검색해서 아래 형식 그대로 출력해.
반드시 엔터테인먼트 관련 뉴스만 포함할 것: K-pop, 드라마, 영화, 아이돌, 예능, KBO, K리그, 셀럽 등.
정치/경제/테크 뉴스는 절대 포함하지 마.""",
    }
}

FORMAT_INSTRUCTION = """
각 뉴스의 실제 원본 기사 URL을 반드시 포함해.

1. **제목**
요약 1~2문장 (최대 80자)
출처: 매체명 (https://실제기사URL)

... (반복) ...

📌 시사점: 1~2문장
"""


def clean_summary(raw: str) -> str:
    match = re.search(r'1\.\s*\*\*', raw)
    if match:
        return raw[match.start():]
    return raw


def parse_sources_json(text: str) -> str:
    sources = []
    pattern = re.compile(r'출처:\s*(.+?)\s*\((https?://[^\s\)]+)\)')
    for m in pattern.finditer(text):
        sources.append({"title": m.group(1).strip(), "link": m.group(2).strip()})
    return json.dumps(sources, ensure_ascii=False)


def resolve_redirect(url: str) -> str:
    """Google 리다이렉트 URL을 실제 URL로 해소"""
    google_domains = ["google.com/url", "vertexaisearch.cloud.google.com", "news.google.com"]
    if not any(domain in url for domain in google_domains):
        return url
    try:
        with httpx.Client(follow_redirects=True, timeout=10.0) as c:
            resp = c.head(url)
            return str(resp.url)
    except Exception:
        return url


def validate_url(url: str) -> bool:
    """HTTP HEAD 요청으로 URL 존재 여부 검증"""
    try:
        with httpx.Client(follow_redirects=True, timeout=10.0) as c:
            resp = c.head(url)
            return resp.status_code < 400
    except Exception:
        return False


def fetch_and_store(region: str, category: str = "general"):
    """Gemini로 뉴스 요약을 생성하고 DB에 저장"""
    print(f"[{datetime.now()}] {region} [{category}] 뉴스 가져오는 중...")

    prompt = PROMPTS[region][category] + FORMAT_INSTRUCTION

    client = genai.Client(api_key=GEMINI_API_KEY)
    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            tools=[types.Tool(google_search=types.GoogleSearch())],
            system_instruction=SYSTEM_INSTRUCTION,
        ),
    )
    raw = response.text or ""
    summary = clean_summary(raw)

    # 리다이렉트 URL 해소 및 검증
    url_pattern = re.compile(r'\((https?://[^\s\)]+)\)')
    urls = url_pattern.findall(summary)
    for url in urls:
        real_url = resolve_redirect(url)
        if real_url != url:
            summary = summary.replace(url, real_url)
            url = real_url
        # URL 존재 여부 검증 — 깨진 URL은 제거하고 출처 텍스트만 남김
        if not validate_url(url):
            summary = summary.replace(f" ({url})", "")
            summary = summary.replace(f"({url})", "")

    sources = parse_sources_json(summary)
    save_news(region, category, summary, sources)
    print(f"[{datetime.now()}] {region} [{category}] 뉴스 저장 완료")
