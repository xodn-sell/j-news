import os
import psycopg2
from datetime import datetime


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
                created_at TEXT NOT NULL
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
        conn.commit()
        cur.close()
    finally:
        conn.close()


def save_news(region: str, category: str, summary: str, sources: str):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO news (region, category, summary, sources, created_at) VALUES (%s, %s, %s, %s, %s)",
            (region, category, summary, sources, datetime.now().isoformat()),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


def get_latest_news(region: str, category: str = "general"):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id, region, category, summary, sources, created_at FROM news WHERE region = %s AND category = %s ORDER BY created_at DESC LIMIT 1",
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
            }
        return None
    finally:
        conn.close()
