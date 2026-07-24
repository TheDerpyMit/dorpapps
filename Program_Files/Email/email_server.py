#!/usr/bin/env python3
"""
Central WebSocket Email Server for ComputerCraft / DorpOS Gmail Client
Compatible with Pterodactyl hosting. Default port: 25616 (or PORT env var).
"""

import os
import sys
import json
import time
import hashlib
import secrets
import asyncio

# Auto-install websockets if missing
try:
    import websockets
except ImportError:
    print("[+] 'websockets' library not found. Installing...")
    os.system(f"{sys.executable} -m pip install websockets")
    import websockets

DATA_DIR = "data"
USERS_FILE = os.path.join(DATA_DIR, "users.json")
TOKENS_FILE = os.path.join(DATA_DIR, "tokens.json")
EMAILS_FILE = os.path.join(DATA_DIR, "emails.json")

# Shared storage structures
users = {}
tokens = {}
emails = []
connected_clients = {}  # websocket -> email address (or None if unauthenticated)

def ensure_data_dir():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

def load_data():
    global users, tokens, emails
    ensure_data_dir()
    
    if os.path.exists(USERS_FILE):
        try:
            with open(USERS_FILE, "r") as f:
                users = json.load(f)
        except Exception as e:
            print(f"[!] Error loading users: {e}")
            users = {}

    if os.path.exists(TOKENS_FILE):
        try:
            with open(TOKENS_FILE, "r") as f:
                tokens = json.load(f)
        except Exception as e:
            print(f"[!] Error loading tokens: {e}")
            tokens = {}

    if os.path.exists(EMAILS_FILE):
        try:
            with open(EMAILS_FILE, "r") as f:
                emails = json.load(f)
        except Exception as e:
            print(f"[!] Error loading emails: {e}")
            emails = []

def save_users():
    ensure_data_dir()
    with open(USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)

def save_tokens():
    ensure_data_dir()
    with open(TOKENS_FILE, "w") as f:
        json.dump(tokens, f, indent=2)

def save_emails():
    ensure_data_dir()
    with open(EMAILS_FILE, "w") as f:
        json.dump(emails, f, indent=2)

def normalize_email(addr):
    if not addr:
        return ""
    addr = str(addr).strip().lower()
    if "@" in addr:
        addr = addr.split("@")[0]
    return f"{addr}@dorp.com"

def hash_password(password, salt=None):
    if not salt:
        salt = secrets.token_hex(16)
    hashed = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
    return f"{salt}:{hashed}"

def verify_password(password, stored):
    try:
        salt, hashed = stored.split(":")
        check = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
        return check == hashed
    except Exception:
        return False

def get_user_from_token(token):
    if not token or token not in tokens:
        return None
    return tokens[token].get("email")

async def send_json(ws, data):
    try:
        await ws.send(json.dumps(data))
    except Exception as e:
        print(f"[!] Send error: {e}")

async def broadcast_email(email_obj):
    recipient = normalize_email(email_obj.get("to"))
    sender = normalize_email(email_obj.get("from"))
    
    dead_clients = []
    for ws, client_email in connected_clients.items():
        if client_email:
            norm_client = normalize_email(client_email)
            if norm_client in (recipient, sender) or recipient == "all@dorp.com":
                try:
                    await ws.send(json.dumps({
                        "event": "newemail",
                        "data": email_obj
                    }))
                except Exception:
                    dead_clients.append(ws)
    for ws in dead_clients:
        connected_clients.pop(ws, None)

async def handle_message(ws, raw_msg):
    try:
        req = json.loads(raw_msg)
    except Exception:
        await send_json(ws, {"event": "error", "error": "Invalid JSON format"})
        return

    event = req.get("event")

    # --- REGISTER ---
    if event == "register":
        raw_email = req.get("email")
        password = req.get("password")

        if not raw_email or not password:
            await send_json(ws, {"event": "register_response", "success": False, "error": "Username and password are required."})
            return

        email = normalize_email(raw_email)
        alias = email.split("@")[0]
        if len(alias) < 2:
            await send_json(ws, {"event": "register_response", "success": False, "error": "Username alias must be at least 2 characters long."})
            return

        if email in users:
            await send_json(ws, {"event": "register_response", "success": False, "error": f"This email ({email}) already exists!"})
            return

        users[email] = {
            "password": hash_password(password),
            "created_at": int(time.time())
        }
        save_users()

        token = secrets.token_hex(32)
        tokens[token] = {
            "email": email,
            "created_at": int(time.time())
        }
        save_tokens()

        connected_clients[ws] = email
        print(f"[+] New User Registered: {email}")
        await send_json(ws, {
            "event": "register_response",
            "success": True,
            "email": email,
            "token": token
        })

    # --- LOGIN ---
    elif event == "login":
        raw_email = req.get("email")
        password = req.get("password")

        if not raw_email or not password:
            await send_json(ws, {"event": "login_response", "success": False, "error": "Username and password are required."})
            return

        email = normalize_email(raw_email)
        user_record = users.get(email)

        if not user_record:
            await send_json(ws, {"event": "login_response", "success": False, "error": f"This email ({email}) does not exist! Please register."})
            return

        if not verify_password(password, user_record.get("password")):
            await send_json(ws, {"event": "login_response", "success": False, "error": "Password incorrect. Please try again."})
            return

        token = secrets.token_hex(32)
        tokens[token] = {
            "email": email,
            "created_at": int(time.time())
        }
        save_tokens()

        connected_clients[ws] = email
        print(f"[+] User Logged In: {email}")
        await send_json(ws, {
            "event": "login_response",
            "success": True,
            "email": email,
            "token": token
        })

    # --- AUTH CHECK ---
    elif event == "auth_check":
        token = req.get("token")
        email = get_user_from_token(token)
        if email:
            connected_clients[ws] = email
            await send_json(ws, {"event": "auth_response", "success": True, "email": email})
        else:
            await send_json(ws, {"event": "auth_response", "success": False, "error": "Session expired or invalid token."})

    # --- LIST EMAILS ---
    elif event == "list":
        token = req.get("token")
        email = get_user_from_token(token)
        if not email:
            await send_json(ws, {"event": "list_response", "success": False, "error": "Unauthorized session."})
            return

        connected_clients[ws] = email
        user_emails = []
        for msg in emails:
            to_addr = normalize_email(msg.get("to"))
            from_addr = normalize_email(msg.get("from"))
            if to_addr == email or from_addr == email or to_addr == "all@dorp.com":
                user_emails.append(msg)

        await send_json(ws, {
            "event": "list_response",
            "success": True,
            "emails": user_emails
        })

    # --- SEND EMAIL (NEWEMAIL) ---
    elif event == "newemail":
        token = req.get("token")
        email = get_user_from_token(token)
        if not email:
            await send_json(ws, {"event": "send_response", "success": False, "error": "Unauthorized session."})
            return

        msg_data = req.get("data", {})
        recipient = normalize_email(msg_data.get("to"))
        subject = msg_data.get("subject", "No Subject")
        body = msg_data.get("body", "")
        msg_id = msg_data.get("id") or secrets.token_hex(6)

        new_email = {
            "id": msg_id,
            "from": email,
            "to": recipient,
            "subject": subject,
            "body": body,
            "timestamp": msg_data.get("timestamp") or int(time.time() * 1000),
            "read": False,
            "archived": False,
            "starred": False,
            "deleted": False
        }

        emails.append(new_email)
        save_emails()
        print(f"[>] Email sent from {email} to {recipient}: {subject}")

        await send_json(ws, {
            "event": "send_response",
            "success": True,
            "email": new_email
        })

        await broadcast_email(new_email)

    # --- UPDATE EMAIL ---
    elif event == "update_email":
        token = req.get("token")
        email = get_user_from_token(token)
        if not email:
            await send_json(ws, {"event": "update_response", "success": False, "error": "Unauthorized session."})
            return

        msg_id = req.get("id")
        updates = req.get("updates", {})

        found = False
        for msg in emails:
            if msg.get("id") == msg_id:
                to_addr = normalize_email(msg.get("to"))
                from_addr = normalize_email(msg.get("from"))
                if to_addr == email or from_addr == email:
                    for k in ("read", "archived", "starred", "deleted"):
                        if k in updates:
                            msg[k] = bool(updates[k])
                    found = True
                    break

        if found:
            save_emails()
            await send_json(ws, {"event": "update_response", "success": True, "id": msg_id})
        else:
            await send_json(ws, {"event": "update_response", "success": False, "error": "Message not found or forbidden."})

async def ws_handler(ws, path=None):
    connected_clients[ws] = None
    try:
        async for message in ws:
            await handle_message(ws, message)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        connected_clients.pop(ws, None)

async def main():
    load_data()
    port = int(os.environ.get("PORT", 25616))
    host = "0.0.0.0"

    print("==================================================")
    print(f" DorpMail Python Email Server Starting...")
    print(f" Listening on {host}:{port}")
    print(f" Loaded {len(users)} registered users, {len(emails)} stored emails.")
    print("==================================================")

    async with websockets.serve(ws_handler, host, port):
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[!] Server stopped.")
