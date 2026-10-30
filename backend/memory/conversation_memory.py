import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent.parent / "database" / "omega.db"


class ConversationMemory:

    def __init__(self):
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)

        with sqlite3.connect(DB_PATH) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    conversation_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_messages_conversation
                ON messages(conversation_id, id)
            """)

    def save_message(self, conversation_id, role, content):
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute(
                """
                INSERT INTO messages
                (conversation_id, role, content)
                VALUES (?, ?, ?)
                """,
                (conversation_id, role, content)
            )

    def get_history(self, conversation_id, limit=20):
        with sqlite3.connect(DB_PATH) as conn:
            rows = conn.execute(
                """
                SELECT role, content
                FROM messages
                WHERE conversation_id = ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (conversation_id, limit)
            ).fetchall()

        return [
            {"role": role, "content": content}
            for role, content in reversed(rows)
        ]