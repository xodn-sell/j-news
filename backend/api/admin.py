import json
import os
import sys
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from lib.db import get_conn

ADMIN_SECRET_KEY = os.environ.get("ADMIN_SECRET_KEY")
if not ADMIN_SECRET_KEY:
    raise RuntimeError("ADMIN_SECRET_KEY environment variable is required")


def _check_auth(headers, params) -> bool:
    key = headers.get("X-Admin-Key") or params.get("key", [None])[0]
    return key == ADMIN_SECRET_KEY


class handler(BaseHTTPRequestHandler):
    def _json_response(self, status_code: int, payload):
        body = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _get_stats(self):
        conn = get_conn()
        try:
            cur = conn.cursor()

            # 총 유저 수
            cur.execute("SELECT COUNT(*) FROM users")
            total_users = int(cur.fetchone()[0])

            # 오늘 신규 가입
            cur.execute("""
                SELECT COUNT(*) FROM users
                WHERE created_at::date = CURRENT_DATE
            """)
            new_users_today = int(cur.fetchone()[0])

            # 총 뉴스 기사 수
            cur.execute("SELECT COUNT(*) FROM news")
            total_news = int(cur.fetchone()[0])

            # 오늘 생성된 뉴스
            cur.execute("""
                SELECT COUNT(*) FROM news
                WHERE created_at::date = CURRENT_DATE
            """)
            new_news_today = int(cur.fetchone()[0])

            # 총 리뷰 수
            cur.execute("SELECT COUNT(*) FROM app_reviews")
            total_reviews = int(cur.fetchone()[0])

            cur.close()
            return {
                "total_users": total_users,
                "new_users_today": new_users_today,
                "total_news": total_news,
                "new_news_today": new_news_today,
                "total_reviews": total_reviews,
            }
        finally:
            conn.close()

    def _get_concepts_stats(self):
        """백필 진척·코퍼스 현황 확인용."""
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM concepts")
            total_concepts = int(cur.fetchone()[0])
            cur.execute("SELECT COUNT(*) FROM concept_occurrences")
            total_occurrences = int(cur.fetchone()[0])
            cur.execute("SELECT COUNT(*) FROM news")
            total_news = int(cur.fetchone()[0])
            cur.execute(
                "SELECT COUNT(DISTINCT news_id) FROM concept_occurrences"
            )
            tagged_news = int(cur.fetchone()[0])
            cur.execute(
                "SELECT domain, COUNT(*) FROM concepts GROUP BY domain "
                "ORDER BY COUNT(*) DESC"
            )
            by_domain = {d: int(c) for d, c in cur.fetchall()}
            cur.close()
            return {
                "total_concepts": total_concepts,
                "total_occurrences": total_occurrences,
                "total_news": total_news,
                "tagged_news": tagged_news,
                "untagged_news": total_news - tagged_news,
                "by_domain": by_domain,
            }
        finally:
            conn.close()

    def _get_users(self):
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT
                    u.id,
                    COALESCE(u.streak_count, 0) AS streak_count,
                    u.created_at,
                    u.platform
                FROM users u
                ORDER BY u.created_at DESC
            """)
            rows = cur.fetchall()
            cur.close()
            return [
                {
                    "id": row[0],
                    "streak_count": row[1],
                    "created_at": row[2],
                    "platform": row[3] or "google",
                }
                for row in rows
            ]
        finally:
            conn.close()

    def _get_reviews(self):
        conn = get_conn()
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT id, user_id, review_text, created_at
                FROM app_reviews
                ORDER BY created_at DESC
            """)
            rows = cur.fetchall()
            cur.close()
            return [
                {
                    "id": row[0],
                    "user_id": row[1],
                    "review_text": row[2],
                    "created_at": row[3],
                }
                for row in rows
            ]
        finally:
            conn.close()

    def _export_csv(self, export_type, columns, date_from, date_to):
        import csv
        import io
        from datetime import date

        allowed = {
            "users": ["id", "streak_count", "platform", "created_at"],
            "reviews": ["id", "user_id", "review_text", "created_at"],
        }

        if export_type not in allowed:
            self._json_response(400, {"detail": f"type must be one of: {', '.join(allowed.keys())}"})
            return

        valid_cols = [c for c in columns if c in allowed[export_type]]
        if not valid_cols:
            valid_cols = allowed[export_type]

        conn = get_conn()
        try:
            cur = conn.cursor()
            rows = []

            if export_type == "users":
                query = """
                    SELECT u.id, COALESCE(u.streak_count, 0), u.platform, u.created_at
                    FROM users u
                """
                conditions = []
                args = []
                if date_from:
                    conditions.append("u.created_at >= %s")
                    args.append(date_from)
                if date_to:
                    conditions.append("u.created_at < (%s::date + interval '1 day')")
                    args.append(date_to)
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                query += " ORDER BY u.created_at DESC"
                cur.execute(query, args)
                for row in cur.fetchall():
                    rows.append({
                        "id": row[0],
                        "streak_count": row[1],
                        "platform": row[2] or "google",
                        "created_at": str(row[3]) if row[3] else "",
                    })

            elif export_type == "reviews":
                query = "SELECT id, user_id, review_text, created_at FROM app_reviews"
                conditions = []
                args = []
                if date_from:
                    conditions.append("created_at >= %s")
                    args.append(date_from)
                if date_to:
                    conditions.append("created_at < (%s::date + interval '1 day')")
                    args.append(date_to)
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                query += " ORDER BY created_at DESC"
                cur.execute(query, args)
                for row in cur.fetchall():
                    rows.append({
                        "id": row[0],
                        "user_id": row[1],
                        "review_text": row[2],
                        "created_at": str(row[3]) if row[3] else "",
                    })

            cur.close()

            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=valid_cols)
            writer.writeheader()
            for row in rows:
                writer.writerow({k: row.get(k, "") for k in valid_cols})

            csv_bytes = ("﻿" + output.getvalue()).encode("utf-8")
            filename = f"{export_type}_{date.today()}.csv"
            self.send_response(200)
            self.send_header("Content-Type", "text/csv; charset=utf-8-sig")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(csv_bytes)
        finally:
            try:
                conn.close()
            except Exception:
                pass

    def do_GET(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        if not _check_auth(self.headers, params):
            self._json_response(401, {"detail": "Unauthorized"})
            return

        action = params.get("action", [None])[0]

        if action == "stats":
            try:
                data = self._get_stats()
                self._json_response(200, data)
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        elif action == "users":
            try:
                data = self._get_users()
                self._json_response(200, data)
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        elif action == "reviews":
            try:
                data = self._get_reviews()
                self._json_response(200, data)
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        elif action == "concepts_stats":
            try:
                self._json_response(200, self._get_concepts_stats())
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        elif action == "backfill_concepts":
            limit_raw = params.get("limit", ["5"])[0]
            try:
                limit = max(1, min(20, int(limit_raw)))
            except ValueError:
                limit = 5
            try:
                from lib.gemini import backfill_concepts
                self._json_response(200, backfill_concepts(limit))
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        elif action == "export":
            export_type = params.get("type", [None])[0]
            columns_raw = params.get("columns", [""])[0]
            columns = [c.strip() for c in columns_raw.split(",") if c.strip()] if columns_raw else []
            date_from = params.get("date_from", [None])[0]
            date_to = params.get("date_to", [None])[0]
            if not export_type:
                self._json_response(400, {"detail": "type is required"})
                return
            try:
                self._export_csv(export_type, columns, date_from, date_to)
            except Exception as e:
                self._json_response(500, {"detail": str(e)})

        else:
            self._json_response(400, {"detail": "action must be one of: stats, users, reviews, export, concepts_stats, backfill_concepts"})

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Admin-Key")
        self.end_headers()
