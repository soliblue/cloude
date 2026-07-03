import sqlite3
from contextlib import contextmanager

from app.core.config import settings


@contextmanager
def db():
    database_path = settings().database_path
    database_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(database_path, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("pragma journal_mode=wal")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()
