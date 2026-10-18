# vulnapp

AWS Security Agent 検証用の意図的に脆弱な Flask アプリ。仕込んだ脆弱性の一覧は `app.py` 冒頭の docstring と、
各関数の `PLANTED-n` コメントを参照。

- 実行環境は Terraform(`terraform/network-app`)の user_data が組み立てる(venv + gunicorn、ポート 80、専用ユーザー)
- ローカルで挙動を見るだけなら次で動く(127.0.0.1:8080 にのみバインド)

```bash
python3 -m venv .venv && .venv/bin/pip install --require-hashes -r requirements.txt
VULNAPP_DB=/tmp/vulnapp.db VULNAPP_FILES=/tmp/vulnapp-files .venv/bin/python app.py
```

インターネットに公開しないこと。
