#!/usr/bin/env python3
import sqlite3
import sys
import os

DB_PATH = os.path.expanduser("~/Library/Messages/chat.db")

def decode_attributed_body(blob):
    if not blob:
        return None
    try:
        text = blob.decode("utf-8", errors="replace")
        if "NSString" in text:
            text = text.split("NSString")[1]
        if "NSDictionary" in text:
            text = text.split("NSDictionary")[0]
        if "NSNumber" in text:
            text = text.split("NSNumber")[0]
        cleaned = text[6:-12].strip()
        if cleaned:
            return cleaned
    except Exception:
        pass
    return None

def format_date(ts):
    if ts is None:
        return "unknown"
    import datetime
    apple_epoch = datetime.datetime(2001, 1, 1)
    return (apple_epoch + datetime.timedelta(seconds=ts / 1e9)).strftime("%Y-%m-%d %H:%M")

def cmd_chats(limit=20):
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("""
        SELECT
            chat.ROWID,
            chat.chat_identifier,
            chat.display_name,
            message.text,
            message.attributedBody,
            message.date
        FROM chat
        JOIN chat_message_join ON chat.ROWID = chat_message_join.chat_id
        JOIN message ON chat_message_join.message_id = message.ROWID
        WHERE message.ROWID IN (
            SELECT MAX(m2.ROWID)
            FROM chat_message_join cmj2
            JOIN message m2 ON cmj2.message_id = m2.ROWID
            WHERE cmj2.chat_id = chat.ROWID
        )
        ORDER BY message.date DESC
        LIMIT ?
    """, (limit,)).fetchall()
    conn.close()

    for row in rows:
        chat_id, identifier, display_name, text, attr_body, date = row
        body = text or decode_attributed_body(attr_body) or "[attachment]"
        body = body.replace("\n", " ")[:100]
        name = display_name or identifier
        print(f"{chat_id}|{name}|{body}|{format_date(date)}")

def cmd_read(contact, limit=30):
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("""
        SELECT
            message.date,
            message.is_from_me,
            handle.id,
            message.text,
            message.attributedBody
        FROM message
        JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
        JOIN chat ON chat_message_join.chat_id = chat.ROWID
        LEFT JOIN handle ON message.handle_id = handle.ROWID
        WHERE chat.chat_identifier LIKE ?
        ORDER BY message.date DESC
        LIMIT ?
    """, (f"%{contact}%", limit)).fetchall()
    conn.close()

    for row in reversed(rows):
        date, is_from_me, handle_id, text, attr_body = row
        sender = "me" if is_from_me else (handle_id or "unknown")
        body = text or decode_attributed_body(attr_body) or "[attachment]"
        body = body.replace("\n", " ")[:2000]
        print(f"{format_date(date)}|{sender}|{body}")

def cmd_search(query, limit=20):
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("""
        SELECT
            message.date,
            message.is_from_me,
            handle.id,
            message.text,
            message.attributedBody,
            chat.chat_identifier
        FROM message
        JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
        JOIN chat ON chat_message_join.chat_id = chat.ROWID
        LEFT JOIN handle ON message.handle_id = handle.ROWID
        WHERE message.text LIKE ?
        ORDER BY message.date DESC
        LIMIT ?
    """, (f"%{query}%", limit)).fetchall()
    conn.close()

    for row in rows:
        date, is_from_me, handle_id, text, attr_body, chat_id = row
        sender = "me" if is_from_me else (handle_id or "unknown")
        body = text or decode_attributed_body(attr_body) or "[attachment]"
        body = body.replace("\n", " ")[:200]
        print(f"{format_date(date)}|{sender}|{chat_id}|{body}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: decode-body.py <chats|read|search> [args...]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "chats":
        cmd_chats(int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd == "read":
        if len(sys.argv) < 3:
            print("Usage: decode-body.py read <phone_or_email> [limit]")
            sys.exit(1)
        cmd_read(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 30)
    elif cmd == "search":
        if len(sys.argv) < 3:
            print("Usage: decode-body.py search <query> [limit]")
            sys.exit(1)
        cmd_search(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20)
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
