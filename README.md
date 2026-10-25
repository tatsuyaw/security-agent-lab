# security-agent-lab

AWS Security Agent(AWS Continuum)のペネトレーションテストを、意図的に脆弱な自作 Web アプリに対して
**公開方式(インターネット公開 + ALB + AWS WAF)** で実行し、仕組みと検出能力を確かめるための検証環境。

- 検証の記事(仕組みと設計、手順、結果)が正本で、このリポジトリはそのコードを置く場所: https://www.infra.jp/docs/aws/vulnerability-assessment/security-agent/
- WAF の既定動作を遮断にし、Security Agent のカスタムヘッダーを持つリクエストだけを通す。第三者は対象アプリに届かない
- EC2 にインターネットへの経路はない(NAT なし)。構築に必要な通信は S3 ゲートウェイエンドポイントと SSM のインターフェースエンドポイントで賄う

> **注意**: `app/` は脆弱性を意図的に仕込んだアプリである。この Terraform の構成(WAF の既定動作が遮断)以外で、インターネットに公開しないこと。

## 構成

```
app/                               意図的に脆弱な Flask アプリ(仕込みの一覧は docs/planted-vulnerabilities.md)
terraform/modules/
  vulnapp/                         対象アプリの EC2 一式(wheel 用 S3、IAM ロール、インスタンス、user_data)
  vpc-endpoints/                   S3 ゲートウェイ + SSM インターフェースエンドポイント(NAT なしで構築・接続する)
  subnet-flow-logs/                サブネットの VPC フローログ
  security-agent-roles/            Application ロールと Pentest サービスロール
terraform/public-method/                  公開方式: ALB + ACM + WAF の背後に対象アプリ
  dns-zone/                        保有ドメインから委任するサブドメインのホストゾーン(state 1)
  network-app/                     VPC、エンドポイント、EC2、ALB、証明書、WAF(state 2)
  security-agent/                  Application、Agent Space、Target Domain(DNS_TXT)、Pentest(state 3)
docs/                              補助資料
```

- Security Agent の Application(Web アプリ)と Application ロールはアカウントに 1 つだけ。すでに Security Agent を使っているアカウントでは `create_application = false` にして、この Terraform では作らない
- 公開版の WAF は既定動作が遮断で、Pentest に付けるカスタムヘッダーを持つリクエストだけ通す。`waf_mode` でヘッダー許可ルールとマネージドルール群の評価順を入れ替える(`agent-first` → `managed-first`)
- EC2 にインターネットへの経路はない。構築に必要な通信は VPC エンドポイント経由

## 使い方(公開版。詳細は手順書)

```bash
cd terraform/public-method/dns-zone && terraform init
cp terraform.tfvars.example terraform.tfvars      # account_id / profile / zone_name(保有ドメインの配下)を記入
terraform apply                                   # 出力されたネームサーバーをレジストラに NS レコードとして登録
cd ../network-app && terraform init && cp terraform.tfvars.example terraform.tfvars
python3 -m pip download -d wheels --only-binary=:all: --python-version 3.9 \
  --implementation cp --abi cp39 --platform manylinux2014_x86_64 --require-hashes -r ../../../app/requirements.txt
terraform plan -out=tfplan && terraform apply tfplan
cd ../security-agent && terraform init && cp terraform.tfvars.example terraform.tfvars
terraform plan -out=tfplan && terraform apply tfplan
```

ドメイン検証の実行(Verify)、Task-hour 上限の設定、ペンテストの実行は Security Agent の画面で行う。片付けは逆順に `terraform destroy`。

## 置かないもの

- `terraform.tfvars`(実アカウント ID・プロファイル名)、`*.tfstate`、`*.tfplan`
- 認証情報、本物のドメイン名、スクリーンショット
