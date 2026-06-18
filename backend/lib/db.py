import os
import psycopg2
from datetime import datetime, timezone, timedelta


KST = timezone(timedelta(hours=9))


def get_conn():
    return psycopg2.connect(os.environ["POSTGRES_URL"])


def init_db():
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS news (
                id SERIAL PRIMARY KEY,
                region TEXT NOT NULL,
                category TEXT NOT NULL DEFAULT 'general',
                summary TEXT NOT NULL,
                sources TEXT NOT NULL,
                created_at TEXT NOT NULL,
                dialogue TEXT
            )
        """)
        # 기존 테이블에 category 컬럼이 없으면 추가
        cur.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'news' AND column_name = 'category'
                ) THEN
                    ALTER TABLE news ADD COLUMN category TEXT NOT NULL DEFAULT 'general';
                END IF;
            END $$;
        """)
        # dialogue 컬럼이 없으면 추가
        cur.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'news' AND column_name = 'dialogue'
                ) THEN
                    ALTER TABLE news ADD COLUMN dialogue TEXT;
                END IF;
            END $$;
        """)
        conn.commit()
        cur.close()
    finally:
        conn.close()


def init_chat_db():
    """chat_usage 테이블 생성 (일일 AI 채팅 사용량 추적)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS chat_usage (
                user_id TEXT NOT NULL,
                date TEXT NOT NULL,
                count INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (user_id, date)
            )
        """)
        conn.commit()
        cur.close()
    finally:
        conn.close()


def increment_chat_usage(user_id: str) -> int:
    """KST 오늘 날짜 기준 사용량 +1 후 누적 count 반환.

    INSERT ... ON CONFLICT DO UPDATE (원자적 UPSERT) — 동시 요청에도 안전.
    """
    today = datetime.now(KST).strftime("%Y-%m-%d")
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO chat_usage (user_id, date, count)
            VALUES (%s, %s, 1)
            ON CONFLICT (user_id, date)
            DO UPDATE SET count = chat_usage.count + 1
            RETURNING count
            """,
            (user_id, today),
        )
        count = cur.fetchone()[0]
        conn.commit()
        cur.close()
        return count
    finally:
        conn.close()


def save_news(region: str, category: str, summary: str, sources: str, dialogue: str | None = None):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO news (region, category, summary, sources, created_at, dialogue) VALUES (%s, %s, %s, %s, %s, %s)",
            (region, category, summary, sources, datetime.now(KST).isoformat(), dialogue),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def update_summary(news_id: int, summary: str):
    """기존 뉴스 row의 summary 교체 (개념 추출 후 quiz에 concept_ids 주입용)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE news SET summary = %s WHERE id = %s",
            (summary, news_id),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def update_dialogue(news_id: int, dialogue: str):
    """기존 뉴스 row에 dialogue를 나중에 추가/교체."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "UPDATE news SET dialogue = %s WHERE id = %s",
            (dialogue, news_id),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def get_today_news(region: str, category: str = "general"):
    """오늘 날짜에 저장된 뉴스 목록 반환 (중복 방지용)"""
    conn = get_conn()
    try:
        cur = conn.cursor()
        today = datetime.now(KST).strftime("%Y-%m-%d")
        cur.execute(
            "SELECT summary FROM news WHERE region = %s AND category = %s AND created_at LIKE %s ORDER BY created_at ASC",
            (region, category, f"{today}%"),
        )
        rows = cur.fetchall()
        cur.close()
        return [row[0] for row in rows]
    finally:
        conn.close()


def get_latest_news(region: str, category: str = "general"):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, region, category, summary, sources, created_at, dialogue FROM news WHERE region = %s AND category = %s ORDER BY created_at DESC LIMIT 1",
            (region, category),
        )
        row = cur.fetchone()
        cur.close()
        if row:
            return {
                "id": row[0],
                "region": row[1],
                "category": row[2],
                "summary": row[3],
                "sources": row[4],
                "created_at": row[5],
                "dialogue": row[6],
            }
        return None
    finally:
        conn.close()
