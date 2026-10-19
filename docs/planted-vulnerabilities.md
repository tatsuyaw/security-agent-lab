# 対象アプリ(app/app.py)に仕込んだ脆弱性

AWS Security Agent の検出能力を確かめるために、意図的に作り込んだ脆弱性の一覧。
以前は app.py の冒頭と各関数の直前にコメントで書いていたが、1 回目と 2 回目の検証で、エージェントがパストラバーサルを使って app.py を取得し、このコメントを読めることが分かった。答えを見られる状態での評価を避けるため、3 回目以降はこのファイルに分離した(EC2 には app.py だけが配置され、このファイルは置かれない)。

| ID | 種類 | 場所(関数) | 内容 |
|---|---|---|---|
| PLANTED-1 | SQL インジェクション | GET /search(search) | 検索語を文字列連結で SQL に埋め込んでいる |
| PLANTED-2 | 安全でない直接オブジェクト参照(IDOR) | GET /profile(profile) | ログインの有無も本人かどうかも確認せず、id で任意のプロフィールを返す |
| PLANTED-3 | マスアサインメントによる権限昇格 | POST /register(register) | フォームの role の値をそのまま保存する |
| PLANTED-4 | パストラバーサル | GET /download(download) | ファイル名を検証せずにパスへ結合している(プロセスは一般ユーザー権限なので /etc/shadow は読めない) |
| PLANTED-5 | 格納型 XSS | GET/POST /comment(comment) | 投稿本文をエスケープせずに表示する |
| PLANTED-6 | 認証なしの機密情報露出 | GET /api/config(api_config) | 設定値を認証なしで返す(値はすべてダミー) |
| PLANTED-7 | 推測可能なセッション | POST /login(login)、GET /admin(admin) | ログイン時に uid=<数字> を署名なしの Cookie に入れる。admin ロールなら /admin で全利用者の平文パスワードが見える |

リモートコード実行につながる脆弱性は仕込んでいない(eval、exec、pickle、subprocess、os.system は使わない)。
