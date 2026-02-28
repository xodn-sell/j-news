import os
import re
import json
from datetime import datetime
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor, as_completed
from google import genai
from google.genai import types
from .db import save_news


GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

SYSTEM_INSTRUCTION = """너는 뉴스 요약 봇이다.
절대 규칙:
- 인사말 금지 (알겠습니다, 제공해 드리겠습니다, 죄송합니다 등)
- 서론/부연 설명 금지
- 반드시 유효한 JSON만 출력
- 한국어로 작성
- 출처 URL은 반드시 실제 뉴스 기사의 원본 URL을 포함 (리다이렉트 URL 금지)
- 원문 표현을 그대로 사용하지 말고, 팩트만 간결하게 전달
- glossary는 뉴스에서 일반인이 이해하기 어려운 전문 용어 1~2개를 골라 쉽게 설명"""

PROMPTS = {
    "us": {
        "general": "오늘의 미국 주요 뉴스(정치, 사회, 국제 등) 5개를 검색해서 아래 JSON 형식 그대로 출력해.",
        "tech": """오늘의 미국 IT/테크/기술 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 기술 관련 뉴스만 포함할 것: AI 서비스/제품, 소프트웨어, 하드웨어, 반도체, 스타트업, 빅테크(Apple, Google, Microsoft, Meta, Amazon, Tesla 등), 사이버보안, 클라우드 등.
순수과학 연구(물리, 화학, 생물학 발견 등)나 정치/경제/연예/스포츠 뉴스는 절대 포함하지 마.""",
        "economy": """오늘의 미국 경제/금융 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 경제 관련 뉴스만 포함할 것: 주식시장, 연준(Fed), 금리, 환율, GDP, 고용지표, 기업실적, 부동산, 무역, 관세 등.
정치/테크/연예 뉴스는 절대 포함하지 마.""",
        "entertainment": """오늘의 미국 연예/문화 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 엔터테인먼트 관련 뉴스만 포함할 것: 할리우드, 영화, 음악, TV/스트리밍, 셀럽, 시상식 등.
스포츠 경기 결과/이적 뉴스와 정치/경제/테크 뉴스는 절대 포함하지 마.""",
        "sports": """오늘의 미국 스포츠 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 스포츠 관련 뉴스만 포함할 것: NFL, NBA, MLB, NHL, MLS 등 주요 리그 경기 결과, 이적, 선수 동향, 감독 교체 등.
정치/경제/연예/테크 뉴스는 절대 포함하지 마.""",
        "politics": """오늘의 미국 정치 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 정치 관련 뉴스만 포함할 것: 백악관, 의회, 상원/하원, 정당, 대통령 정책, 외교, 선거 등.
경제/테크/연예/스포츠 뉴스는 절대 포함하지 마.""",
        "health": """오늘의 미국 건강/의료 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 건강/의료 관련 뉴스만 포함할 것: FDA 승인, 신약 개발, 의료 정책, 질병 동향, 공중보건, 건강 생활 팁 등.
순수과학 연구나 정치/경제/연예 뉴스는 절대 포함하지 마.""",
        "science": """오늘의 미국 과학/연구 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 순수과학 관련 뉴스만 포함할 것: NASA 우주 탐사, 물리학/화학/생물학 연구 성과, 기초과학 발견, 기후과학, 고고학 등.
IT 제품/서비스나 스포츠/연예/정치 뉴스는 절대 포함하지 마.""",
    },
    "kr": {
        "general": "오늘의 한국 주요 뉴스(정치, 사회, 국제 등) 5개를 검색해서 아래 JSON 형식 그대로 출력해.",
        "tech": """오늘의 한국 IT/테크/기술 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 기술 관련 뉴스만 포함할 것: AI 서비스/제품, 반도체, 삼성전자, SK하이닉스, 네이버, 카카오, 스타트업, 통신사, 게임 등.
순수과학 연구나 정치/경제/연예/스포츠 뉴스는 절대 포함하지 마.""",
        "economy": """오늘의 한국 경제/금융 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 경제 관련 뉴스만 포함할 것: 코스피, 코스닥, 한국은행, 금리, 환율, 부동산, 기업실적, 수출입, 물가 등.
정치/테크/연예 뉴스는 절대 포함하지 마.""",
        "entertainment": """오늘의 한국 연예/문화 분야 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 엔터테인먼트 관련 뉴스만 포함할 것: K-pop, 드라마, 영화, 아이돌, 예능, 배우/가수 동향 등.
스포츠 경기 결과/이적 뉴스와 정치/경제/테크 뉴스는 절대 포함하지 마.""",
        "sports": """오늘의 한국 스포츠 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 스포츠 관련 뉴스만 포함할 것: KBO 야구, K리그 축구, 해외파 선수(손흥민, 이강인, 류현진 등), 국가대표, 국제대회 등.
정치/경제/연예/테크 뉴스는 절대 포함하지 마.""",
        "politics": """오늘의 한국 정치 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 정치 관련 뉴스만 포함할 것: 국회, 대통령실, 여야 정당, 장관/공직자, 정책, 외교, 선거 등.
경제/테크/연예/스포츠 뉴스는 절대 포함하지 마.""",
        "health": """오늘의 한국 건강/의료 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 건강/의료 관련 뉴스만 포함할 것: 신약 승인, 의료 정책, 건강보험, 질병 동향, 공중보건, 건강 생활 팁 등.
순수과학 연구나 정치/경제/연예 뉴스는 절대 포함하지 마.""",
        "science": """오늘의 한국 과학/연구 뉴스만 5개를 검색해서 아래 JSON 형식 그대로 출력해.
반드시 순수과학 관련 뉴스만 포함할 것: KAIST, IBS, 한국천문연구원 등 연구기관 성과, 우주 탐사, 물리/화학/생물학 발견, 기후과학 등.
IT 제품/서비스나 스포츠/연예/정치 뉴스는 절대 포함하지 마.""",
    }
}

FORMAT_INSTRUCTION = """
반드시 아래 JSON 형식으로만 출력해. 다른 텍스트 없이 JSON만 출력할 것.

{
  "items": [
    {
      "title": "뉴스 제목",
      "body": "요약 1~2문장 (최대 80자)",
      "source_label": "매체명",
      "source_url": "https://실제기사URL",
      "glossary": [
        {"term": "전문용어", "definition": "쉬운 설명 1~2문장"}
      ]
    }
  ],
  "insight": "시사점 1~2문장"
}

규칙:
- items는 반드시 5개
- glossary는 각 뉴스당 0~2개 (어려운 용어가 없으면 빈 배열)
- source_url은 실제 기사 원본 URL
- JSON 외에 다른 텍스트 출력 금지
"""


def extract_json(raw: str) -> dict:
    """Gemini 응답에서 JSON을 추출"""
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    match = re.search(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', raw)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    match = re.search(r'\{[\s\S]*\}', raw)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass

    raise ValueError(f"JSON 파싱 실패: {raw[:200]}")


def _resolve_redirect(url: str, timeout: int = 3) -> str:
    """리다이렉트 URL을 따라가 최종 URL을 반환. 실패 시 원본 반환."""
    if "vertexaisearch" not in url:
        return url
    try:
        req = Request(url, method="HEAD")
        req.add_header("User-Agent", "Mozilla/5.0")
        resp = urlopen(req, timeout=timeout)
        final_url = resp.url
        if final_url and "vertexaisearch" not in final_url:
            return final_url
    except Exception:
        pass
    return url


def _resolve_all_urls(data: dict) -> dict:
    """items의 리다이렉트 URL을 병렬로 실제 URL로 교체"""
    items = data.get("items", [])
    redirect_items = [(i, item) for i, item in enumerate(items)
                      if "vertexaisearch" in item.get("source_url", "")]

    if not redirect_items:
        return data

    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {
            executor.submit(_resolve_redirect, item["source_url"]): idx
            for idx, item in redirect_items
        }
        for future in as_completed(futures, timeout=5):
            idx = futures[future]
            try:
                resolved = future.result()
                old_url = items[idx]["source_url"]
                items[idx]["source_url"] = resolved
                print(f"  URL [{idx}]: {old_url[:50]}... -> {resolved[:80]}")
            except Exception as e:
                print(f"  URL [{idx}] resolve failed: {e}")

    return data


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

    data = extract_json(raw)
    if "items" not in data:
        raise ValueError("응답에 items 필드가 없습니다")

    data = _resolve_all_urls(data)

    summary = json.dumps(data, ensure_ascii=False)
    sources = json.dumps(
        [{"title": item.get("source_label", ""), "link": item.get("source_url", "")}
         for item in data.get("items", []) if item.get("source_url")],
        ensure_ascii=False,
    )

    save_news(region, category, summary, sources)
    print(f"[{datetime.now()}] {region} [{category}] 뉴스 저장 완료")
