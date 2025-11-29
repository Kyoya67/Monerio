<div align="center">
  <img src="./Monerio.png" alt="Monerio Logo" width="280" />

  <p><strong>自動化された個人向け金融レイヤー</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity" alt="Solidity" />
    <img src="https://img.shields.io/badge/Foundry-Framework-DEA584?logo=ethereum" alt="Foundry" />
    <img src="https://img.shields.io/badge/Chainlink-CRE-375BD2?logo=chainlink" alt="Chainlink" />
    <img src="https://img.shields.io/badge/UUPS-Upgradeable-8B5CF6" alt="UUPS" />
  </p>
</div>

---

# 1. プロジェクト概要

**Monerio** は、ユーザーが一度資産を預けるだけで:

- 資産を安全に保管し
- 自動的に運用され（v2 以降）
- 必要な生活費のみ毎日または任意周期で EOA に送金され
- 将来的にはカード決済と連動し、使いすぎを防止できる

**自動化された個人向け金融レイヤー**を提供するプロジェクト。

---

# 2. 背景と課題

## 現代ユーザーの課題

- 資産運用の継続が難しい
- 生活費管理が困難
- カード決済の使いすぎ問題
- 銀行・家計簿アプリでは運用と予算管理が統合されていない

## 技術背景

スマートコントラクト、Chainlink CRE、AA Wallet により、

資産保管・運用・予算管理・自動支払いを統合した新しい金融モデルが実現可能となった。

---

# 3. Monerio が提供する価値

- 自動運用と自動送金の統合
- 必要資金のみを EOA に送金し使いすぎを防止
- 資産を Vault で安全に保管
- 将来的なカード連携による現実世界の支払い最適化
- 何もしなくても家計が最適化される体験

---

# 4. スコープ

## 本書で扱う

- Monerio のビジネス要件
- 機能要件・非機能要件
- v1 / v2 の定義
- フロー図およびシステム構成図

## 本書で扱わない

- 実装詳細（別途仕様書）
- CRE の TypeScript 実装
- 画面設計

---

# 5. バージョン定義

## 5.1 v1（JPYC EX 想定モデル）

### 目的

日本で確実に運用できる MVP を構築する。

### 想定フロー

```mermaid
sequenceDiagram
    participant Salary as 給料
    participant OnRamp as JPYC EX（オンランプ）
    participant Vault as Vaultコントラクト
    participant CRE as CRE Workflow
    participant EOA as ユーザーEOA
    participant OffRamp as JPYC EX（オフランプ）
    participant Card as デビットカード

    Salary->>OnRamp: 給料をオンランプ
    OnRamp->>Vault: deposit（ユーザーが送金）
    CRE->>Vault: payout（毎週）
    Vault->>EOA: 生活費送金（毎週）
    EOA->>OffRamp: オフランプ
    OffRamp->>Card: デビットカードで支払い

```

### 提供機能

- deposit / payout
- dailyLimit 設定
- UUPS によるアップグレード
- CRE cron
- 家賃・光熱費の自動支払いなし
- カード連携なし

---

## 5.2 v2（Crypto カード / AA Wallet 対応モデル）

### 目的

Crypto デビット/クレカや AA Wallet と連動し、完全自動家計を実現する。

### 想定フロー

```mermaid
sequenceDiagram
    participant Salary as 給料
    participant Vault as Vaultコントラクト
    participant CRE as CRE Workflow
    participant ConstantEOA as 固定費EOA
    participant LivingEOA as 生活費EOA
    participant ConstantCard as 固定費カード
    participant LivingCard as 生活費カード

    Salary->>Vault: deposit（ユーザー）
    CRE->>Vault: payout（毎月）
    Vault->>ConstantEOA: 固定費送金（毎月）
    ConstantEOA->>ConstantCard: カード支払い
    
    CRE->>Vault: payout（毎日）
    Vault->>LivingEOA: 生活費送金（毎日）
    LivingEOA->>LivingCard: カード支払い

```

### 追加提供機能

- 家賃・光熱費の自動送金
- カード残高の自動チャージ
- 複数 EOA のカテゴリ管理
- DeFi 運用
- AA Wallet の自動支払い

---

# 7.システム構成図（Mermaid）

```mermaid
flowchart TB
    subgraph User["ユーザー操作"]
        Wallet[User Wallet]
        Frontend[Frontend]
    end

    subgraph Blockchain["Blockchain (Polygon等)"]
        subgraph Vault["MonerioVault (UUPS Proxy)"]
            deposit["deposit(amount)"]
            setLimit["setDailyLimit(amount)"]
            payout["payout(user)"]
            balance["balances mapping"]
            limit["dailyLimit mapping"]
        end
        Token["ERC20 Token (JPYC等)"]
    end

    subgraph Automation["自動化レイヤー"]
        CRE["Chainlink CRE<br/>(Cron Trigger)"]
    end

    EOA[User EOA<br/>生活費受取先]

    %% User flows
    Wallet -->|approve + deposit| Frontend
    Frontend -->|RPC| deposit
    Frontend -->|RPC| setLimit

    deposit --> balance
    setLimit --> limit

    %% Automation flow
    CRE -->|定期実行| payout
    payout -->|transfer| Token
    Token -->|送金| EOA

    %% Token flow
    Wallet -->|ERC20| Token
    Token -->|safeTransferFrom| Vault
```

---

# 8. ロードマップ

## Phase 1（v1 / MVP）

- deposit / payout
- dailyLimit
- CRE cron
- JPYC EX 前提の設計

## Phase 2（v2）

- 家賃・光熱費自動送金
- カード残高自動管理
- DeFi 運用

## Phase 3

- AA Wallet による完全自動化
- Spend Policy のオンチェーン化