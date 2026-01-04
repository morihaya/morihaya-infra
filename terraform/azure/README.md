# Terraform Azure

個人用 Azure インフラストラクチャを Terraform で管理するディレクトリです。

## 概要

HCP Terraform を使用して Azure リソースを管理しています。

## 認証

HCP Terraform と Azure 間は OIDC（Workload Identity Federation）で認証しています。

### 必要な環境変数（HCP Terraform Workspace で設定）

| 変数名 | 説明 |
|--------|------|
| `ARM_SUBSCRIPTION_ID` | Azure サブスクリプション ID |
| `ARM_TENANT_ID` | Azure AD テナント ID |
| `TFC_AZURE_PROVIDER_AUTH` | `true` に設定 |
| `TFC_AZURE_RUN_CLIENT_ID` | Azure AD アプリケーションのクライアント ID |

### Azure 側の設定

Azure AD アプリケーションに Federated Identity Credential を設定する必要があります：

- **Issuer**: `https://app.terraform.io`
- **Subject**: `organization:morihaya:project:Azure:workspace:morihaya-infra-azure:run_phase:*`
- **Audience**: `api://AzureADTokenExchange`
