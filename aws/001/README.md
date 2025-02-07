# 📌 No.1：基本的な VPC 構成

## 🎯 目標

AWS 上に **VPC を作成し、パブリックサブネットと EC2 をデプロイ** する。

## ✅ 構成

### 🔹 VPC

- **CIDR**: `10.0.0.0/16`

### 🔹 サブネット

- **パブリックサブネット**: `10.0.1.0/24`（`us-east-1a`）

### 🔹 インターネットゲートウェイ (IGW)

- **VPC にアタッチする**

### 🔹 ルートテーブル

- `0.0.0.0/0` → **IGW**
- **パブリックサブネットに関連付ける**

### 🔹 EC2 インスタンス

- **AMI**: Amazon Linux 2023 (最新)
- **インスタンスタイプ**: `t2.micro`
- **キーペア**: `infra-100-knock`
- **パブリック IP**: **有効**
- **セキュリティグループ**: **SSH (22 番ポート) を許可**

### 🔹 EIP (Elastic IP)

- **EC2 にアタッチする**

## ✅ Terraform での実装に必要なリソース

1. **VPC (`aws_vpc`)**
2. **サブネット (`aws_subnet`)**
3. **インターネットゲートウェイ (`aws_internet_gateway`)**
4. **ルートテーブル (`aws_route_table`)**
5. **ルートテーブルとサブネットの関連付け (`aws_route_table_association`)**
6. **セキュリティグループ (`aws_security_group`)**
7. **Amazon Linux 2023 の AMI (`data "aws_ami"`)**
8. **EC2 インスタンス (`aws_instance`)**
9. **Elastic IP (`aws_eip`)**
10. **EIP を EC2 にアタッチ (`aws_eip_association`)**

---

## 🎯 達成条件

- `terraform apply` でインフラがデプロイできること
- EC2 に **SSH で接続** できること (`ssh -i infra-100-knock.pem ec2-user@パブリックIP`)
- AWS コンソールでリソースが正しく作成されていることを確認する

---

💡 **Terraform のコードが書けたら見せてくれればレビューするよ！🔥**
