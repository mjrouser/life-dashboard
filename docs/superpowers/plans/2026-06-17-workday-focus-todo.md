# Workday Focus Todo App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone daily work-focus tool — a Python Flask server with SQLite backend and vanilla JS frontend — that lets you manage a full todo backlog across four work categories, pin today's priorities, and collapse to a distraction-free focus view.

**Architecture:** Flask serves both the single-page app and a JSON CRUD API. SQLite stores todos in a single local file. The frontend uses vanilla JS + SortableJS for drag-and-drop reordering. Two UI modes (planning / focus) are toggled via URL parameter. Runs as a launchd service on the Mac Mini; accessible from phone via WireGuard.

**Tech Stack:** Python 3 + Flask, SQLite3, pytest, vanilla HTML/CSS/JS, SortableJS 1.15.2

## Global Constraints

- New standalone repo: `~/repos/workday-focus/` — **not** inside life-dashboard
- Python 3, venv, Flask >= 3.0, pytest >= 8.0
- No localStorage, no sessionStorage — persistence via server; mode state via URL param only
- Fixed categories: `sales`, `delivery`, `work_admin`, `personal`
- Design tokens match life-dashboard exactly (see Task 8)
- Flask runs on port **5001** (5000 conflicts with macOS AirPlay Receiver)
- All API responses are JSON; errors return `{"error": "message"}`
- Tests use a temp-file SQLite DB (not `:memory:`) to avoid connection lifecycle issues

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `~/repos/workday-focus/app.py` | Create | Flask app: DB connection, init, all routes |
| `~/repos/workday-focus/requirements.txt` | Create | flask, pytest |
| `~/repos/workday-focus/.gitignore` | Create | Excludes todo.db, venv/, logs, pycache |
| `~/repos/workday-focus/tests/__init__.py` | Create | Empty — makes tests a package |
| `~/repos/workday-focus/tests/test_api.py` | Create | All pytest API tests |
| `~/repos/workday-focus/static/index.html` | Create | SPA markup, loads fonts + SortableJS + style.css + app.js |
| `~/repos/workday-focus/static/style.css` | Create | Design tokens, 4-column layout, dark mode |
| `~/repos/workday-focus/static/app.js` | Create | State, API client, planning/focus mode render, drag-and-drop |
| `~/repos/workday-focus/com.matthewrouser.workday-focus.plist` | Create | launchd service definition |
| `~/repos/workday-focus/README.md` | Create | Setup, venv, run, deploy to Mac Mini |

---

## Task 1: Project scaffold + DB schema

**Files:**
- Create: `~/repos/workday-focus/app.py`
- Create: `~/repos/workday-focus/requirements.txt`
- Create: `~/repos/workday-focus/.gitignore`
- Create: `~/repos/workday-focus/tests/__init__.py`
- Create: `~/repos/workday-focus/tests/test_api.py` (fixture only)

**Interfaces:**
- Produces: `app` (Flask instance), `get_db()`, `init_db()`, `CATEGORIES` — used by all later tasks

- [ ] **Step 1: Create the repo**

```bash
mkdir ~/repos/workday-focus
cd ~/repos/workday-focus
git init
```

- [ ] **Step 2: Create `requirements.txt`**

```
flask>=3.0
pytest>=8.0
```

- [ ] **Step 3: Create `.gitignore`**

```
venv/
todo.db
*.log
__pycache__/
*.pyc
.pytest_cache/
```

- [ ] **Step 4: Set up venv and install dependencies**

```bash
cd ~/repos/workday-focus
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

- [ ] **Step 5: Create `app.py`**

```python
# app.py — Workday Focus Flask server
# Run: python app.py  (serves on http://0.0.0.0:5001)

import sqlite3
import os
import logging
from datetime import datetime, timezone
from flask import Flask, jsonify, request, g

app = Flask(__name__)
app.config['DATABASE'] = os.path.join(os.path.dirname(__file__), 'todo.db')

CATEGORIES = ['sales', 'delivery', 'work_admin', 'personal']

logging.basicConfig(
    filename=os.path.join(os.path.dirname(__file__), 'workday-focus.log'),
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)


def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(app.config['DATABASE'])
        db.row_factory = sqlite3.Row
    return db


@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()


@app.after_request
def log_request(response):
    logging.info('%s %s %s', request.method, request.path, response.status_code)
    return response


def init_db():
    db = get_db()
    db.execute('''
        CREATE TABLE IF NOT EXISTS todos (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            category    TEXT    NOT NULL,
            text        TEXT    NOT NULL,
            done        INTEGER NOT NULL DEFAULT 0,
            pinned      INTEGER NOT NULL DEFAULT 0,
            position    INTEGER NOT NULL DEFAULT 0,
            created_at  TEXT    NOT NULL,
            completed_at TEXT
        )
    ''')
    db.commit()


@app.route('/')
def index():
    return app.send_static_file('index.html')


if __name__ == '__main__':
    with app.app_context():
        init_db()
    app.run(host='0.0.0.0', port=5001, debug=False)
```

- [ ] **Step 6: Create `tests/__init__.py`**

Empty file — no content needed.

- [ ] **Step 7: Write the test fixture in `tests/test_api.py`**

```python
# tests/test_api.py — API endpoint tests for Workday Focus

import os
import tempfile
import pytest
from app import app, init_db


@pytest.fixture
def client():
    db_fd, db_path = tempfile.mkstemp(suffix='.db')
    app.config['TESTING'] = True
    app.config['DATABASE'] = db_path

    with app.test_client() as client:
        with app.app_context():
            init_db()
        yield client

    os.close(db_fd)
    os.unlink(db_path)
```

- [ ] **Step 8: Write the first test — DB schema is correct**

Add after the fixture in `tests/test_api.py`:

```python
def test_db_has_todos_table(client):
    from app import get_db
    with app.app_context():
        db = get_db()
        rows = db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='todos'"
        ).fetchall()
    assert len(rows) == 1
```

- [ ] **Step 9: Run the test**

```bash
cd ~/repos/workday-focus
source venv/bin/activate
pytest tests/test_api.py::test_db_has_todos_table -v
```

Expected output:
```
PASSED tests/test_api.py::test_db_has_todos_table
```

- [ ] **Step 10: Commit**

```bash
git add app.py requirements.txt .gitignore tests/__init__.py tests/test_api.py
git commit -m "feat: project scaffold, DB schema, test fixture"
```

---

## Task 2: GET /api/todos

**Files:**
- Modify: `~/repos/workday-focus/app.py` (add route)
- Modify: `~/repos/workday-focus/tests/test_api.py` (add tests)

**Interfaces:**
- Consumes: `get_db()`, `CATEGORIES` from Task 1
- Produces: `GET /api/todos` → `{ "sales": [...], "delivery": [...], "work_admin": [...], "personal": [...] }` — used by the frontend in Tasks 8–10

- [ ] **Step 1: Write the failing test**

Add to `tests/test_api.py`:

```python
def test_get_todos_returns_all_categories(client):
    response = client.get('/api/todos')
    assert response.status_code == 200
    data = response.get_json()
    assert set(data.keys()) == {'sales', 'delivery', 'work_admin', 'personal'}


def test_get_todos_returns_lists(client):
    response = client.get('/api/todos')
    data = response.get_json()
    for category in ['sales', 'delivery', 'work_admin', 'personal']:
        assert isinstance(data[category], list)
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/test_api.py::test_get_todos_returns_all_categories -v
```

Expected: `FAILED` — `404 NOT FOUND`

- [ ] **Step 3: Implement the route in `app.py`**

Add after `init_db()` and before the `index` route:

```python
@app.route('/api/todos', methods=['GET'])
def get_todos():
    db = get_db()
    rows = db.execute(
        'SELECT * FROM todos ORDER BY position ASC, created_at ASC'
    ).fetchall()
    grouped = {cat: [] for cat in CATEGORIES}
    for row in rows:
        if row['category'] in grouped:
            grouped[row['category']].append(dict(row))
    return jsonify(grouped)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_api.py::test_get_todos_returns_all_categories tests/test_api.py::test_get_todos_returns_lists -v
```

Expected: both `PASSED`

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_api.py
git commit -m "feat: GET /api/todos"
```

---

## Task 3: POST /api/todos

**Files:**
- Modify: `~/repos/workday-focus/app.py`
- Modify: `~/repos/workday-focus/tests/test_api.py`

**Interfaces:**
- Consumes: `get_db()`, `CATEGORIES`
- Produces: `POST /api/todos` with `{"category": "sales", "text": "Call client"}` → 201 with todo object including `id`, `position`, `created_at`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_api.py`:

```python
def test_create_todo_returns_201(client):
    response = client.post('/api/todos', json={'category': 'sales', 'text': 'Call client'})
    assert response.status_code == 201
    data = response.get_json()
    assert data['category'] == 'sales'
    assert data['text'] == 'Call client'
    assert data['done'] == 0
    assert data['pinned'] == 0
    assert 'id' in data
    assert 'created_at' in data


def test_create_todo_appears_in_get(client):
    client.post('/api/todos', json={'category': 'delivery', 'text': 'Ship order'})
    response = client.get('/api/todos')
    data = response.get_json()
    assert any(t['text'] == 'Ship order' for t in data['delivery'])


def test_create_todo_missing_text_returns_400(client):
    response = client.post('/api/todos', json={'category': 'sales'})
    assert response.status_code == 400


def test_create_todo_missing_category_returns_400(client):
    response = client.post('/api/todos', json={'text': 'something'})
    assert response.status_code == 400


def test_create_todo_invalid_category_returns_400(client):
    response = client.post('/api/todos', json={'category': 'invalid', 'text': 'something'})
    assert response.status_code == 400
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/test_api.py::test_create_todo_returns_201 -v
```

Expected: `FAILED` — `405 METHOD NOT ALLOWED`

- [ ] **Step 3: Implement the route in `app.py`**

Add after `get_todos()`:

```python
@app.route('/api/todos', methods=['POST'])
def create_todo():
    data = request.get_json()
    if not data or not data.get('text') or not data.get('category'):
        return jsonify({'error': 'text and category are required'}), 400
    if data['category'] not in CATEGORIES:
        return jsonify({'error': f'category must be one of {CATEGORIES}'}), 400

    db = get_db()
    row = db.execute(
        'SELECT MAX(position) as max_pos FROM todos WHERE category = ?',
        (data['category'],)
    ).fetchone()
    position = (row['max_pos'] or 0) + 1

    now = datetime.now(timezone.utc).isoformat()
    cursor = db.execute(
        'INSERT INTO todos (category, text, done, pinned, position, created_at) VALUES (?, ?, 0, 0, ?, ?)',
        (data['category'], data['text'], position, now)
    )
    db.commit()

    todo = db.execute('SELECT * FROM todos WHERE id = ?', (cursor.lastrowid,)).fetchone()
    return jsonify(dict(todo)), 201
```

- [ ] **Step 4: Run all tests**

```bash
pytest tests/test_api.py -v -k "create"
```

Expected: all 5 `create` tests `PASSED`

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_api.py
git commit -m "feat: POST /api/todos"
```

---

## Task 4: PATCH /api/todos/\<id\>

**Files:**
- Modify: `~/repos/workday-focus/app.py`
- Modify: `~/repos/workday-focus/tests/test_api.py`

**Interfaces:**
- Consumes: `get_db()`
- Produces: `PATCH /api/todos/<id>` accepts `{"text": "..."}`, `{"done": true/false}`, `{"pinned": true/false}`, `{"position": N}` individually or combined → 200 with updated todo object; 404 if id missing

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_api.py`:

```python
def _create(client, category='sales', text='Test todo'):
    """Helper: create a todo and return its id."""
    r = client.post('/api/todos', json={'category': category, 'text': text})
    return r.get_json()['id']


def test_patch_update_text(client):
    todo_id = _create(client)
    response = client.patch(f'/api/todos/{todo_id}', json={'text': 'Updated text'})
    assert response.status_code == 200
    assert response.get_json()['text'] == 'Updated text'


def test_patch_mark_done_sets_completed_at(client):
    todo_id = _create(client)
    response = client.patch(f'/api/todos/{todo_id}', json={'done': True})
    data = response.get_json()
    assert data['done'] == 1
    assert data['completed_at'] is not None


def test_patch_unmark_done_clears_completed_at(client):
    todo_id = _create(client)
    client.patch(f'/api/todos/{todo_id}', json={'done': True})
    response = client.patch(f'/api/todos/{todo_id}', json={'done': False})
    data = response.get_json()
    assert data['done'] == 0
    assert data['completed_at'] is None


def test_patch_pin_and_unpin(client):
    todo_id = _create(client)
    response = client.patch(f'/api/todos/{todo_id}', json={'pinned': True})
    assert response.get_json()['pinned'] == 1
    response = client.patch(f'/api/todos/{todo_id}', json={'pinned': False})
    assert response.get_json()['pinned'] == 0


def test_patch_update_position(client):
    todo_id = _create(client)
    response = client.patch(f'/api/todos/{todo_id}', json={'position': 5})
    assert response.get_json()['position'] == 5


def test_patch_not_found_returns_404(client):
    response = client.patch('/api/todos/99999', json={'text': 'ghost'})
    assert response.status_code == 404
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/test_api.py::test_patch_update_text -v
```

Expected: `FAILED` — `405 METHOD NOT ALLOWED`

- [ ] **Step 3: Implement the route in `app.py`**

Add after `create_todo()`:

```python
@app.route('/api/todos/<int:todo_id>', methods=['PATCH'])
def update_todo(todo_id):
    db = get_db()
    todo = db.execute('SELECT * FROM todos WHERE id = ?', (todo_id,)).fetchone()
    if not todo:
        return jsonify({'error': 'todo not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'request body required'}), 400

    allowed = {'text', 'done', 'pinned', 'position'}
    updates = {k: v for k, v in data.items() if k in allowed}
    if not updates:
        return jsonify({'error': 'no valid fields to update'}), 400

    if 'done' in updates:
        if updates['done'] and not todo['done']:
            updates['completed_at'] = datetime.now(timezone.utc).isoformat()
        elif not updates['done']:
            updates['completed_at'] = None

    set_clause = ', '.join(f'{k} = ?' for k in updates)
    db.execute(
        f'UPDATE todos SET {set_clause} WHERE id = ?',
        list(updates.values()) + [todo_id]
    )
    db.commit()

    updated = db.execute('SELECT * FROM todos WHERE id = ?', (todo_id,)).fetchone()
    return jsonify(dict(updated))
```

- [ ] **Step 4: Run all PATCH tests**

```bash
pytest tests/test_api.py -v -k "patch"
```

Expected: all 6 `patch` tests `PASSED`

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_api.py
git commit -m "feat: PATCH /api/todos/<id>"
```

---

## Task 5: DELETE /api/todos/\<id\>

**Files:**
- Modify: `~/repos/workday-focus/app.py`
- Modify: `~/repos/workday-focus/tests/test_api.py`

**Interfaces:**
- Produces: `DELETE /api/todos/<id>` → 204 no content; 404 if id not found

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_api.py`:

```python
def test_delete_todo_returns_204(client):
    todo_id = _create(client)
    response = client.delete(f'/api/todos/{todo_id}')
    assert response.status_code == 204


def test_delete_todo_removes_from_get(client):
    todo_id = _create(client, text='To be deleted')
    client.delete(f'/api/todos/{todo_id}')
    data = client.get('/api/todos').get_json()
    all_todos = [t for cat in data.values() for t in cat]
    assert not any(t['id'] == todo_id for t in all_todos)


def test_delete_not_found_returns_404(client):
    response = client.delete('/api/todos/99999')
    assert response.status_code == 404
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/test_api.py::test_delete_todo_returns_204 -v
```

Expected: `FAILED` — `405 METHOD NOT ALLOWED`

- [ ] **Step 3: Implement the route in `app.py`**

Add after `update_todo()`:

```python
@app.route('/api/todos/<int:todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    db = get_db()
    todo = db.execute('SELECT * FROM todos WHERE id = ?', (todo_id,)).fetchone()
    if not todo:
        return jsonify({'error': 'todo not found'}), 404
    db.execute('DELETE FROM todos WHERE id = ?', (todo_id,))
    db.commit()
    return '', 204
```

- [ ] **Step 4: Run the full test suite**

```bash
pytest tests/test_api.py -v
```

Expected: all tests `PASSED`

- [ ] **Step 5: Commit**

```bash
git add app.py tests/test_api.py
git commit -m "feat: DELETE /api/todos/<id> — full CRUD complete"
```

---

## Task 6: HTML skeleton + static file serving

**Files:**
- Create: `~/repos/workday-focus/static/index.html`
- Create: `~/repos/workday-focus/static/style.css` (empty for now)
- Create: `~/repos/workday-focus/static/app.js` (empty for now)
- Modify: `~/repos/workday-focus/tests/test_api.py`

**Interfaces:**
- Consumes: `index` route from Task 1
- Produces: `GET /` returns 200 HTML page that loads `style.css`, `app.js`, SortableJS, and Google Fonts

- [ ] **Step 1: Write the failing test**

Add to `tests/test_api.py`:

```python
def test_index_returns_html(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b'<!DOCTYPE html>' in response.data
```

- [ ] **Step 2: Run to verify failure**

```bash
pytest tests/test_api.py::test_index_returns_html -v
```

Expected: `FAILED` — 404 (no `static/index.html` yet)

- [ ] **Step 3: Create `static/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Workday Focus</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400&family=IBM+Plex+Sans:wght@400;500&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <div id="error-banner" class="error-banner hidden"></div>

  <header class="app-header">
    <h1 class="app-title">Workday Focus</h1>
    <div class="header-controls">
      <button id="btn-toggle-completed" class="btn-secondary">Show Completed</button>
      <button id="btn-toggle-mode" class="btn-primary">Focus Mode</button>
    </div>
  </header>

  <main id="app"></main>

  <script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/Sortable.min.js"></script>
  <script src="/static/app.js"></script>
</body>
</html>
```

- [ ] **Step 4: Create empty `static/style.css`**

```css
/* style.css — Workday Focus styles */
```

- [ ] **Step 5: Create empty `static/app.js`**

```javascript
// app.js — Workday Focus frontend
```

- [ ] **Step 6: Run the test**

```bash
pytest tests/test_api.py::test_index_returns_html -v
```

Expected: `PASSED`

- [ ] **Step 7: Run the full suite to confirm no regressions**

```bash
pytest tests/test_api.py -v
```

Expected: all tests `PASSED`

- [ ] **Step 8: Commit**

```bash
git add static/index.html static/style.css static/app.js tests/test_api.py
git commit -m "feat: HTML skeleton + static file serving"
```

---

## Task 7: CSS — design tokens, layout, dark mode

**Files:**
- Modify: `~/repos/workday-focus/static/style.css`

**Interfaces:**
- Produces: visual styles consumed by the HTML in Task 6; class names used by JS in Tasks 8–10

**Note:** No automated test. Manual verification: start the server, open `http://localhost:5001` in a browser, confirm layout renders correctly in light and dark mode (DevTools → Rendering → Emulate CSS prefers-color-scheme).

- [ ] **Step 1: Implement `static/style.css`**

```css
/* style.css — Workday Focus styles */

/* === Design tokens (match life-dashboard) === */
:root {
  --bg:            #fafaf8;
  --surface:       #ffffff;
  --text-primary:  #1a1a18;
  --text-secondary:#6e6e68;
  --text-tertiary: #a3a39d;
  --border:        rgba(0,0,0,0.08);
  --border-hover:  rgba(0,0,0,0.15);
  --pinned:        #1d6b54;
  --pinned-bg:     rgba(29,107,84,0.08);
  --done-text:     #a3a39d;
  --error-bg:      #fde8e8;
  --error-text:    #b91c1c;
  --font-sans: 'IBM Plex Sans', sans-serif;
  --font-mono: 'IBM Plex Mono', monospace;
  --radius: 10px;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg:            #141413;
    --surface:       #1e1e1c;
    --text-primary:  #e8e8e4;
    --text-secondary:#9a9a94;
    --text-tertiary: #6a6a64;
    --border:        rgba(255,255,255,0.08);
    --border-hover:  rgba(255,255,255,0.15);
    --pinned:        #5dcaa5;
    --pinned-bg:     rgba(93,202,165,0.10);
    --done-text:     #6a6a64;
    --error-bg:      #3b1515;
    --error-text:    #fca5a5;
  }
}

/* === Reset === */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--font-sans);
  background: var(--bg);
  color: var(--text-primary);
  min-height: 100vh;
}

/* === Error banner === */
.error-banner {
  background: var(--error-bg);
  color: var(--error-text);
  font-size: 0.85rem;
  padding: 10px 20px;
  text-align: center;
}
.hidden { display: none !important; }

/* === Header === */
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid var(--border);
}
.app-title {
  font-size: 1.1rem;
  font-weight: 500;
  font-family: var(--font-mono);
  color: var(--text-primary);
}
.header-controls { display: flex; gap: 8px; }

/* === Buttons === */
.btn-primary, .btn-secondary {
  font-family: var(--font-sans);
  font-size: 0.8rem;
  font-weight: 500;
  padding: 6px 14px;
  border-radius: 6px;
  border: 1px solid var(--border);
  cursor: pointer;
  background: var(--surface);
  color: var(--text-primary);
  transition: border-color 0.15s;
}
.btn-primary:hover, .btn-secondary:hover { border-color: var(--border-hover); }
.btn-primary.active {
  background: var(--pinned);
  color: #fff;
  border-color: var(--pinned);
}
.btn-icon {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--text-tertiary);
  font-size: 1rem;
  padding: 2px 4px;
  line-height: 1;
  transition: color 0.15s;
}
.btn-icon:hover { color: var(--text-primary); }

/* === Main layout === */
#app { padding: 20px; }

/* Planning mode: 4 columns */
.columns {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  align-items: start;
}
@media (max-width: 900px) {
  .columns { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 500px) {
  .columns { grid-template-columns: 1fr; }
}

/* Focus mode: single column, narrow */
.focus-list {
  max-width: 560px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 24px;
}
.focus-category-label {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-tertiary);
  margin-bottom: 8px;
}

/* === Column === */
.column {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 14px;
}
.column-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.column-title {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
}

/* === Todo items === */
.todo-list { list-style: none; display: flex; flex-direction: column; gap: 4px; }

.todo-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 8px 10px;
  border-radius: 6px;
  border: 1px solid transparent;
  transition: border-color 0.15s, background 0.15s;
  cursor: grab;
}
.todo-item:hover { border-color: var(--border); }
.todo-item.is-pinned {
  background: var(--pinned-bg);
  border-color: var(--pinned);
}
.todo-item.is-done .todo-text {
  text-decoration: line-through;
  color: var(--done-text);
}
.todo-item.is-done { opacity: 0.6; }

.todo-checkbox {
  margin-top: 2px;
  flex-shrink: 0;
  width: 16px;
  height: 16px;
  accent-color: var(--pinned);
  cursor: pointer;
}
.todo-text {
  flex: 1;
  font-size: 0.9rem;
  line-height: 1.4;
  color: var(--text-primary);
  word-break: break-word;
}
.todo-actions { display: flex; gap: 2px; flex-shrink: 0; opacity: 0; transition: opacity 0.15s; }
.todo-item:hover .todo-actions { opacity: 1; }
.pin-icon.is-pinned { color: var(--pinned); opacity: 1 !important; }

/* === Add form === */
.add-form { margin-top: 10px; display: flex; gap: 6px; }
.add-input {
  flex: 1;
  font-family: var(--font-sans);
  font-size: 0.85rem;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--bg);
  color: var(--text-primary);
  outline: none;
}
.add-input:focus { border-color: var(--border-hover); }
.add-btn {
  font-family: var(--font-sans);
  font-size: 1.1rem;
  padding: 4px 10px;
  border-radius: 6px;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text-secondary);
  cursor: pointer;
}
.add-btn:hover { border-color: var(--border-hover); color: var(--text-primary); }

/* === Empty focus state === */
.focus-empty {
  text-align: center;
  color: var(--text-tertiary);
  font-size: 0.9rem;
  padding: 48px 0;
}
.focus-empty a { color: var(--pinned); text-decoration: none; cursor: pointer; }

/* === Drag ghost === */
.sortable-ghost { opacity: 0.4; }
```

- [ ] **Step 2: Start server and visually verify**

```bash
cd ~/repos/workday-focus
source venv/bin/activate
python app.py
```

Open `http://localhost:5001` in browser. Expected: header renders with title and two buttons, body background is correct. Toggle DevTools → Rendering → Emulate `prefers-color-scheme: dark` and confirm dark mode tokens apply.

- [ ] **Step 3: Commit**

```bash
git add static/style.css
git commit -m "feat: CSS design tokens, 4-column layout, dark mode"
```

---

## Task 8: JS — planning mode

**Files:**
- Modify: `~/repos/workday-focus/static/app.js`

**Interfaces:**
- Consumes: `GET /api/todos`, `POST /api/todos`, `PATCH /api/todos/<id>`, `DELETE /api/todos/<id>`
- Produces: `state.todos`, `render()`, `showError(msg)` — used by Tasks 9 and 10

**Note:** No automated tests. Manual verification: start the server, open the browser, add a todo in each category, mark one done, pin one, confirm rendering.

- [ ] **Step 1: Implement state, API client, and planning mode render in `static/app.js`**

```javascript
// app.js — Workday Focus frontend

const CATEGORIES = ['sales', 'delivery', 'work_admin', 'personal'];
const CATEGORY_LABELS = {
  sales: 'Sales',
  delivery: 'Delivery',
  work_admin: 'Work Admin',
  personal: 'Personal',
};

const state = {
  todos: {},
  showCompleted: false,
};

// === API client ===

async function api(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(path, opts);
  if (res.status === 204) return null;
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

async function fetchTodos() {
  const data = await api('GET', '/api/todos');
  state.todos = data;
}

async function createTodo(category, text) {
  await api('POST', '/api/todos', { category, text });
  await fetchTodos();
}

async function updateTodo(id, updates) {
  await api('PATCH', `/api/todos/${id}`, updates);
  await fetchTodos();
}

async function deleteTodo(id) {
  await api('DELETE', `/api/todos/${id}`);
  await fetchTodos();
}

// === Error banner ===

function showError(msg) {
  const banner = document.getElementById('error-banner');
  banner.textContent = msg;
  banner.classList.remove('hidden');
  setTimeout(() => banner.classList.add('hidden'), 5000);
}

function withError(fn) {
  return async (...args) => {
    try {
      await fn(...args);
    } catch (e) {
      showError(e.message);
    }
  };
}

// === Mode helpers ===

function getMode() {
  return new URLSearchParams(window.location.search).get('mode') || 'planning';
}

function setMode(mode) {
  const url = new URL(window.location);
  if (mode === 'planning') {
    url.searchParams.delete('mode');
  } else {
    url.searchParams.set('mode', mode);
  }
  window.history.pushState({}, '', url);
  render();
}

// === Render ===

function render() {
  const mode = getMode();
  const app = document.getElementById('app');
  const btn = document.getElementById('btn-toggle-mode');

  if (mode === 'focus') {
    btn.textContent = 'Planning Mode';
    btn.classList.add('active');
    renderFocusMode(app);
  } else {
    btn.textContent = 'Focus Mode';
    btn.classList.remove('active');
    renderPlanningMode(app);
  }

  document.getElementById('btn-toggle-completed').classList.toggle(
    'active', state.showCompleted
  );
}

function renderPlanningMode(container) {
  container.innerHTML = '';
  const grid = document.createElement('div');
  grid.className = 'columns';

  CATEGORIES.forEach(cat => {
    const items = (state.todos[cat] || []).filter(
      t => state.showCompleted || !t.done
    );
    grid.appendChild(renderColumn(cat, items));
  });

  container.appendChild(grid);
  initDragDrop();
}

function renderColumn(category, items) {
  const col = document.createElement('div');
  col.className = 'column';
  col.dataset.category = category;

  col.innerHTML = `
    <div class="column-header">
      <span class="column-title">${CATEGORY_LABELS[category]}</span>
    </div>
    <ul class="todo-list" data-category="${category}"></ul>
    <form class="add-form" data-category="${category}">
      <input class="add-input" type="text" placeholder="Add todo…" autocomplete="off">
      <button class="add-btn" type="submit">+</button>
    </form>
  `;

  const list = col.querySelector('.todo-list');
  items.forEach(t => list.appendChild(renderTodoItem(t)));

  col.querySelector('.add-form').addEventListener('submit', withError(async e => {
    e.preventDefault();
    const input = e.target.querySelector('.add-input');
    const text = input.value.trim();
    if (!text) return;
    input.value = '';
    await createTodo(category, text);
    render();
  }));

  return col;
}

function renderTodoItem(todo) {
  const li = document.createElement('li');
  li.className = 'todo-item' +
    (todo.pinned ? ' is-pinned' : '') +
    (todo.done   ? ' is-done'   : '');
  li.dataset.todoId = todo.id;

  li.innerHTML = `
    <input class="todo-checkbox" type="checkbox" ${todo.done ? 'checked' : ''}>
    <span class="todo-text">${escapeHtml(todo.text)}</span>
    <div class="todo-actions">
      <button class="btn-icon pin-icon ${todo.pinned ? 'is-pinned' : ''}" title="Pin">📌</button>
      <button class="btn-icon delete-icon" title="Delete">✕</button>
    </div>
  `;

  li.querySelector('.todo-checkbox').addEventListener('change', withError(async e => {
    await updateTodo(todo.id, { done: e.target.checked });
    render();
  }));

  li.querySelector('.pin-icon').addEventListener('click', withError(async () => {
    await updateTodo(todo.id, { pinned: !todo.pinned });
    render();
  }));

  li.querySelector('.delete-icon').addEventListener('click', withError(async () => {
    await deleteTodo(todo.id);
    render();
  }));

  return li;
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// === Toggle handlers ===

document.getElementById('btn-toggle-mode').addEventListener('click', () => {
  setMode(getMode() === 'focus' ? 'planning' : 'focus');
});

document.getElementById('btn-toggle-completed').addEventListener('click', () => {
  state.showCompleted = !state.showCompleted;
  render();
});

// === Focus mode placeholder (Task 9) ===
function renderFocusMode(container) {
  container.innerHTML = '<p class="focus-empty">Focus mode coming soon.</p>';
}

// === Drag-and-drop placeholder (Task 10) ===
function initDragDrop() {}

// === Init ===
withError(async () => {
  await fetchTodos();
  render();
})();
```

- [ ] **Step 2: Start server and manually verify planning mode**

```bash
python app.py
```

Open `http://localhost:5001`. Verify:
- Four columns render with correct labels
- Add a todo in each column — it appears immediately
- Check a todo — it shows as done (strikethrough)
- Click pin icon — item highlights green
- Click ✕ — item disappears
- "Show Completed" button shows/hides done items

- [ ] **Step 3: Commit**

```bash
git add static/app.js
git commit -m "feat: planning mode — add, done, pin, delete"
```

---

## Task 9: JS — focus mode + toggle

**Files:**
- Modify: `~/repos/workday-focus/static/app.js`

**Interfaces:**
- Consumes: `state.todos`, `getMode()`, `setMode()`, `renderTodoItem()` from Task 8
- Produces: complete `renderFocusMode()` replacing the placeholder

- [ ] **Step 1: Replace the `renderFocusMode` placeholder in `static/app.js`**

Find this block:

```javascript
// === Focus mode placeholder (Task 9) ===
function renderFocusMode(container) {
  container.innerHTML = '<p class="focus-empty">Focus mode coming soon.</p>';
}
```

Replace it with:

```javascript
function renderFocusMode(container) {
  container.innerHTML = '';

  const pinnedByCategory = CATEGORIES.map(cat => ({
    category: cat,
    items: (state.todos[cat] || []).filter(t => t.pinned && !t.done),
  })).filter(g => g.items.length > 0);

  if (pinnedByCategory.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'focus-empty';
    empty.innerHTML = 'Nothing pinned. <a id="go-planning">Go to planning mode</a> to pick your priorities.';
    container.appendChild(empty);
    document.getElementById('go-planning').addEventListener('click', () => setMode('planning'));
    return;
  }

  const list = document.createElement('div');
  list.className = 'focus-list';

  pinnedByCategory.forEach(({ category, items }) => {
    const section = document.createElement('div');
    const label = document.createElement('div');
    label.className = 'focus-category-label';
    label.textContent = CATEGORY_LABELS[category];
    section.appendChild(label);

    const ul = document.createElement('ul');
    ul.className = 'todo-list';
    items.forEach(t => ul.appendChild(renderTodoItem(t)));
    section.appendChild(ul);
    list.appendChild(section);
  });

  container.appendChild(list);
}
```

- [ ] **Step 2: Manually verify focus mode**

With the server running and a few todos pinned:
1. Click "Focus Mode" button — URL becomes `?mode=focus`, only pinned todos show
2. Mark a pinned todo done — it disappears from focus view
3. Unpin an item in planning mode, switch to focus — item is gone
4. Unpin everything, switch to focus — empty state with link shows
5. Refresh with `?mode=focus` in URL — focus mode persists

- [ ] **Step 3: Commit**

```bash
git add static/app.js
git commit -m "feat: focus mode — pinned items, URL param persistence"
```

---

## Task 10: JS — drag-and-drop reordering

**Files:**
- Modify: `~/repos/workday-focus/static/app.js`

**Interfaces:**
- Consumes: `updateTodo()`, `withError()` from Task 8; SortableJS loaded via CDN in `index.html`
- Produces: complete `initDragDrop()` replacing the placeholder; position updates sent to `PATCH /api/todos/<id>`

- [ ] **Step 1: Replace the `initDragDrop` placeholder in `static/app.js`**

Find:

```javascript
// === Drag-and-drop placeholder (Task 10) ===
function initDragDrop() {}
```

Replace with:

```javascript
function initDragDrop() {
  document.querySelectorAll('.todo-list[data-category]').forEach(listEl => {
    Sortable.create(listEl, {
      animation: 150,
      ghostClass: 'sortable-ghost',
      onEnd: withError(async () => {
        const items = [...listEl.querySelectorAll('[data-todo-id]')];
        await Promise.all(
          items.map((el, index) =>
            updateTodo(parseInt(el.dataset.todoId), { position: index + 1 })
          )
        );
        // No render() here — positions updated in DB; visual order already correct from drag
      }),
    });
  });
}
```

- [ ] **Step 2: Manually verify drag-and-drop**

With the server running and multiple todos in one category:
1. Drag a todo to a new position within its column — it stays there
2. Refresh the page — order is preserved (persisted in DB)
3. Drag on a touch device via browser DevTools device emulation — drag works

- [ ] **Step 3: Run the full test suite to confirm no regressions**

```bash
pytest tests/test_api.py -v
```

Expected: all tests `PASSED`

- [ ] **Step 4: Commit**

```bash
git add static/app.js
git commit -m "feat: drag-and-drop reordering via SortableJS"
```

---

## Task 11: Deployment — launchd service + README

**Files:**
- Create: `~/repos/workday-focus/com.matthewrouser.workday-focus.plist`
- Create: `~/repos/workday-focus/README.md`

**Note:** This task is executed on the Mac Mini, not the dev machine. No automated test — verify by checking `launchctl list` and confirming the app is reachable.

- [ ] **Step 1: Create `com.matthewrouser.workday-focus.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.matthewrouser.workday-focus</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/matthewrouser/repos/workday-focus/venv/bin/python</string>
    <string>/Users/matthewrouser/repos/workday-focus/app.py</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/matthewrouser/repos/workday-focus</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/Users/matthewrouser/repos/workday-focus/workday-focus.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/matthewrouser/repos/workday-focus/workday-focus.log</string>
</dict>
</plist>
```

- [ ] **Step 2: Create `README.md`**

```markdown
# Workday Focus

Daily work-focus todo app. Four categories (Sales, Delivery, Work Admin, Personal),
drag-and-drop backlog, pin priorities, collapse to focus view.

**Access:** http://<mac-mini-ip>:5001 (local) or http://<tailscale/wireguard-ip>:5001 (phone)

## Dev setup (MacBook)

    cd ~/repos/workday-focus
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    python app.py          # → http://localhost:5001

## Tests

    pytest tests/ -v

## Deploy to Mac Mini

SSH into the Mac Mini, then:

    cd ~/repos
    git clone <repo-url> workday-focus
    cd workday-focus
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt

    # Install launchd service
    cp com.matthewrouser.workday-focus.plist ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.matthewrouser.workday-focus.plist

    # Verify it's running
    launchctl list | grep workday-focus
    curl http://localhost:5001/api/todos

## Managing the service

    # Stop
    launchctl unload ~/Library/LaunchAgents/com.matthewrouser.workday-focus.plist

    # Restart after code changes
    launchctl unload ~/Library/LaunchAgents/com.matthewrouser.workday-focus.plist
    launchctl load  ~/Library/LaunchAgents/com.matthewrouser.workday-focus.plist

## Logs

    tail -f ~/repos/workday-focus/workday-focus.log
```

- [ ] **Step 3: Commit the plist and README**

```bash
git add com.matthewrouser.workday-focus.plist README.md
git commit -m "feat: launchd service plist + README"
```

- [ ] **Step 4: Deploy to Mac Mini**

SSH to Mac Mini and run the deploy steps from the README.

- [ ] **Step 5: Verify service is running**

On Mac Mini:
```bash
launchctl list | grep workday-focus
curl http://localhost:5001/api/todos
```

Expected: service listed with no error code; curl returns `{"sales":[],"delivery":[],"work_admin":[],"personal":[]}` (or your actual todos)

- [ ] **Step 6: Verify from phone**

Connect phone to WireGuard VPN, open the Mac Mini's WireGuard IP at port 5001 in the mobile browser. Confirm the app loads and todos sync.
```
