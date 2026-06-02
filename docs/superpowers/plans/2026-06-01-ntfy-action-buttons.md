# ntfy Action Buttons — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Approve / Snooze / Refine action buttons to EA ntfy notifications, backed by a general-purpose Flask action dispatcher on Mac mini, plus an `agent_needs` field in the data model.

**Architecture:** A Flask server (`~/scripts/action-dispatcher/`) on Mac mini listens on port 8765 for HTTP POSTs from ntfy button taps. Each action routes to a typed handler that reads/writes `dashboard-data.json` and commits. Refine fires a follow-up ntfy notification with a paste-ready Claude Code prompt. The dispatcher is general-purpose — new automations add a handler key, nothing else changes.

**Tech Stack:** Python 3, Flask, python-dotenv, requests, pytest, launchd (Mac mini service management)

---

## Prerequisites

- Run all commands on the Mac mini (SSH in first)
- Confirm port 8765 is free: `lsof -i :8765` — if something is using it, pick another port and update every reference in this plan
- Python 3 must be available: `python3 --version`
- git must be configured with push credentials on Mac mini: `git -C ~/repos/life-dashboard push --dry-run`

---

## File Map

**Created (Mac mini, outside life-dashboard repo):**
```
~/scripts/action-dispatcher/
├── app.py           — Flask server, auth, routing
├── handlers.py      — approve / snooze / refine + git helpers
├── context.py       — context bundle builder + ntfy sender
├── requirements.txt — dependencies
├── .env             — secrets and paths (never committed)
├── tests/
│   ├── conftest.py  — env setup before imports
│   └── test_dispatcher.py — all tests
└── com.mrrouser.action-dispatcher.plist  — launchd config
```

**Modified (life-dashboard repo):**
```
dashboard-data.json          — add agent_needs: null to all chats
CLAUDE.md                    — add agent_needs to session wrap protocol
CONTEXT.md                   — add agent_needs to data model docs
<ea-scanner-script>          — add action buttons to ntfy calls
docs/superpowers/specs/2026-06-01-ntfy-action-buttons-design.md  — already committed
```

---

## Task 1: Project setup

**Files:**
- Create: `~/scripts/action-dispatcher/requirements.txt`
- Create: `~/scripts/action-dispatcher/.env`

- [ ] **Step 1: Create the project directory and venv**

```bash
mkdir -p ~/scripts/action-dispatcher/tests
cd ~/scripts/action-dispatcher
python3 -m venv venv
```

- [ ] **Step 2: Create requirements.txt**

```
flask
python-dotenv
requests
pytest
```

- [ ] **Step 3: Install dependencies**

```bash
~/scripts/action-dispatcher/venv/bin/pip install -r ~/scripts/action-dispatcher/requirements.txt
```

Expected: pip installs flask, python-dotenv, requests, pytest with no errors.

- [ ] **Step 4: Create .env**

```bash
cat > ~/scripts/action-dispatcher/.env << 'EOF'
SECRET_TOKEN=change-me-to-a-random-string
DASHBOARD_PATH=/Users/matthewrouser/repos/life-dashboard/dashboard-data.json
NTFY_URL=https://ntfy.sh/your-topic-here
NTFY_TOKEN=your-ntfy-token-here
PORT=8765
EOF
```

Then fill in real values: generate `SECRET_TOKEN` with `openssl rand -hex 32`, use the same ntfy topic and token the EA scanner already uses.

- [ ] **Step 5: Add .env to .gitignore (create one in the project dir)**

```bash
echo ".env" > ~/scripts/action-dispatcher/.gitignore
echo "venv/" >> ~/scripts/action-dispatcher/.gitignore
echo "__pycache__/" >> ~/scripts/action-dispatcher/.gitignore
echo ".pytest_cache/" >> ~/scripts/action-dispatcher/.gitignore
```

---

## Task 2: context.py — context bundle builder

**Files:**
- Create: `~/scripts/action-dispatcher/context.py`
- Create: `~/scripts/action-dispatcher/tests/conftest.py`
- Create: `~/scripts/action-dispatcher/tests/test_dispatcher.py` (first section)

- [ ] **Step 1: Create conftest.py — set env vars before any imports**

```python
# tests/conftest.py
import os

os.environ.setdefault("SECRET_TOKEN", "test-token")
os.environ.setdefault("DASHBOARD_PATH", "/tmp/placeholder.json")
os.environ.setdefault("NTFY_URL", "https://ntfy.sh/test-topic")
os.environ.setdefault("NTFY_TOKEN", "test-ntfy-token")
os.environ.setdefault("PORT", "8765")
```

- [ ] **Step 2: Write the failing tests for build_context_bundle**

```python
# tests/test_dispatcher.py

import json
import pytest
from unittest.mock import patch


# ── fixtures ─────────────────────────────────────────────────────────────

SAMPLE_CHAT = {
    "id": "pihole-ipv6",
    "title": "PiHole",
    "agent_can_do": "Check if IPv6 PR merged",
    "agent_can_prep": "Research IPv6 config",
    "agent_needs": "SSH access to pihole1",
    "breadcrumb": "IPv6 VIP pending",
    "open_question": None,
    "cooldown_until": None,
    "last_completed": None,
    "updated": "2026-06-01",
}

SAMPLE_DASHBOARD = {
    "meta": {"last_updated": "2026-06-01T00:00:00Z", "version": "1.1"},
    "chats": [SAMPLE_CHAT.copy()],
}


@pytest.fixture
def dashboard_file(tmp_path):
    import handlers
    f = tmp_path / "dashboard-data.json"
    f.write_text(json.dumps(SAMPLE_DASHBOARD, indent=2))
    handlers.DASHBOARD_PATH = f
    return f


@pytest.fixture
def client(dashboard_file):
    import app as app_module
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as c:
        yield c, dashboard_file


def auth_headers():
    return {"Authorization": "Bearer test-token"}


# ── context bundle ───────────────────────────────────────────────────────

class TestContextBundle:
    def test_includes_all_non_null_fields(self):
        from context import build_context_bundle
        chat = {
            "title": "PiHole",
            "agent_can_do": "Check if PR merged",
            "agent_needs": "SSH access",
            "agent_can_prep": "Research config",
            "breadcrumb": "IPv6 pending",
        }
        result = build_context_bundle(chat)
        assert 'Refine EA action for "PiHole"' in result
        assert "Check if PR merged" in result
        assert "SSH access" in result
        assert "Research config" in result
        assert "IPv6 pending" in result
        assert "Work with me to refine" in result

    def test_omits_null_fields(self):
        from context import build_context_bundle
        chat = {
            "title": "PiHole",
            "agent_can_do": "Check if PR merged",
            "agent_needs": None,
            "agent_can_prep": None,
            "breadcrumb": None,
        }
        result = build_context_bundle(chat)
        assert "Needs" not in result
        assert "Prep available" not in result
        assert "Context" not in result
```

- [ ] **Step 3: Run the tests — verify they fail**

```bash
cd ~/scripts/action-dispatcher
venv/bin/pytest tests/test_dispatcher.py::TestContextBundle -v
```

Expected: `ImportError` or `ModuleNotFoundError` — context.py doesn't exist yet.

- [ ] **Step 4: Create context.py**

```python
# context.py
# Builds context bundles for the Refine handler and sends ntfy notifications.

import os

import requests
from dotenv import load_dotenv

load_dotenv()

NTFY_URL = os.environ["NTFY_URL"]
NTFY_TOKEN = os.environ["NTFY_TOKEN"]


def build_context_bundle(chat):
    lines = [f'Refine EA action for "{chat["title"]}".', ""]

    fields = [
        ("agent_can_do",   "Surfaced action"),
        ("agent_needs",    "Needs          "),
        ("agent_can_prep", "Prep available "),
        ("breadcrumb",     "Context        "),
    ]
    for key, label in fields:
        value = chat.get(key)
        if value:
            lines.append(f"{label}: {value}")

    lines.extend(["", "Work with me to refine this action or provision what the agent needs."])
    return "\n".join(lines)


def send_ntfy(title, message):
    requests.post(
        NTFY_URL,
        headers={
            "Title": title,
            "Authorization": f"Bearer {NTFY_TOKEN}",
        },
        data=message.encode("utf-8"),
        timeout=10,
    )
```

- [ ] **Step 5: Run the tests — verify they pass**

```bash
venv/bin/pytest tests/test_dispatcher.py::TestContextBundle -v
```

Expected: 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git -C ~/scripts/action-dispatcher init  # only needed first time
git -C ~/scripts/action-dispatcher add context.py requirements.txt .gitignore tests/conftest.py tests/test_dispatcher.py
git -C ~/scripts/action-dispatcher commit -m "feat: context bundle builder + test scaffold"
```

---

## Task 3: handlers.py — approve, snooze, refine

**Files:**
- Create: `~/scripts/action-dispatcher/handlers.py`
- Modify: `~/scripts/action-dispatcher/tests/test_dispatcher.py` (add handler tests)

- [ ] **Step 1: Write failing tests for all three handlers**

Handler tests call handler functions directly — no Flask test client needed yet (app.py doesn't exist until Task 4). Add these classes to `tests/test_dispatcher.py` after `TestContextBundle`:

```python
# ── approve ─────────────────────────────────────────────────────────────────

class TestApprove:
    def test_clears_agent_can_do(self, dashboard_file):
        from handlers import handle_approve
        with patch("handlers._git_commit_push"):
            handle_approve({"id": "pihole-ipv6"})
        data = json.loads(dashboard_file.read_text())
        chat = next(ch for ch in data["chats"] if ch["id"] == "pihole-ipv6")
        assert chat["agent_can_do"] is None

    def test_sets_last_completed(self, dashboard_file):
        from handlers import handle_approve
        with patch("handlers._git_commit_push"):
            handle_approve({"id": "pihole-ipv6"})
        data = json.loads(dashboard_file.read_text())
        chat = next(ch for ch in data["chats"] if ch["id"] == "pihole-ipv6")
        assert chat["last_completed"] == "EA action approved via ntfy"

    def test_calls_git_commit_push(self, dashboard_file):
        from handlers import handle_approve
        with patch("handlers._git_commit_push") as mock_git:
            handle_approve({"id": "pihole-ipv6"})
        mock_git.assert_called_once()
        assert "PiHole" in mock_git.call_args[0][0]


# ── snooze ──────────────────────────────────────────────────────────────────

class TestSnooze:
    def test_sets_cooldown_until_from_param(self, dashboard_file):
        from handlers import handle_snooze
        with patch("handlers._git_commit_push"):
            handle_snooze({"id": "pihole-ipv6", "until": "2026-07-01"})
        data = json.loads(dashboard_file.read_text())
        chat = next(ch for ch in data["chats"] if ch["id"] == "pihole-ipv6")
        assert chat["cooldown_until"] == "2026-07-01"

    def test_defaults_to_7_days_when_no_until(self, dashboard_file):
        from datetime import datetime, timedelta
        from handlers import handle_snooze
        with patch("handlers._git_commit_push"):
            handle_snooze({"id": "pihole-ipv6"})
        data = json.loads(dashboard_file.read_text())
        chat = next(ch for ch in data["chats"] if ch["id"] == "pihole-ipv6")
        expected = (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")
        assert chat["cooldown_until"] == expected

    def test_calls_git_commit_push(self, dashboard_file):
        from handlers import handle_snooze
        with patch("handlers._git_commit_push") as mock_git:
            handle_snooze({"id": "pihole-ipv6", "until": "2026-07-01"})
        mock_git.assert_called_once()


# ── refine ──────────────────────────────────────────────────────────────────

class TestRefine:
    def test_sends_ntfy_with_chat_title(self, dashboard_file):
        from handlers import handle_refine
        with patch("handlers.send_ntfy") as mock_ntfy:
            handle_refine({"id": "pihole-ipv6"})
        mock_ntfy.assert_called_once()
        title, prompt = mock_ntfy.call_args[0]
        assert "PiHole" in title

    def test_refine_prompt_includes_agent_can_do(self, dashboard_file):
        from handlers import handle_refine
        with patch("handlers.send_ntfy") as mock_ntfy:
            handle_refine({"id": "pihole-ipv6"})
        _, prompt = mock_ntfy.call_args[0]
        assert "Check if IPv6 PR merged" in prompt

    def test_refine_prompt_includes_agent_needs(self, dashboard_file):
        from handlers import handle_refine
        with patch("handlers.send_ntfy") as mock_ntfy:
            handle_refine({"id": "pihole-ipv6"})
        _, prompt = mock_ntfy.call_args[0]
        assert "SSH access to pihole1" in prompt
```

- [ ] **Step 2: Run the tests — verify they fail**

```bash
venv/bin/pytest tests/test_dispatcher.py::TestApprove tests/test_dispatcher.py::TestSnooze tests/test_dispatcher.py::TestRefine -v
```

Expected: `ImportError` — handlers.py doesn't exist yet.

- [ ] **Step 3: Create handlers.py**

```python
# handlers.py
# Approve, snooze, and refine action handlers.

import json
import os
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

from dotenv import load_dotenv

from context import build_context_bundle, send_ntfy

load_dotenv()

DASHBOARD_PATH = Path(os.environ["DASHBOARD_PATH"])


def handle_approve(data):
    chat_id = data["id"]
    dashboard = _read_dashboard()
    chat = _find_chat(dashboard, chat_id)
    chat["agent_can_do"] = None
    chat["last_completed"] = "EA action approved via ntfy"
    chat["updated"] = _today()
    _write_dashboard(dashboard)
    _git_commit_push(f"EA approve: {chat['title']}")


def handle_snooze(data):
    chat_id = data["id"]
    until = data.get("until") or _default_snooze_date()
    dashboard = _read_dashboard()
    chat = _find_chat(dashboard, chat_id)
    chat["cooldown_until"] = until
    chat["updated"] = _today()
    _write_dashboard(dashboard)
    _git_commit_push(f"EA snooze: {chat['title']} until {until}")


def handle_refine(data):
    chat_id = data["id"]
    dashboard = _read_dashboard()
    chat = _find_chat(dashboard, chat_id)
    prompt = build_context_bundle(chat)
    send_ntfy(f"Refine: {chat['title']}", prompt)


def _read_dashboard():
    with open(DASHBOARD_PATH) as f:
        return json.load(f)


def _write_dashboard(dashboard):
    with open(DASHBOARD_PATH, "w") as f:
        json.dump(dashboard, f, indent=2)
        f.write("\n")


def _find_chat(dashboard, chat_id):
    for chat in dashboard["chats"]:
        if chat["id"] == chat_id:
            return chat
    raise ValueError(f"Chat not found: {chat_id}")


def _git_commit_push(message):
    repo = str(DASHBOARD_PATH.parent)
    subprocess.run(["git", "-C", repo, "add", "dashboard-data.json"], check=True)
    subprocess.run(["git", "-C", repo, "commit", "-m", message], check=True)
    subprocess.run(["git", "-C", repo, "push"], check=True)


def _today():
    return datetime.now().strftime("%Y-%m-%d")


def _default_snooze_date():
    return (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")


HANDLERS = {
    "approve": handle_approve,
    "snooze": handle_snooze,
    "refine": handle_refine,
}
```

- [ ] **Step 4: Run handler tests — verify they pass**

```bash
venv/bin/pytest tests/test_dispatcher.py::TestApprove tests/test_dispatcher.py::TestSnooze tests/test_dispatcher.py::TestRefine -v
```

Expected: 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git -C ~/scripts/action-dispatcher add handlers.py tests/test_dispatcher.py
git -C ~/scripts/action-dispatcher commit -m "feat: approve/snooze/refine handlers with tests"
```

---

## Task 4: app.py — Flask server with auth and routing

**Files:**
- Create: `~/scripts/action-dispatcher/app.py`
- Modify: `~/scripts/action-dispatcher/tests/test_dispatcher.py` (add auth/routing tests)

- [ ] **Step 1: Write failing tests for auth and routing**

Add these classes to `tests/test_dispatcher.py` before `TestContextBundle`:

```python
# ── auth ─────────────────────────────────────────────────────────────────────

class TestAuth:
    def test_missing_token_returns_401(self, client):
        c, _ = client
        res = c.post("/action", json={"action": "approve", "id": "pihole-ipv6"})
        assert res.status_code == 401

    def test_wrong_token_returns_401(self, client):
        c, _ = client
        res = c.post("/action", json={"action": "approve", "id": "pihole-ipv6"},
                     headers={"Authorization": "Bearer wrong-token"})
        assert res.status_code == 401

    def test_valid_token_passes_auth(self, client):
        c, _ = client
        with patch("handlers._git_commit_push"):
            res = c.post("/action", json={"action": "approve", "id": "pihole-ipv6"},
                         headers=auth_headers())
        assert res.status_code == 200


# ── routing ──────────────────────────────────────────────────────────────────

class TestRouting:
    def test_unknown_action_returns_400(self, client):
        c, _ = client
        res = c.post("/action", json={"action": "dance", "id": "pihole-ipv6"},
                     headers=auth_headers())
        assert res.status_code == 400

    def test_invalid_json_returns_400(self, client):
        c, _ = client
        res = c.post("/action", data="not json", content_type="text/plain",
                     headers=auth_headers())
        assert res.status_code == 400

    def test_handler_exception_returns_500(self, client):
        c, _ = client
        with patch("handlers.handle_approve", side_effect=Exception("boom")):
            res = c.post("/action", json={"action": "approve", "id": "pihole-ipv6"},
                         headers=auth_headers())
        assert res.status_code == 500
```

- [ ] **Step 2: Run new tests — verify they fail**

```bash
venv/bin/pytest tests/test_dispatcher.py::TestAuth tests/test_dispatcher.py::TestRouting -v
```

Expected: `ImportError` — app.py doesn't exist yet.

- [ ] **Step 3: Create app.py**

```python
# app.py
# Flask action dispatcher. One endpoint: POST /action
# Run directly: python app.py  (uses PORT from .env, default 8765)

import os

from dotenv import load_dotenv
from flask import Flask, jsonify, request

from handlers import HANDLERS

load_dotenv()

app = Flask(__name__)
SECRET_TOKEN = os.environ["SECRET_TOKEN"]


@app.route("/action", methods=["POST"])
def action():
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {SECRET_TOKEN}":
        return jsonify({"error": "unauthorized"}), 401

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "invalid JSON"}), 400

    action_name = data.get("action")
    if action_name not in HANDLERS:
        return jsonify({"error": f"unknown action: {action_name}"}), 400

    try:
        HANDLERS[action_name](data)
        return jsonify({"ok": True}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8765)))
```

- [ ] **Step 4: Run all tests — verify everything passes**

```bash
venv/bin/pytest tests/ -v
```

Expected: all tests PASS (no failures, no errors).

- [ ] **Step 5: Commit**

```bash
git -C ~/scripts/action-dispatcher add app.py tests/test_dispatcher.py
git -C ~/scripts/action-dispatcher commit -m "feat: Flask app with auth and routing"
```

---

## Task 5: launchd service

**Files:**
- Create: `~/scripts/action-dispatcher/com.mrrouser.action-dispatcher.plist`

- [ ] **Step 1: Create the launchd plist**

```bash
mkdir -p ~/Library/Logs/action-dispatcher
```

Create `~/scripts/action-dispatcher/com.mrrouser.action-dispatcher.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mrrouser.action-dispatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/matthewrouser/scripts/action-dispatcher/venv/bin/python</string>
        <string>/Users/matthewrouser/scripts/action-dispatcher/app.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/matthewrouser/scripts/action-dispatcher</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/matthewrouser/Library/Logs/action-dispatcher/out.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/matthewrouser/Library/Logs/action-dispatcher/err.log</string>
</dict>
</plist>
```

- [ ] **Step 2: Copy plist to LaunchAgents and load it**

```bash
cp ~/scripts/action-dispatcher/com.mrrouser.action-dispatcher.plist \
   ~/Library/LaunchAgents/com.mrrouser.action-dispatcher.plist

launchctl load ~/Library/LaunchAgents/com.mrrouser.action-dispatcher.plist
```

- [ ] **Step 3: Verify the service is running**

```bash
launchctl list | grep action-dispatcher
```

Expected: a line with `com.mrrouser.action-dispatcher` and a PID (non-zero number in first column).

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer wrong" \
  -d '{"action":"approve","id":"test"}'
```

Expected: `401` (server is responding).

- [ ] **Step 4: Check logs if the service failed to start**

```bash
cat ~/Library/Logs/action-dispatcher/err.log
```

Common causes: wrong python path (check `which python3` in venv), missing .env values, port already in use.

- [ ] **Step 5: Commit plist to the action-dispatcher repo**

```bash
git -C ~/scripts/action-dispatcher add com.mrrouser.action-dispatcher.plist
git -C ~/scripts/action-dispatcher commit -m "feat: launchd service config"
```

---

## Task 6: Update dashboard-data.json — add agent_needs field

**Files:**
- Modify: `~/repos/life-dashboard/dashboard-data.json`
- Modify: `~/repos/life-dashboard/CONTEXT.md`
- Modify: `~/repos/life-dashboard/CLAUDE.md`

- [ ] **Step 1: Add agent_needs: null to all chats in dashboard-data.json**

Open `dashboard-data.json`. For every object in the `chats` array that does NOT already have `agent_needs`, add it alongside `agent_can_do` and `agent_can_prep`:

```json
"agent_can_do": null,
"agent_can_prep": null,
"agent_needs": null,
```

Order matters for readability — keep the three fields together. All existing chats get `null`.

- [ ] **Step 2: Update CONTEXT.md data model section**

In CONTEXT.md, find the `chats[]` line under `## Data model` and update it:

```
- `chats[]` — id, project_id, title, status, deadline, next_step, breadcrumb, energy, open_question, updated, shipped_count, blocker_type, agent_can_do, agent_can_prep, agent_needs, cooldown_until
```

- [ ] **Step 3: Update CLAUDE.md session wrap protocol**

In CLAUDE.md, find the `agent_can_prep` field definition and add `agent_needs` immediately after:

```
- `agent_needs` — one line: what the agent would need to execute `agent_can_do` autonomously (e.g., "SSH access to pihole1", "Spotify API credentials"). Or `null`.
```

Also add `agent_needs` to the dashboard update list:

> Set `blocker_type`, `agent_can_do`, `agent_can_prep`, `agent_needs`, `cooldown_until`

- [ ] **Step 4: Commit**

```bash
git -C ~/repos/life-dashboard add dashboard-data.json CONTEXT.md CLAUDE.md
git -C ~/repos/life-dashboard commit -m "data model: add agent_needs field to all chats"
git -C ~/repos/life-dashboard push
```

---

## Task 7: Update EA scanner — add action buttons to ntfy calls

**Files:**
- Modify: `<ea-scanner-script>` (discover path in Step 1)

- [ ] **Step 1: Find the EA scanner script**

Run on Mac mini:

```bash
crontab -l
```

Look for the line that runs the EA scanner. The script path will be in that crontab entry. Note it down — you'll need it for Step 2.

- [ ] **Step 2: Find the DISPATCHER_HOST value**

The Mac mini's local IP (for WireGuard/LAN access):

```bash
ipconfig getifaddr en0
```

Note this IP. It goes into the EA scanner's environment or .env as `DISPATCHER_HOST`.

- [ ] **Step 3: Add dispatcher config to the EA scanner's .env (or equivalent)**

The scanner needs to know where to point the action buttons. Add to its config:

```
DISPATCHER_HOST=<mac-mini-local-ip>
DISPATCHER_PORT=8765
DISPATCHER_TOKEN=<same SECRET_TOKEN from action-dispatcher .env>
```

- [ ] **Step 4: Update the ntfy notification call in the scanner**

Locate the line(s) in the scanner that call ntfy (likely a `curl` command). Replace the simple ntfy call with one that includes action buttons.

Before (example — exact syntax will vary):
```bash
curl -s "$NTFY_URL" \
  -H "Authorization: Bearer $NTFY_TOKEN" \
  -H "Title: EA: $CHAT_TITLE" \
  -d "$BODY"
```

After:
```bash
ACTIONS="http, Approve, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer ${DISPATCHER_TOKEN}, body={\"action\":\"approve\",\"id\":\"${CHAT_ID}\"}"
ACTIONS="${ACTIONS}; http, Snooze, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer ${DISPATCHER_TOKEN}, body={\"action\":\"snooze\",\"id\":\"${CHAT_ID}\"}"
ACTIONS="${ACTIONS}; http, Refine, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer ${DISPATCHER_TOKEN}, body={\"action\":\"refine\",\"id\":\"${CHAT_ID}\"}"

# Build body — include agent_needs line only if set
BODY="I can do: ${AGENT_CAN_DO}"
if [ -n "$AGENT_NEEDS" ] && [ "$AGENT_NEEDS" != "null" ]; then
  BODY="${BODY}\nNeeds: ${AGENT_NEEDS}\nTap Refine to set it up, or Approve/Snooze."
fi

curl -s "$NTFY_URL" \
  -H "Authorization: Bearer $NTFY_TOKEN" \
  -H "Title: EA: $CHAT_TITLE" \
  -H "Actions: $ACTIONS" \
  -d "$(printf "$BODY")"
```

Where `$CHAT_ID`, `$CHAT_TITLE`, `$AGENT_CAN_DO`, `$AGENT_NEEDS` come from the scanner's existing jq/parsing logic. Adapt variable names to match what the scanner already uses.

- [ ] **Step 5: Test the updated scanner manually**

Run the scanner script once manually and check your phone for the notification with three buttons:

```bash
<path-to-ea-scanner-script>
```

Expected: ntfy notification arrives with [Approve] [Snooze] [Refine] buttons visible.

- [ ] **Step 6: Commit scanner changes**

Commit the scanner script in whatever repo it lives in.

---

## Task 8: End-to-end smoke test

- [ ] **Step 1: Send a test Approve via curl from Mac mini**

```bash
curl -s -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(grep SECRET_TOKEN ~/scripts/action-dispatcher/.env | cut -d= -f2)" \
  -d '{"action":"approve","id":"pihole-ipv6"}'
```

Expected response: `{"ok": true}`

- [ ] **Step 2: Verify dashboard-data.json was updated**

```bash
python3 -c "
import json
data = json.load(open('/Users/matthewrouser/repos/life-dashboard/dashboard-data.json'))
chat = next(c for c in data['chats'] if c['id'] == 'pihole-ipv6')
print('agent_can_do:', chat['agent_can_do'])
print('last_completed:', chat['last_completed'])
"
```

Expected:
```
agent_can_do: None
last_completed: EA action approved via ntfy
```

- [ ] **Step 3: Verify git commit was made**

```bash
git -C ~/repos/life-dashboard log --oneline -3
```

Expected: top commit says something like `EA approve: PiHole`.

- [ ] **Step 4: Test Refine — verify follow-up ntfy arrives**

```bash
curl -s -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(grep SECRET_TOKEN ~/scripts/action-dispatcher/.env | cut -d= -f2)" \
  -d '{"action":"refine","id":"lawn-care"}'
```

Expected: a follow-up ntfy notification arrives on your phone titled "Refine: Lawn care" with the context prompt in the body.

- [ ] **Step 5: Test Snooze**

```bash
curl -s -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(grep SECRET_TOKEN ~/scripts/action-dispatcher/.env | cut -d= -f2)" \
  -d '{"action":"snooze","id":"landscaping","until":"2026-08-01"}'
```

Check `dashboard-data.json`: landscaping chat should have `"cooldown_until": "2026-08-01"`.

- [ ] **Step 6: Tap a real button from your phone (on home WiFi)**

Trigger the EA scanner manually (or wait for it to fire). When the notification arrives, tap Approve. Confirm `dashboard-data.json` is updated on the Mac mini within a few seconds.

---

## Rollback

If something breaks and you need to stop the dispatcher:

```bash
launchctl unload ~/Library/LaunchAgents/com.mrrouser.action-dispatcher.plist
```

To restart after fixing:
```bash
launchctl load ~/Library/LaunchAgents/com.mrrouser.action-dispatcher.plist
```

---

## Open questions (from spec)

1. **Port conflict:** Run `lsof -i :8765` before Task 5 — if occupied, pick a free port and update `.env`, the plist, and the scanner config.
2. **EA scanner location:** Discovered in Task 7 Step 1 via `crontab -l`. The exact variable names for `CHAT_ID`, `CHAT_TITLE`, `AGENT_CAN_DO`, `AGENT_NEEDS` depend on what the scanner already uses — adapt Task 7 Step 4 to match.
