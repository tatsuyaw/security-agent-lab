# security-agent-lab

AWS Security Agent(AWS Continuum)の **Private VPC 方式ペネトレーションテスト**を、
意図的に脆弱な自作 Web アプリに対して実行し、仕組みと検出能力を確かめるための検証環境。

- 検証手順書(infra.jp 記事ドラフト)が正本。このリポジトリはそのコードを置く場所
- 初回は NAT Gateway なし(インターネットへの経路がない VPC)で動かす。EC2 の構築は S3 ゲートウェイエンドポイント、SSM 接続はインターフェースエンドポイントで賄う
- `enable_nat = true` で NAT Gateway を追加できる。Security Agent が GitHub のソースコードを参照する手順で必要になるかを検証で確かめる
- 対象アプリは VPC 内からしか到達できない

## 構成

```
app/                               意図的に脆弱な Flask アプリ(仕込みは app.py 冒頭に一覧)
terraform/modules/
  vulnapp/                         対象アプリの EC2 一式(wheel 用 S3、IAM ロール、インスタンス、user_data)
  vpc-endpoints/                   S3 ゲートウェイ + SSM インターフェースエンドポイント(NAT なしで構築・接続する)
  subnet-flow-logs/                サブネットの VPC フローログ
  security-agent-roles/            Application ロールと Pentest サービスロール
terraform/public-method/                  公開方式(本命): ALB + ACM + WAF の背後に対象アプリ
  dns-zone/                        保有ドメインから委任するサブドメインのホストゾーン(state 1)
  network-app/                     VPC、エンドポイント、EC2、ALB、証明書、WAF(state 2)
  security-agent/                  Application、Agent Space、Target Domain(DNS_TXT)、Pentest(state 3)
terraform/private-method/          Private VPC 方式: 閉域構成(未検証のため、検証が済むまでリポジトリには含めない)
  network-app/                     VPC、エンドポイント、EC2、プライベートホストゾーン(state 1)
  security-agent/                  Agent Space、Target Domain(PRIVATE_VPC)、Pentest(state 2)
docs/                              補助資料
```

- Security Agent の Application はアカウントに 1 つだけ。先に apply する側で `create_application = true`、もう一方は `false` にする
- 公開版の WAF は既定動作が遮断で、Pentest に付けるカスタムヘッダーを持つリクエストだけ通す。`waf_mode` でヘッダー許可ルールとマネージドルール群の評価順を入れ替える(`agent-first` → `managed-first`)
- どちらの版も EC2 にインターネットへの経路はない。構築に必要な通信は VPC エンドポイント経由

## 使い方(公開版。詳細は手順書)

```bash
cd terraform/public-method/dns-zone && terraform init
cp terraform.tfvars.example terraform.tfvars      # account_id / profile / zone_name(保有ドメインの配下)を記入
terraform apply                                   # 出力されたネームサーバーをレジストラに NS レコードとして登録
cd ../network-app && terraform init && cp terraform.tfvars.example terraform.tfvars
python3 -m pip download -d wheels --only-binary=:all: --python-version 3.9 \
  --implementation cp --abi cp39 --platform manylinux2014_x86_64 flask==3.1.1 gunicorn==23.0.0
terraform plan -out=tfplan && terraform apply tfplan
cd ../security-agent && terraform init && cp terraform.tfvars.example terraform.tfvars
terraform plan -out=tfplan && terraform apply tfplan
```

ドメイン検証の実行(Verify)、Task-hour 上限の設定、ペンテストの実行は Security Agent の画面で行う。片付けは逆順に `terraform destroy`。

## 置かないもの

- `terraform.tfvars`(実アカウント ID・プロファイル名)、`*.tfstate`、`*.tfplan`
- 認証情報、本物のドメイン名、スクリーンショット
