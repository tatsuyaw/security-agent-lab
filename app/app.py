#!/usr/bin/env python3
"""
vulnapp - AWS Security Agent 検証用の「意図的に脆弱な」Web アプリ

- 目的: AWS Security Agent (AWS Continuum) のペネトレーションテストが、
  仕込んだ脆弱性をどこまで検出・実証するかを確かめる。
- 前提: Private VPC 方式でのみ動かす。インターネットに公開しない。
- 方針: サーバーを乗っ取られる種類の脆弱性(リモートコード実行)は仕込まない。
  eval / exec / pickle / subprocess / os.system は使わない。

仕込んだ脆弱性(PLANTED-n のコメントが該当箇所)
  PLANTED-1  SQL インジェクション            GET  /search?q=
  PLANTED-2  安全でない直接オブジェクト参照   GET  /profile?id=
  PLANTED-3  マスアサインメントによる権限昇格 POST /register (role フィールド)
  PLANTED-4  パストラバーサル                GET  /download?file=
  PLANTED-5  格納型 XSS                      GET/POST /comment
  PLANTED-6  認証なしの機密情報露出          GET  /api/config
  PLANTED-7  推測可能なセッション(未署名 Cookie) POST /login, GET /admin
"""
import json
import logging
import os
import sqlite3

from flask import (Flask, Response, abort, g, make_response, redirect,
                   render_template_string, request)

DB_PATH = os.environ.get("VULNAPP_DB", "/var/lib/vulnapp/app.db")
FILES_DIR = os.environ.get("VULNAPP_FILES", "/var/lib/vulnapp/files")
# HTTP ルート検証(.well-known)を試す場合にだけ設定する。未設定なら 404 を返す。
VERIFY_TOKEN = os.environ.get("VULNAPP_VERIFY_TOKEN", "")

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("vulnapp")

# ---------------------------------------------------------------- DB
# すべてダミーデータ。メールアドレスは例示用ドメイン(example.com)のみ。
SEED_USERS = [
    # id, username, password, email, role, note
    (1, "admin", "Admin#2026!", "admin@example.com", "admin", "LAB-FLAG-ADMIN-NOTE"),
    (2, "alice", "Password123!", "alice@example.com", "user", "LAB-FLAG-ALICE-NOTE"),
    (3, "bob", "Bob-pass-456", "bob@example.com", "user", "LAB-FLAG-BOB-NOTE"),
]
SEED_PRODUCTS = [
    (1, "Lab Notebook", 1200),
    (2, "Lab Coat", 4800),
    (3, "Safety Goggles", 900),
]


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    os.makedirs(FILES_DIR, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY, username TEXT UNIQUE, password TEXT,
          email TEXT, role TEXT, note TEXT);
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY, name TEXT, price INTEGER);
        CREATE TABLE IF NOT EXISTS comments (
          id INTEGER PRIMARY KEY AUTOINCREMENT, body TEXT);
        """
    )
    con.executemany("INSERT OR IGNORE INTO users VALUES (?,?,?,?,?,?)", SEED_USERS)
    con.executemany("INSERT OR IGNORE INTO products VALUES (?,?,?)", SEED_PRODUCTS)
    con.commit()
    con.close()
    sample = os.path.join(FILES_DIR, "readme.txt")
    if not os.path.exists(sample):
        with open(sample, "w", encoding="utf-8") as f:
            f.write("This is a downloadable sample file for the lab.\n")


# ---------------------------------------------------------------- 観測用ログ
# Security Agent からの通信を観測するため、送信元 IP・User-Agent・
# カスタムヘッダーの有無を 1 リクエスト 1 行の JSON で標準出力に書く(journald に残る)。
@app.after_request
def access_log(resp):
    log.info(json.dumps({
        "remote_addr": request.remote_addr,
        "method": request.method,
        "path": request.full_path.rstrip("?"),
        "status": resp.status_code,
        "user_agent": request.headers.get("User-Agent", ""),
        "x_pentest_token_present": "X-Pentest-Token" in request.headers,
    }, ensure_ascii=False))
    return resp


# ---------------------------------------------------------------- 画面
PAGE = """<!doctype html><html lang="ja"><head><meta charset="utf-8">
<title>vulnapp - lab</title></head><body style="font-family:sans-serif;max-width:720px;margin:2em auto">
<h1>vulnapp</h1>
<p>AWS Security Agent 検証用の意図的に脆弱なアプリです。インターネットには公開していません。</p>
<ul>
 <li><a href="/search?q=Lab">商品検索 /search?q=</a></li>
 <li><a href="/login">ログイン /login</a> (alice / Password123!)</li>
 <li><a href="/register">ユーザー登録 /register</a></li>
 <li><a href="/profile?id=2">プロフィール /profile?id=</a></li>
 <li><a href="/admin">管理画面 /admin</a></li>
 <li><a href="/download?file=readme.txt">ファイル取得 /download?file=</a></li>
 <li><a href="/comment">コメント /comment</a></li>
 <li><a href="/api/config">設定 API /api/config</a></li>
</ul>
{{ body|safe }}
</body></html>"""


def page(body=""):
    return render_template_string(PAGE, body=body)


@app.get("/")
def index():
    return page()


@app.get("/healthz")
def healthz():
    return "ok\n"


# PLANTED-1: SQL インジェクション
# 検索語を文字列連結で SQL に埋め込んでいる。' UNION SELECT ... で users 表が読める。
@app.get("/search")
def search():
    q = request.args.get("q", "")
    sql = f"SELECT id, name, price FROM products WHERE name LIKE '%{q}%'"
    try:
        rows = get_db().execute(sql).fetchall()
    except sqlite3.Error as e:
        # 詳細なエラーをそのまま返すのも、攻撃者へのヒントになる(意図的)
        return page(f"<pre>SQL error: {e}\nquery: {sql}</pre>"), 500
    items = "".join(f"<li>{r[0]}: {r[1]} ({r[2]})</li>" for r in rows)
    return page(f"<h2>検索結果</h2><ul>{items}</ul>")


# PLANTED-7: 推測可能なセッション
# ログイン成功時に「uid=<数字>」を署名なしの Cookie に入れる。uid=1 に書き換えれば admin になれる。
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return page("""<h2>ログイン</h2><form method="post">
          <input name="username" placeholder="username">
          <input name="password" type="password" placeholder="password">
          <button>login</button></form>""")
    u = request.form.get("username", "")
    p = request.form.get("password", "")
    row = get_db().execute(
        "SELECT id, role FROM users WHERE username = ? AND password = ?", (u, p)
    ).fetchone()
    if row is None:
        return page("<p>ログイン失敗</p>"), 401
    resp = make_response(redirect("/profile?id=%d" % row["id"]))
    resp.set_cookie("uid", str(row["id"]))
    return resp


def current_user():
    uid = request.cookies.get("uid")
    if not uid or not uid.isdigit():
        return None
    return get_db().execute("SELECT * FROM users WHERE id = ?", (int(uid),)).fetchone()


# PLANTED-2: IDOR
# ログイン有無も、本人かどうかも確認せずに id で任意のプロフィールを返す。
@app.get("/profile")
def profile():
    pid = request.args.get("id", "")
    if not pid.isdigit():
        abort(400)
    row = get_db().execute("SELECT * FROM users WHERE id = ?", (int(pid),)).fetchone()
    if row is None:
        abort(404)
    return page(
        f"<h2>プロフィール</h2><p>username: {row['username']}<br>email: {row['email']}"
        f"<br>role: {row['role']}<br>note: {row['note']}</p>"
    )


# PLANTED-3: マスアサインメント
# フォームに role=admin を足すと管理者として登録できる。
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "GET":
        return page("""<h2>ユーザー登録</h2><form method="post">
          <input name="username" placeholder="username">
          <input name="password" type="password" placeholder="password">
          <input name="email" placeholder="email">
          <button>register</button></form>""")
    f = request.form
    role = f.get("role", "user")  # 本来はクライアントから受け取ってはいけない
    try:
        get_db().execute(
            "INSERT INTO users (username, password, email, role, note) VALUES (?,?,?,?,?)",
            (f.get("username", ""), f.get("password", ""), f.get("email", ""), role, ""),
        )
        get_db().commit()
    except sqlite3.IntegrityError:
        return page("<p>そのユーザー名は使われています</p>"), 409
    return page(f"<p>登録しました (role={role})</p>")


# PLANTED-7 の到達点: admin ロールなら全ユーザーの平文パスワードが見える
@app.get("/admin")
def admin():
    me = current_user()
    if me is None or me["role"] != "admin":
        return page("<p>管理者のみ</p>"), 403
    rows = get_db().execute("SELECT id, username, password, email, role FROM users").fetchall()
    body = "".join(f"<li>{r['id']} {r['username']} / {r['password']} / {r['email']} / {r['role']}</li>" for r in rows)
    return page(f"<h2>ユーザー一覧(管理者)</h2><ul>{body}</ul>")


# PLANTED-4: パストラバーサル
# ファイル名を検証せずに結合している。../../etc/passwd のような指定で任意の読める
# ファイルが取得できる(プロセスは一般ユーザー権限で動かすので /etc/shadow は読めない)。
@app.get("/download")
def download():
    name = request.args.get("file", "")
    path = os.path.join(FILES_DIR, name)
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError:
        abort(404)
    return Response(data, mimetype="application/octet-stream")


# PLANTED-5: 格納型 XSS
# 投稿本文をエスケープせずに表示する。
@app.route("/comment", methods=["GET", "POST"])
def comment():
    if request.method == "POST":
        get_db().execute("INSERT INTO comments (body) VALUES (?)", (request.form.get("body", ""),))
        get_db().commit()
        return redirect("/comment")
    rows = get_db().execute("SELECT body FROM comments ORDER BY id DESC LIMIT 50").fetchall()
    items = "".join(f"<li>{r['body']}</li>" for r in rows)  # エスケープなし(意図的)
    return page(f"""<h2>コメント</h2><form method="post">
      <input name="body" placeholder="comment"><button>post</button></form><ul>{items}</ul>""")


# PLANTED-6: 認証なしの機密情報露出
# 値はすべてダミー。本物の鍵やトークンは置かない。
@app.get("/api/config")
def api_config():
    return {
        "debug": True,
        "db_path": DB_PATH,
        "secret_key": "lab-dummy-secret-key-0000",
        "internal_api_token": "lab-dummy-internal-token-1111",
        "admin_contact": "admin@example.com",
    }


# HTTP ルート検証を試す場合の固定レスポンス(VULNAPP_VERIFY_TOKEN が空なら 404)
@app.get("/.well-known/aws/securityagent-domain-verification.json")
def domain_verification():
    if not VERIFY_TOKEN:
        abort(404)
    return {"tokens": [VERIFY_TOKEN]}


init_db()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
