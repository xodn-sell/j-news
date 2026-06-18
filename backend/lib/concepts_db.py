"""개념(시사 배경지식) 학습 데이터 모델.

리터러시 학습앱 전환의 핵심 화폐 = '습득 개념 수' / 토픽별 mastery.

3개 테이블:
- concepts            : 정규화된 학습 단위 (인물·기관·사건·용어). slug UNIQUE로 dedup.
- concept_occurrences : 개념이 어느 뉴스에 등장했는가 (노출 코퍼스).
- user_concept_mastery: 유저별 개념 학습 상태 (노출 → Leitner SRS → 마스터).

설계 원칙:
- 측정은 수동 노출 기반(srs_stage=0 부터 카운트), 능동 테스트(퀴즈)는 stage를 끌어올림.
- 기존 client-side review_service(local)는 그대로 두고 이 레이어를 additive로 얹음.
- canonicalization은 Gemini가 추출 단계에서 수행 (slug/kind/domain 직접 반환).
"""

from datetime import datetime, timezone, timedelta
from .db import get_conn


KST = timezone(timedelta(hours=9))

# client review_service.dart와 동일한 Leitner 간격(일). index = stage - 1.
INTERVAL_DAYS = [1, 3, 7, 14, 30]
MAX_STAGE = 5

VALID_KINDS = ("person", "org", "event", "place", "term")
VALID_DOMAINS = ("politics", "economy", "society", "tech", "foreign", "etc")


def _now() -> str:
    return datetime.now(KST).isoformat()


def _today() -> str:
    return datetime.now(KST).strftime("%Y-%m-%d")


def _add_days(ymd: str, days: int) -> str:
    base = datetime.strptime(ymd, "%Y-%m-%d")
    return (base + timedelta(days=days)).strftime("%Y-%m-%d")


def init_concepts_db():
    """개념 학습 3테이블 생성 (멱등). news.py GET처럼 런타임 호출 가능."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS concepts (
                id SERIAL PRIMARY KEY,
                slug TEXT UNIQUE NOT NULL,
                display_name TEXT NOT NULL,
                kind TEXT NOT NULL DEFAULT 'term',
                domain TEXT NOT NULL DEFAULT 'etc',
                definition TEXT NOT NULL DEFAULT '',
                occurrence_count INTEGER NOT NULL DEFAULT 0,
                first_seen_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS concept_occurrences (
                id SERIAL PRIMARY KEY,
                concept_id INTEGER NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
                news_id INTEGER NOT NULL REFERENCES news(id) ON DELETE CASCADE,
                article_title TEXT NOT NULL DEFAULT '',
                session_key TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                UNIQUE (concept_id, news_id, article_title)
            )
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS user_concept_mastery (
                user_id TEXT NOT NULL,
                concept_id INTEGER NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
                exposure_count INTEGER NOT NULL DEFAULT 0,
                srs_stage INTEGER NOT NULL DEFAULT 0,
                next_review_date TEXT,
                mastered BOOLEAN NOT NULL DEFAULT FALSE,
                first_exposed_at TEXT NOT NULL,
                last_result_at TEXT,
                mastered_at TEXT,
                PRIMARY KEY (user_id, concept_id)
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_ucm_user_due "
            "ON user_concept_mastery (user_id, next_review_date)"
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS idx_co_news ON concept_occurrences (news_id)"
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


# ── 수집(cron) 측 ────────────────────────────────────────────

def upsert_concept(slug: str, display_name: str, kind: str,
                   domain: str, definition: str) -> int:
    """slug 기준 개념 upsert. 기존이면 last_seen/정의 갱신, occurrence_count는
    add_occurrence에서 증가. 개념 id 반환."""
    kind = kind if kind in VALID_KINDS else "term"
    domain = domain if domain in VALID_DOMAINS else "etc"
    now = _now()
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO concepts
                (slug, display_name, kind, domain, definition,
                 first_seen_at, last_seen_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE SET
                last_seen_at = EXCLUDED.last_seen_at,
                display_name = EXCLUDED.display_name,
                -- 새 정의가 더 길면 채택(빈/짧은 정의 덮어쓰기 방지)
                definition = CASE
                    WHEN length(EXCLUDED.definition) > length(concepts.definition)
                    THEN EXCLUDED.definition ELSE concepts.definition END
            RETURNING id
            """,
            (slug, display_name, kind, domain, definition, now, now),
        )
        concept_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        return concept_id
    finally:
        conn.close()


def add_occurrence(concept_id: int, news_id: int,
                   article_title: str, session_key: str) -> bool:
    """개념-뉴스 등장 기록. UNIQUE로 중복 무시. 신규 등장이면 occurrence_count++.
    신규 삽입 여부 반환."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO concept_occurrences
                (concept_id, news_id, article_title, session_key, created_at)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (concept_id, news_id, article_title) DO NOTHING
            RETURNING id
            """,
            (concept_id, news_id, article_title, session_key, _now()),
        )
        inserted = cur.fetchone() is not None
        if inserted:
            cur.execute(
                "UPDATE concepts SET occurrence_count = occurrence_count + 1 "
                "WHERE id = %s",
                (concept_id,),
            )
        conn.commit()
        cur.close()
        return inserted
    finally:
        conn.close()


# ── 유저 학습 측 ─────────────────────────────────────────────

def record_exposure(user_id: str, concept_id: int):
    """유저가 개념을 (수동) 노출. 행 없으면 stage=0으로 생성, 있으면 exposure_count++.
    능동 테스트 없이도 '만난 개념'으로 카운트되는 패시브 신호."""
    now = _now()
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO user_concept_mastery
                (user_id, concept_id, exposure_count, srs_stage, first_exposed_at)
            VALUES (%s, %s, 1, 0, %s)
            ON CONFLICT (user_id, concept_id) DO UPDATE SET
                exposure_count = user_concept_mastery.exposure_count + 1
            """,
            (user_id, concept_id, now),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def record_review(user_id: str, concept_id: int, correct: bool):
    """능동 테스트(퀴즈/복습) 결과로 Leitner 진행.
    정답=다음 단계(5→마스터), 오답=1단계 리셋. 미존재 행은 노출로 간주 후 처리."""
    today = _today()
    now = _now()
    conn = get_conn()
    try:
        cur = conn.cursor()
        # 행 보장 (노출 없이 바로 퀴즈 가능성 방어)
        cur.execute(
            """
            INSERT INTO user_concept_mastery
                (user_id, concept_id, exposure_count, srs_stage, first_exposed_at)
            VALUES (%s, %s, 0, 0, %s)
            ON CONFLICT (user_id, concept_id) DO NOTHING
            """,
            (user_id, concept_id, now),
        )
        cur.execute(
            "SELECT srs_stage, mastered FROM user_concept_mastery "
            "WHERE user_id = %s AND concept_id = %s",
            (user_id, concept_id),
        )
        stage, mastered = cur.fetchone()

        if correct:
            if stage >= MAX_STAGE:
                cur.execute(
                    """
                    UPDATE user_concept_mastery SET
                        mastered = TRUE,
                        mastered_at = COALESCE(mastered_at, %s),
                        last_result_at = %s
                    WHERE user_id = %s AND concept_id = %s
                    """,
                    (now, now, user_id, concept_id),
                )
            else:
                next_stage = max(stage, 1) + 1 if stage >= 1 else 1
                cur.execute(
                    """
                    UPDATE user_concept_mastery SET
                        srs_stage = %s,
                        next_review_date = %s,
                        last_result_at = %s
                    WHERE user_id = %s AND concept_id = %s
                    """,
                    (next_stage, _add_days(today, INTERVAL_DAYS[next_stage - 1]),
                     now, user_id, concept_id),
                )
        else:
            cur.execute(
                """
                UPDATE user_concept_mastery SET
                    srs_stage = 1,
                    next_review_date = %s,
                    mastered = FALSE,
                    last_result_at = %s
                WHERE user_id = %s AND concept_id = %s
                """,
                (_add_days(today, INTERVAL_DAYS[0]), now, user_id, concept_id),
            )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def get_concepts_for_news(news_id: int) -> list:
    """뉴스에 등장한 개념 목록 (기사 제목별 매핑 포함). 앱이 카드 노출/퀴즈 시
    어느 concept_id를 기록할지 알기 위해 news 페이로드에 실어줌."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT c.id, c.slug, c.display_name, c.kind, c.domain,
                   c.definition, o.article_title
            FROM concept_occurrences o
            JOIN concepts c ON c.id = o.concept_id
            WHERE o.news_id = %s
            ORDER BY c.kind, c.display_name
            """,
            (news_id,),
        )
        rows = cur.fetchall()
        cur.close()
        return [
            {
                "id": r[0],
                "slug": r[1],
                "display_name": r[2],
                "kind": r[3],
                "domain": r[4],
                "definition": r[5],
                "article_title": r[6],
            }
            for r in rows
        ]
    finally:
        conn.close()


def get_user_progress(user_id: str) -> dict:
    """진척 시각화용 집계. 완독보너스 자리에 띄울 핵심 수치."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT
                COUNT(*)                                   AS encountered,
                COUNT(*) FILTER (WHERE mastered)           AS mastered,
                COUNT(*) FILTER (WHERE srs_stage BETWEEN 1 AND 4
                                 AND NOT mastered)         AS learning,
                COUNT(*) FILTER (WHERE next_review_date IS NOT NULL
                                 AND next_review_date <= %s
                                 AND NOT mastered)         AS due_today
            FROM user_concept_mastery
            WHERE user_id = %s
            """,
            (_today(), user_id),
        )
        enc, mas, lrn, due = cur.fetchone()

        # 토픽(domain)별 mastery % — "G7 관련 80% 숙지" 류 viz
        cur.execute(
            """
            SELECT c.domain,
                   COUNT(*)                          AS total,
                   COUNT(*) FILTER (WHERE u.mastered) AS mastered
            FROM user_concept_mastery u
            JOIN concepts c ON c.id = u.concept_id
            WHERE u.user_id = %s
            GROUP BY c.domain
            """,
            (user_id,),
        )
        domains = [
            {"domain": d, "total": t, "mastered": m,
             "ratio": round(m / t, 2) if t else 0.0}
            for d, t, m in cur.fetchall()
        ]
        cur.close()
        return {
            "encountered": enc,
            "mastered": mas,
            "learning": lrn,
            "due_today": due,
            "domains": domains,
        }
    finally:
        conn.close()
