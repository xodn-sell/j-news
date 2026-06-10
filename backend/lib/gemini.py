import os
import re
import json
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor, as_completed
from google import genai
from google.genai import types
from .db import save_news, get_today_news, update_dialogue


GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

SYSTEM_INSTRUCTION = """너는 뉴스 큐레이터이자 학습 콘텐츠 제작자다. 뉴스를 보고 싶지만 뭘 봐야 할지 모르는 한국 독자를 위해 오늘의 핵심 뉴스를 선별하고 쉽게 전달한다.
절대 규칙:
- 인사말 금지 (알겠습니다, 제공해 드리겠습니다, 죄송합니다 등)
- 서론·부연 설명 금지
- 반드시 유효한 JSON만 출력
- 한국어로 작성
- 원문 그대로 복사 금지 — 팩트만 간결하게 재구성
- glossary: 일반인이 이해하기 어려운 전문 용어가 있을 때만 0~3개 설명 (없으면 빈 배열 [])
- why_matters: 독자 삶·경제·사회와의 연결고리를 2~3문장으로 설명. 뉴스 해석 기반이라 추측 최소화
- quiz: 해당 뉴스의 body 또는 why_matters에서 답을 찾을 수 있는 문제만 출제. 외부 지식·추측 요구 금지
- quiz answer_index: options 배열의 정답 인덱스 (0-based 정수)
- suggested_questions: AI 튜터가 독자에게 제안하는 후속 질문 3개. 뉴스 맥락에 맞는 자연스러운 한국어"""

PROMPT = """오늘 한국 독자가 반드시 알아야 할 뉴스 7개를 검색해서 아래 JSON 형식으로 출력해.

[선택 기준 — 우선순위 순]
1. 정치·외교 — 한국·미국·글로벌 주요 정치 이슈, 한국 독자 생활에 직결되는 것 우선
2. 경제·금융 — 환율, 금리, 주식, 부동산, 물가, 고용 중 오늘 가장 움직임이 큰 것
3. 사회·사건 — 한국 또는 세계에서 오늘 가장 많이 회자되는 사건·사고·정책
4. 기술·산업 — AI, 반도체, 빅테크 등 일반인 생활과 연결되는 기술 뉴스

[반드시 지킬 규칙]
- 스포츠·연예·순수과학은 7개 중 최대 1개만 허용 (화제성이 압도적일 때만)
- 한국 뉴스 3~4개 + 해외 뉴스 3~4개 균형 유지
- 같은 사건·인물을 다른 각도로 중복 선택 금지
- 홍보성·광고성·낚시성 기사 제외
- "오늘 모르면 내일 대화에서 뒤처지는" 뉴스 우선"""

FORMAT_INSTRUCTION = """
반드시 아래 JSON 형식으로만 출력해. 다른 텍스트 없이 JSON만 출력할 것.

{
  "items": [
    {
      "title": "뉴스 제목 (원문 제목 그대로 말고, 핵심을 담은 명확한 제목으로)",
      "body": "무슨 일이 왜 일어났는지 2~3문장으로 작성. 독자가 원문 안 봐도 이해할 수 있게. (최대 150자)",
      "source_label": "매체명",
      "source_url": "https://실제기사URL",
      "glossary": [
        {"term": "전문용어", "definition": "쉬운 설명 1~2문장"}
      ],
      "why_matters": "이 뉴스가 독자의 삶·경제·사회에 왜 중요한지 2~3문장. 연결고리와 실질적 영향 중심으로.",
      "quiz": [
        {
          "question": "이 뉴스에서 답을 찾을 수 있는 질문",
          "type": "ox",
          "options": ["O", "X"],
          "answer_index": 0,
          "explanation": "정답 해설 1문장"
        },
        {
          "question": "이 뉴스에서 답을 찾을 수 있는 또 다른 질문",
          "type": "mc",
          "options": ["보기1", "보기2", "보기3", "보기4"],
          "answer_index": 2,
          "explanation": "정답 해설 1문장"
        }
      ],
      "suggested_questions": [
        "쉽게 설명해줘",
        "왜 중요해?",
        "비슷한 과거 사례는?"
      ]
    }
  ],
  "insight": {
    "headline": "오늘 뉴스를 꿰뚫는 한 줄 제목 (15자 이내, 임팩트 있게)",
    "summary": "오늘 이 뉴스들이 왜 함께 등장했는가에 대한 맥락 2문장. 단순 나열 금지, 흐름과 배경 중심으로",
    "points": [
      "오늘 가장 중요한 변화나 사실 (한 문장)",
      "뉴스들의 연결고리나 공통 트렌드 (한 문장)",
      "독자 일상·경제·삶에 미치는 영향 (한 문장)"
    ],
    "outlook": "앞으로 주목할 변수 또는 다음 시사점 1문장",
    "mood": "optimistic 또는 cautious 또는 alarming 또는 neutral"
  }
}

규칙:
- items 반드시 7개
- body: 팩트 중심 2~3문장, 최대 150자
- glossary: 뉴스당 0~3개 (어려운 용어 없으면 빈 배열 [])
- source_url: 실제 기사 원본 URL
- why_matters: 뉴스당 반드시 작성. 2~3문장. 독자 삶과의 연결 중심.
- quiz: 뉴스당 반드시 2개. 각 문제는 해당 뉴스 body/why_matters에서 답을 찾을 수 있어야 함. 외부 지식 요구 금지.
- quiz[].type: "ox" 또는 "mc" 중 하나
- quiz[].options: ox는 ["O","X"], mc는 보기 4개 문자열 배열
- quiz[].answer_index: options 배열의 정답 인덱스 (0부터 시작하는 정수). 반드시 포함.
- quiz[].explanation: 정답 해설 1문장. 반드시 포함.
- suggested_questions: 뉴스당 반드시 3개 문자열. 뉴스 맥락에 맞게 자연스러운 한국어로.
- insight.headline: 15자 이내
- insight.points: 반드시 3개, 각각 한 문장
- insight.mood: optimistic / cautious / alarming / neutral 중 하나
- JSON 외 다른 텍스트 출력 금지
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


def _extract_titles_from_summaries(summaries: list) -> list:
    """저장된 summary 목록에서 뉴스 제목 추출"""
    titles = []
    for raw_summary in summaries:
        try:
            parsed = json.loads(raw_summary)
            for item in parsed.get("items", []):
                title = item.get("title", "").strip()
                if title:
                    titles.append(title)
        except Exception:
            pass
    return titles


DIALOGUE_SYSTEM = """너는 라디오 뉴스 팟캐스트 작가다. 진행자 두 명의 자연스러운 한국어 대화를 만든다.

진행자 A (지음): 친근하고 호기심 많은 진행자. 뉴스를 소개하고 질문을 던짐. 반말톤("~지", "~네", "~야").
진행자 B (소나): 침착한 분석가. 맥락과 의미를 설명하고 균형잡힌 시각 제공. 반말톤.

대화 규칙:
- A가 뉴스를 던지면 B가 받아서 해설하는 흐름
- 한 발화는 1~3문장. 너무 길지 않게. 자연스러운 구어체.
- 7개 뉴스를 차례로 다루고 마지막에 오늘의 인사이트로 마무리
- 총 40~55턴 (약 5~7분 분량)
- 인사: A가 "오늘 뉴스 같이 보자!" 같은 짧은 오프닝
- 마무리: B가 "오늘은 여기까지!" 같은 짧은 클로징
- "음", "어", "그러게" 같은 자연스러운 추임새 OK"""

DIALOGUE_PROMPT = """아래 오늘의 뉴스 7편과 인사이트를 보고, 두 진행자의 자연스러운 라디오 대화 스크립트를 만들어.

[뉴스 데이터]
{news_json}

반드시 아래 JSON 배열 형식으로만 출력:
[
  {{"speaker": "A", "text": "오늘 뉴스 같이 보자!"}},
  {{"speaker": "B", "text": "응 시작해보자."}},
  ...
]

규칙:
- speaker는 "A" 또는 "B"만 사용
- JSON 외 다른 텍스트 출력 금지
- 40~55턴
- 한국어 구어체"""


def generate_dialogue(news_data: dict) -> list:
    """뉴스 데이터로 2인 대화 스크립트 생성. 실패 시 빈 리스트."""
    try:
        news_json = json.dumps(news_data, ensure_ascii=False)
        prompt = DIALOGUE_PROMPT.format(news_json=news_json)
        client = genai.Client(api_key=GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=DIALOGUE_SYSTEM,
                temperature=0.9,
                max_output_tokens=4000,
            ),
        )
        raw = (response.text or "").strip()
        if not raw:
            return []
        # JSON 추출
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            match = re.search(r"\[[\s\S]*\]", raw)
            if not match:
                return []
            parsed = json.loads(match.group(0))
        if not isinstance(parsed, list):
            return []
        # speaker/text 검증
        cleaned = []
        for turn in parsed:
            if not isinstance(turn, dict):
                continue
            sp = turn.get("speaker")
            tx = (turn.get("text") or "").strip()
            if sp in ("A", "B") and tx:
                cleaned.append({"speaker": sp, "text": tx})
        return cleaned
    except Exception as e:
        print(f"  dialogue 생성 실패: {e}")
        return []


def fetch_and_store(region: str = "world", category: str = "general"):
    """Gemini로 뉴스 요약을 생성하고 DB에 저장"""
    KST = timezone(timedelta(hours=9))
    now = datetime.now(KST)
    today_str = now.strftime("%Y-%m-%d")
    print(f"[{now}] {region} [{category}] 뉴스 가져오는 중 (KST 기준 날짜: {today_str})...")

    # 오늘 이미 저장된 뉴스 제목 추출 (중복 방지)
    exclude_instruction = ""
    covered_titles = _extract_titles_from_summaries(get_today_news(region, category))
    if covered_titles:
        titles_str = "\n".join(f"- {t}" for t in covered_titles)
        exclude_instruction = (
            f"\n\n절대 금지: 아래 이미 다룬 뉴스와 동일하거나 유사한 주제는 포함하지 마. "
            f"같은 사건·인물·이슈를 다른 각도로 다루는 것도 금지.\n{titles_str}"
        )

    # 날짜 지침 (KST 기준 당일 뉴스만)
    date_instruction = (
        f"\n\n중요: 반드시 한국시간(KST) 기준 오늘({today_str}) 날짜의 뉴스만 검색해서 출력해. "
        f"어제({(now - timedelta(days=1)).strftime('%Y-%m-%d')}) 이전 뉴스는 절대 포함하지 마. "
        f"뉴스 발행일이 {today_str}인 것만 선택할 것."
    )

    prompt = PROMPT + date_instruction + exclude_instruction + FORMAT_INSTRUCTION

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

    # 배치 내 중복 제거 (동일 제목)
    seen_titles = set()
    unique_items = []
    for item in data.get("items", []):
        title = item.get("title", "").strip()
        if title and title not in seen_titles:
            seen_titles.add(title)
            unique_items.append(item)
    data["items"] = unique_items

    # 저장 직전 DB 재확인 — 생성 중 추가된 뉴스와도 중복 제거
    fresh_titles = set(_extract_titles_from_summaries(get_today_news(region, category)))
    data["items"] = [
        item for item in data["items"]
        if item.get("title", "").strip() not in fresh_titles
    ]
    if not data["items"]:
        print(f"[{now}] {region} [{category}] 모든 뉴스가 중복 — 저장 건너뜀")
        return

    summary = json.dumps(data, ensure_ascii=False)
    sources = json.dumps(
        [{"title": item.get("source_label", ""), "link": item.get("source_url", "")}
         for item in data.get("items", []) if item.get("source_url")],
        ensure_ascii=False,
    )

    # 1) 뉴스 먼저 저장 (dialogue 생성 실패/타임아웃 대비)
    save_news(region, category, summary, sources, None)
    print(f"[{datetime.now(KST)}] {region} [{category}] 뉴스 저장 완료 ({len(data['items'])}건)")

    # 2) dialogue 생성 후 같은 row를 update
    #    별도 try로 감싸서 dialogue 실패가 cron 전체를 죽이지 않게 함
    try:
        dialogue_list = generate_dialogue(data)
        if dialogue_list:
            # 방금 저장한 row를 찾아 update (region+category의 최신)
            from .db import get_latest_news
            latest = get_latest_news(region, category)
            if latest and latest.get("id"):
                update_dialogue(latest["id"], json.dumps(dialogue_list, ensure_ascii=False))
                print(f"  대화 {len(dialogue_list)}턴 저장 완료")
    except Exception as e:
        print(f"  dialogue 생성/저장 스킵: {e}")
