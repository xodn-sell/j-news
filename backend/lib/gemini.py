import os
import re
import json
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor, as_completed
from google import genai
from google.genai import types
from .db import save_news, get_today_news, update_dialogue, update_summary, get_conn
from .concepts_db import init_concepts_db, upsert_concept, add_occurrence


GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-2.5-flash"

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
- quiz ox 타입은 반드시 참/거짓 판단 평서문 (의문형 금지). 의문형이면 mc로 내거나 평서문으로 변환
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
          "question": "참 또는 거짓으로 판단 가능한 평서문 (예: '정부의 외평채 발행은 원화 가치를 높이는 효과가 있다.')",
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
- **type="ox" 문항의 question은 반드시 참/거짓으로 판단 가능한 평서문(서술문). 의문형·개방형 절대 금지.**
  - 올바름(O): "정부의 외평채 발행은 원화 가치를 높이는 효과가 있다."
  - 잘못됨(X): "원화 가치는 어떻게 될까?", "무엇이 원인일까?" (이런 의문형은 ox로 내지 말 것 — mc로 내거나 평서문으로 바꿀 것)
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
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=DIALOGUE_SYSTEM,
                temperature=0.9,
                max_output_tokens=4000,
                thinking_config=types.ThinkingConfig(thinking_budget=0),
            ),
        )
        raw = (response.text or "").strip()
        if not raw and response.candidates:
            parts = response.candidates[0].content.parts if response.candidates[0].content else []
            text_parts = [p.text for p in parts if hasattr(p, "text") and p.text]
            raw = "\n".join(text_parts).strip()
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


CONCEPT_SYSTEM = """너는 시사 배경지식 큐레이터다. 뉴스에서 독자가 '알아두면 다음 뉴스 이해가 쉬워지는' 핵심 개념을 골라 정규화한다.

개념 = 인물(person) / 기관·단체(org) / 사건·정책(event) / 지명·국가(place) / 용어(term).

절대 규칙:
- 인사말·서론·부연 금지. 유효한 JSON 배열만 출력.
- 한국어로 작성.
- slug: 개념의 영구 식별자. 소문자 영문 kebab-case (예: "g7-summit", "interest-rate", "kim-jong-un"). 같은 개념은 표면형이 달라도 반드시 같은 slug.
- 일회성·지엽적 고유명사 제외. 반복 등장하거나 배경지식 가치 있는 것만.
- 너무 일반적인 단어(예: 정부, 사람, 오늘) 제외.
- 제공된 glossary 용어는 우선 포함하되 같은 정규화 규칙 적용.
- definition: 1~2문장, 뉴스 없이도 이해되는 독립 설명."""

CONCEPT_PROMPT = """아래 오늘의 뉴스에서 핵심 개념을 추출해 정규화하고, 각 퀴즈 문항이 어떤 개념을 묻는지 연결해.

[뉴스 데이터]
{news_json}

반드시 아래 JSON 객체 형식으로만 출력:
{{
  "concepts": [
    {{
      "slug": "g7-summit",
      "display_name": "G7 정상회의",
      "kind": "event",
      "domain": "foreign",
      "definition": "주요 7개국 정상이 모여 국제 현안을 논의하는 연례 회의.",
      "articles": ["이 개념이 등장한 기사 제목 (items[].title과 정확히 일치)"]
    }}
  ],
  "quiz_links": [
    {{"article_title": "기사 제목(items[].title과 일치)", "quiz_index": 0, "concept_slug": "g7-summit"}}
  ]
}}

규칙:
- kind: person / org / event / place / term 중 하나
- domain: politics / economy / society / tech / foreign / etc 중 하나
- articles: 반드시 입력 items의 title과 글자까지 일치. 매칭 안 되면 그 개념 제외.
- concepts 전체 8~16개. 기사당 1~3개 수준.
- quiz_links: 각 기사의 quiz 배열 순서대로 quiz_index(0부터). 그 문항이 핵심으로 묻는 개념 1개의 slug를 concepts에 있는 slug 중에서 지정. 적절한 개념 없으면 그 문항은 생략.
- JSON 외 다른 텍스트 출력 금지"""


def _session_key(now=None) -> str:
    """KST 시간 → {YYYY-MM-DD}_{morning|evening}. 2회/일(07/18) 세션.
    07:00~17:59 morning, 18:00~23:59 evening, 00:00~06:59 전일 evening 연장."""
    KST = timezone(timedelta(hours=9))
    now = now or datetime.now(KST)
    h = now.hour
    if 7 <= h < 18:
        return f"{now.strftime('%Y-%m-%d')}_morning"
    if h >= 18:
        return f"{now.strftime('%Y-%m-%d')}_evening"
    prev = now - timedelta(days=1)
    return f"{prev.strftime('%Y-%m-%d')}_evening"


def _slugify(text: str) -> str:
    """LLM이 slug를 빠뜨렸을 때 fallback. 영문/숫자만 kebab, 없으면 원문 압축."""
    s = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return s or re.sub(r"\s+", "-", (text or "").strip())


def _extract_concepts(news_data: dict) -> dict:
    """뉴스 데이터로 개념 + 퀴즈-개념 링크 생성.
    반환: {"concepts": [...], "quiz_links": [...]}. 실패 시 빈 dict(cron 안 죽임)."""
    try:
        # glossary·quiz가 프롬프트에 포함되도록 items만 슬림하게 전달.
        # quiz는 quiz_index 참조용으로 question 텍스트만 순서대로.
        slim = {
            "items": [
                {
                    "title": it.get("title", ""),
                    "body": it.get("body", ""),
                    "why_matters": it.get("why_matters", ""),
                    "glossary": it.get("glossary", []),
                    "quiz": [
                        {"quiz_index": qi, "question": (q or {}).get("question", "")}
                        for qi, q in enumerate(it.get("quiz", []) or [])
                    ],
                }
                for it in news_data.get("items", [])
            ]
        }
        prompt = CONCEPT_PROMPT.format(
            news_json=json.dumps(slim, ensure_ascii=False)
        )
        client = genai.Client(api_key=GEMINI_API_KEY)
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=CONCEPT_SYSTEM,
                temperature=0.2,
                max_output_tokens=4000,
                thinking_config=types.ThinkingConfig(thinking_budget=0),
            ),
        )
        raw = (response.text or "").strip()
        if not raw and response.candidates:
            parts = response.candidates[0].content.parts if response.candidates[0].content else []
            raw = "\n".join(p.text for p in parts if hasattr(p, "text") and p.text).strip()
        if not raw:
            return {}
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            match = re.search(r"\{[\s\S]*\}", raw)
            if not match:
                return {}
            parsed = json.loads(match.group(0))
        if not isinstance(parsed, dict):
            return {}
        return parsed
    except Exception as e:
        print(f"  개념 추출 실패: {e}")
        return {}


def extract_and_store_concepts(news_data: dict, news_id: int):
    """뉴스에서 개념 추출 → concepts upsert + concept_occurrences 기록 +
    quiz 문항에 concept_ids 주입 후 summary 재저장.
    fetch_and_store 끝에서 호출. 실패해도 뉴스/대화 저장에 영향 없음."""
    init_concepts_db()
    extracted = _extract_concepts(news_data)
    concepts = extracted.get("concepts") or []
    quiz_links = extracted.get("quiz_links") or []
    if not concepts:
        print("  개념 0건 — 추출 스킵")
        return

    # 기사 제목 → 매칭 검증용
    valid_titles = {
        it.get("title", "").strip()
        for it in news_data.get("items", [])
        if it.get("title")
    }
    session_key = _session_key()
    slug_to_id = {}  # quiz_links 주입 시 slug → concept_id 조회용
    stored = 0
    for c in concepts:
        if not isinstance(c, dict):
            continue
        display = (c.get("display_name") or "").strip()
        if not display:
            continue
        slug = (c.get("slug") or "").strip() or _slugify(display)
        try:
            concept_id = upsert_concept(
                slug=slug,
                display_name=display,
                kind=(c.get("kind") or "term").strip(),
                domain=(c.get("domain") or "etc").strip(),
                definition=(c.get("definition") or "").strip(),
            )
        except Exception as e:
            print(f"  개념 upsert 실패 [{slug}]: {e}")
            continue
        slug_to_id[slug] = concept_id
        articles = c.get("articles") or []
        matched = [t.strip() for t in articles if t.strip() in valid_titles]
        # 매칭 0이면 뉴스 전체에 1건이라도 귀속(노출 코퍼스 손실 방지)
        if not matched and valid_titles:
            matched = [next(iter(valid_titles))]
        for title in matched:
            try:
                if add_occurrence(concept_id, news_id, title, session_key):
                    stored += 1
            except Exception as e:
                print(f"  occurrence 실패 [{slug}/{title[:20]}]: {e}")

    # quiz_links → 해당 quiz 문항에 concept_ids 주입 (위치 기반, 문자열 매칭 없음)
    title_to_item = {
        it.get("title", "").strip(): it
        for it in news_data.get("items", [])
        if it.get("title")
    }
    injected = 0
    for link in quiz_links:
        if not isinstance(link, dict):
            continue
        cid = slug_to_id.get((link.get("concept_slug") or "").strip())
        item = title_to_item.get((link.get("article_title") or "").strip())
        if cid is None or item is None:
            continue
        try:
            qi = int(link.get("quiz_index"))
        except (TypeError, ValueError):
            continue
        quiz = item.get("quiz") or []
        if not (0 <= qi < len(quiz)) or not isinstance(quiz[qi], dict):
            continue
        ids = quiz[qi].get("concept_ids") or []
        if cid not in ids:
            ids.append(cid)
            quiz[qi]["concept_ids"] = ids
            injected += 1

    # concept_ids가 하나라도 주입됐으면 summary 재저장
    if injected:
        try:
            update_summary(news_id, json.dumps(news_data, ensure_ascii=False))
        except Exception as e:
            print(f"  summary 재저장 실패: {e}")
    print(f"  개념 {len(concepts)}건, occurrence {stored}건, quiz링크 {injected}건 저장")


def backfill_concepts(limit: int = 5) -> dict:
    """concept_occurrences 없는 기존 news row만 골라 개념 추출 백필 (콜드스타트 코퍼스).

    Vercel 타임아웃 회피: 호출당 limit건만 처리. 멱등 — 이미 처리된 news_id는
    NOT IN으로 제외되므로 안전하게 반복 호출 가능.
    파싱 불가/items 없는 row는 occurrence가 안 생겨 영구히 남으므로,
    caller는 processed==0이면 루프 종료해야 함(remaining>0이어도)."""
    init_concepts_db()
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, summary FROM news
            WHERE id NOT IN (SELECT DISTINCT news_id FROM concept_occurrences)
            ORDER BY id DESC
            LIMIT %s
            """,
            (limit,),
        )
        rows = cur.fetchall()
        cur.execute(
            "SELECT COUNT(*) FROM news "
            "WHERE id NOT IN (SELECT DISTINCT news_id FROM concept_occurrences)"
        )
        remaining_before = cur.fetchone()[0]
        cur.close()
    finally:
        conn.close()

    processed, skipped = 0, 0
    for news_id, summary in rows:
        try:
            data = json.loads(summary) if isinstance(summary, str) else summary
        except Exception:
            data = None
        if not isinstance(data, dict) or not data.get("items"):
            skipped += 1
            continue
        try:
            extract_and_store_concepts(data, news_id)
            processed += 1
        except Exception as e:
            print(f"  백필 실패 [news_id={news_id}]: {e}")
            skipped += 1
    return {
        "processed": processed,
        "skipped": skipped,
        "remaining": max(0, remaining_before - processed),
    }


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
        model=GEMINI_MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(
            tools=[types.Tool(google_search=types.GoogleSearch())],
            system_instruction=SYSTEM_INSTRUCTION,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    # response.text가 None인 경우 parts에서 직접 텍스트 추출
    raw = response.text or ""
    if not raw and response.candidates:
        parts = response.candidates[0].content.parts if response.candidates[0].content else []
        text_parts = [p.text for p in parts if hasattr(p, "text") and p.text]
        raw = "\n".join(text_parts)

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

    # 방금 저장한 row id 확보 (dialogue·concept 둘 다 사용)
    from .db import get_latest_news
    latest = get_latest_news(region, category)
    news_id = latest.get("id") if latest else None

    # 2) dialogue 생성 후 같은 row를 update
    #    별도 try로 감싸서 dialogue 실패가 cron 전체를 죽이지 않게 함
    try:
        dialogue_list = generate_dialogue(data)
        if dialogue_list and news_id:
            update_dialogue(news_id, json.dumps(dialogue_list, ensure_ascii=False))
            print(f"  대화 {len(dialogue_list)}턴 저장 완료")
    except Exception as e:
        print(f"  dialogue 생성/저장 스킵: {e}")

    # 3) 개념 추출 → 학습 코퍼스 적재 (별도 try, 실패해도 무해)
    try:
        if news_id:
            extract_and_store_concepts(data, news_id)
    except Exception as e:
        print(f"  개념 추출/저장 스킵: {e}")
