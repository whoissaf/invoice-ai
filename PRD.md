# 📋 Product Requirement Document (PRD) — Backend
## Smart Invoice Financing Broker
**Nama Produk:** InvoiceFlow AI
**Versi:** 1.0 (Backend MVP)
**Tanggal:** 10 September 2026
**Status:** Final Draft untuk Pengembangan
**Lingkup:** Backend Services, Smart Contracts, API, Database, AI Engine, Compliance

---

## 1. Ringkasan Eksekutif

**InvoiceFlow AI** adalah platform backend untuk marketplace pembiayaan invoice (invoice financing) berbasis blockchain dan AI. Platform ini memungkinkan UMKM menjual invoice yang belum dibayar kepada investor dengan diskon, mendapatkan likuiditas instan, sementara investor memperoleh yield dari pembayaran invoice. Backend mengorkestrasi seluruh siklus hidup invoice — dari onboarding, verifikasi dokumen, credit scoring berbasis AI, tokenisasi, lelang, escrow, hingga settlement otomatis dan penanganan default.

**Masalah yang dipecahkan:**
- 80% perusahaan di negara berkembang melaporkan keterlambatan pembayaran, dengan rata-rata periode pembayaran 66 hari.
- UMKM mengalami kekurangan pendanaan $5.2 triliun per tahun di negara berkembang.
- Proses factoring tradisional memerlukan dokumentasi ekstensif dan manual yang memperlambat pembiayaan.

**Solusi backend:**
- Microservices event-driven dengan Kafka untuk workflow time-sensitive (lelang, jatuh tempo, default).
- Smart contract ERC-721 untuk tokenisasi invoice + ERC-4626 vault untuk funding pool.
- AI credit scoring engine yang menganalisis ratusan data point secara real-time.
- KYC/AML compliance terintegrasi dengan verifikasi counterparty dan continuous monitoring.
- Escrow-only settlement flow untuk keamanan dana investor.

---

## 2. Tujuan Produk

### 2.1 Tujuan Bisnis
| Metrik | Target 6 Bulan | Target 12 Bulan |
|--------|----------------|-----------------|
| Invoice terfunding | 500 | 5.000 |
| Total volume pembiayaan | $5M | $100M |
| Investor aktif | 100 | 1.000 |
| UMKM onboarded | 200 | 2.000 |
| Default rate | < 3% | < 2% |
| Waktu rata-rata dari upload ke funding | < 48 jam | < 6 jam |

### 2.2 Tujuan Teknis
- Mendukung 10.000 invoice concurrent tanpa degradasi.
- Waktu respons API < 500ms untuk operasi read, < 2s untuk credit scoring.
- Uptime 99,9% untuk core services.
- Settlement on-chain < 30 detik dari konfirmasi pembayaran.
- Audit trail immutable untuk setiap transaksi.

---

## 3. Arsitektur Sistem

### 3.1 Diagram Arsitektur High-Level

```
┌─────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY (KONG)                          │
│         JWT Validation · Rate Limiting · CORS · Routing            │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  USER SERVICE │      │INVOICE SERVICE│      │MARKETPLACE SVC│
│  Auth · KYC   │      │ Upload · OCR  │      │ Listing · Bid │
│  Profile      │      │ Validation    │      │ Auction       │
└───────┬───────┘      └───────┬───────┘      └───────┬───────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   EVENT BUS (Kafka)  │
                    │  invoice.created     │
                    │  invoice.verified    │
                    │  bid.placed          │
                    │  auction.closed      │
                    │  loan.created        │
                    │  payment.received    │
                    │  payment.overdue     │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ CREDIT SCORE  │    │   PAYMENT     │    │  NOTIFICATION │
│ SERVICE       │    │   SERVICE     │    │  SERVICE      │
│ AI · ML       │    │ Escrow·Settle │    │ Email · Push  │
└───────┬───────┘    └───────┬───────┘    └───────────────┘
        │                    │
        ▼                    ▼
┌───────────────┐    ┌───────────────┐
│  BLOCKCHAIN   │    │   DATABASE    │
│  SERVICE      │    │  PostgreSQL   │
│  ERC-721      │    │  + Redis      │
│  ERC-4626     │    │  + Supabase   │
└───────────────┘    └───────────────┘
```

### 3.2 Stack Teknologi Backend

| Layer | Teknologi | Alasan |
|-------|-----------|--------|
| **API Gateway** | KONG atau Nginx | JWT validation, rate limiting, routing, TLS termination |
| **Service Runtime** | Node.js 20 + TypeScript / Python 3.11 + FastAPI | Node untuk orchestration & I/O-heavy, Python untuk AI/ML & OCR |
| **Event Bus** | Apache Kafka | Async communication untuk workflow panjang: auction, repayment, default |
| **Database Utama** | PostgreSQL 15 | Relational, ACID, JSONB untuk metadata fleksibel, mendukung migrasi SQL |
| **Cache** | Redis | Session, rate limiting, queue ringan, idempotency keys |
| **Object Storage** | Supabase Storage (S3-compatible) | Simpan PDF invoice, dokumen KYC, bukti pengiriman |
| **Blockchain** | Polygon (EVM) | Gas murah ($0.01), EVM-compatible, mature ecosystem |
| **Smart Contract** | Solidity 0.8.20 + OpenZeppelin + Foundry | ERC-721, ERC-4626, ReentrancyGuard, SafeERC20 |
| **OCR Engine** | Tesseract / docTR | Ekstraksi data dari PDF invoice |
| **AI/ML** | LightGBM / XGBoost + FastAPI | Credit scoring, fraud detection, risk assessment |
| **Task Queue** | Temporal / BullMQ | Durable workflow untuk lelang, jatuh tempo, reminder |
| **Monitoring** | Prometheus + Grafana + Sentry | Metrics, alerting, error tracking |

---

## 4. Microservices Breakdown

### 4.1 User Service

**Tanggung Jawab:** Autentikasi, registrasi, manajemen profil, KYC/KYB onboarding, role-based access control (RBAC).

**Fitur:**
- Registrasi dengan email/password atau OAuth (Google, LinkedIn).
- JWT-based authentication dengan refresh token.
- Role: `ADMIN`, `BORROWER` (UMKM), `INVESTOR`, `UNDERWRITER`.
- Profil bisnis: nama perusahaan, NPWP, alamat, industri, rekening bank.
- KYC: upload KTP/NPWP, verifikasi selfie, liveness detection.
- KYB: verifikasi dokumen perusahaan, beneficial ownership.
- Continuous KYC: monitoring perubahan data perusahaan dan risk database.

**API Endpoints:**
```
POST   /api/v1/auth/register
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
GET    /api/v1/users/me
PUT    /api/v1/users/me
POST   /api/v1/kyc/submit
GET    /api/v1/kyc/status
POST   /api/v1/kyb/submit
GET    /api/v1/kyb/status
GET    /api/v1/admin/users
PUT    /api/v1/admin/users/:id/verify
```

**Event yang dipublikasikan:**
- `user.registered`
- `kyc.submitted`
- `kyc.approved`
- `kyc.rejected`

---

### 4.2 Invoice Service

**Tanggung Jawab:** Upload invoice, ekstraksi data (OCR), validasi, registrasi on-chain, dan manajemen dokumen.

**Fitur:**
- Upload PDF invoice (drag & drop atau API).
- OCR extraction: nomor invoice, tanggal, jumlah, jatuh tempo, nama debtor, NPWP debtor.
- Validasi: cek duplikasi, validasi format, verifikasi NPWP debtor.
- Verifikasi debtor: validasi melalui database perusahaan (ACRA wrapper / API eksternal).
- Tokenisasi: mint ERC-721 NFT dengan metadata invoice.
- Simpan PDF di Supabase Storage, hash di blockchain.
- Status tracking: `DRAFT` → `UPLOADED` → `VERIFIED` → `TOKENIZED` → `LISTED` → `FUNDED` → `REPAID` → `DEFAULTED`.

**API Endpoints:**
```
POST   /api/v1/invoices/upload
GET    /api/v1/invoices
GET    /api/v1/invoices/:id
PUT    /api/v1/invoices/:id
POST   /api/v1/invoices/:id/verify
POST   /api/v1/invoices/:id/tokenize
GET    /api/v1/invoices/:id/documents
POST   /api/v1/invoices/:id/documents
DELETE /api/v1/invoices/:id/documents/:docId
```

**Event yang dipublikasikan:**
- `invoice.uploaded`
- `invoice.ocr.completed`
- `invoice.verified`
- `invoice.tokenized`
- `invoice.listed`

**Struktur data invoice:**
```json
{
  "id": "uuid",
  "invoice_number": "INV-2026-001",
  "borrower_id": "uuid",
  "debtor_name": "PT Maju Jaya",
  "debtor_npwp": "01.234.567.8-901.000",
  "face_value": 100000000,
  "currency": "IDR",
  "issue_date": "2026-09-01",
  "due_date": "2026-11-01",
  "status": "VERIFIED",
  "ocr_confidence": 0.95,
  "nft_token_id": 1234,
  "tx_hash": "0x...",
  "documents": [
    {"type": "INVOICE_PDF", "url": "https://..."},
    {"type": "PO", "url": "https://..."}
  ]
}
```

---

### 4.3 Credit Scoring Service

**Tanggung Jawab:** Penilaian risiko berbasis AI untuk setiap invoice dan debtor, menghasilkan risk grade (A–D) dan yield rate.

**Fitur:**
- Feature engineering dari data transaksi: payment history, invoice aging, debtor concentration, industry trend, seasonal patterns.
- Model ML: LightGBM / XGBoost untuk credit scoring.
- Fraud detection: anomaly detection untuk invoice duplikat, nilai tidak wajar, debtor fiktif.
- Real-time scoring: < 2 detik per invoice.
- Risk grade: A (low risk), B (medium-low), C (medium-high), D (high risk).
- Yield recommendation: berdasarkan risk grade dan market demand.
- Feedback loop: model retraining dengan data repayment aktual.

**API Endpoints:**
```
POST   /api/v1/credit-score/evaluate
GET    /api/v1/credit-score/:invoiceId
POST   /api/v1/credit-score/batch
GET    /api/v1/credit-score/model/version
POST   /api/v1/credit-score/feedback
```

**Input untuk scoring:**
```json
{
  "invoice_id": "uuid",
  "debtor_name": "PT Maju Jaya",
  "debtor_npwp": "01.234.567.8-901.000",
  "face_value": 100000000,
  "due_date": "2026-11-01",
  "borrower_history": {
    "total_invoices": 15,
    "on_time_payments": 12,
    "late_payments": 3,
    "avg_days_late": 5
  },
  "debtor_history": {
    "total_invoices": 45,
    "on_time_payments": 40,
    "late_payments": 5,
    "avg_days_late": 8
  },
  "industry": "MANUFACTURING",
  "macro_indicators": {
    "inflation_rate": 3.2,
    "interest_rate": 5.5
  }
}
```

**Output:**
```json
{
  "invoice_id": "uuid",
  "risk_grade": "B",
  "risk_score": 72,
  "default_probability": 0.04,
  "recommended_yield": 0.12,
  "recommended_advance_rate": 0.85,
  "factors": [
    {"name": "debtor_payment_history", "impact": "positive", "weight": 0.35},
    {"name": "invoice_aging", "impact": "neutral", "weight": 0.20},
    {"name": "industry_risk", "impact": "negative", "weight": 0.15}
  ],
  "model_version": "v2.3.1",
  "evaluated_at": "2026-09-10T10:00:00Z"
}
```

**Event yang dipublikasikan:**
- `credit.score.completed`
- `credit.score.flagged` (jika fraud terdeteksi)

---

### 4.4 Marketplace Service

**Tanggung Jawab:** Listing invoice, lelang, bidding, anti-snipe auction, dan penentuan pemenang.

**Fitur:**
- Listing invoice yang sudah diverifikasi dan di-tokenize.
- Lelang dengan durasi tetap (default: 24 jam).
- Bidding: investor memasukkan jumlah dan yield yang diminta.
- Anti-snipe: perpanjangan otomatis 5 menit jika ada bid di menit terakhir.
- Escrow locking: dana investor di-lock saat bid menang.
- Auto-close: lelang ditutup otomatis pada waktu yang ditentukan.
- Penentuan pemenang: yield terendah (biaya terendah untuk borrower).

**API Endpoints:**
```
GET    /api/v1/marketplace/listings
GET    /api/v1/marketplace/listings/:id
POST   /api/v1/marketplace/listings
PUT    /api/v1/marketplace/listings/:id/cancel
POST   /api/v1/marketplace/listings/:id/bid
GET    /api/v1/marketplace/listings/:id/bids
POST   /api/v1/marketplace/listings/:id/close
GET    /api/v1/marketplace/my-bids
```

**Event yang dipublikasikan:**
- `listing.created`
- `bid.placed`
- `auction.extended`
- `auction.closed`
- `winner.determined`

---

### 4.5 Loan Service

**Tanggung Jawab:** Pembuatan loan setelah lelang selesai, manajemen repayment schedule, tracking pembayaran, dan penanganan default.

**Fitur:**
- Loan creation otomatis saat auction closed.
- Repayment schedule: single payment pada due date (default) atau cicilan.
- Tracking pembayaran dari debtor.
- Auto-distribution: bagi hasil ke investor setelah pembayaran diterima.
- Overdue handling: reminder H-7, H-3, H-1, dan hari H.
- Default handling: eskalasi setelah 30 hari overdue, klaim asuransi (jika ada).
- Reserve management: holdback percentage sampai debtor bayar.

**API Endpoints:**
```
GET    /api/v1/loans
GET    /api/v1/loans/:id
POST   /api/v1/loans/:id/repay
GET    /api/v1/loans/:id/schedule
GET    /api/v1/loans/:id/repayments
POST   /api/v1/loans/:id/default
GET    /api/v1/loans/overdue
```

**Event yang dipublikasikan:**
- `loan.created`
- `loan.repayment.received`
- `loan.repayment.overdue`
- `loan.defaulted`
- `loan.settled`

---

### 4.6 Payment Service

**Tanggung Jawab:** Escrow, disbursement, settlement on-chain, dan integrasi payment gateway.

**Fitur:**
- Escrow smart contract: dana investor di-hold sampai loan created.
- Disbursement: transfer dana ke borrower setelah loan created (stablecoin USDC).
- Settlement: distribusi pembayaran dari debtor ke investor + platform fee.
- Integrasi payment gateway: Stripe / Xendit untuk fiat on/off ramp.
- Idempotency: setiap transaksi memiliki idempotency key untuk mencegah double-spend.
- Reconciliation: automated matching antara on-chain dan off-chain records.

**API Endpoints:**
```
POST   /api/v1/payments/escrow/lock
POST   /api/v1/payments/escrow/release
POST   /api/v1/payments/disburse
POST   /api/v1/payments/settle
GET    /api/v1/payments/:id/status
POST   /api/v1/payments/webhook/stripe
POST   /api/v1/payments/webhook/xendit
GET    /api/v1/payments/reconciliation
```

**Event yang dipublikasikan:**
- `payment.escrow.locked`
- `payment.disbursed`
- `payment.settled`
- `payment.failed`

---

### 4.7 Blockchain Service

**Tanggung Jawab:** Interaksi dengan smart contract, minting NFT, deployment vault, event indexing.

**Fitur:**
- Mint ERC-721 InvoiceNFT untuk setiap invoice terverifikasi.
- Deploy ERC-4626 vault untuk setiap invoice yang akan di-funding.
- Event indexing: listen ke event on-chain dan update database.
- Gas management: server-side signer untuk deployment dan transaksi.
- ABI management: generate ABI dari Foundry, sync ke API dan frontend.

**Smart Contracts:**

| Contract | Standard | Fungsi |
|----------|----------|--------|
| `InvoiceNFT.sol` | ERC-721 | Tokenisasi invoice, metadata: invoiceId, debtorHash, faceValue, dueDate, ipfsHash |
| `VaultFactory.sol` | — | Deploy vault per invoice, owner-only |
| `InvoiceVault.sol` | ERC-4626 | Funding pool, deposit USDC, redeem shares |
| `Escrow.sol` | — | Hold dana investor sampai loan created |
| `PaymentProcessor.sol` | — | Distribusi pembayaran ke investor + platform fee |
| `CreditScore.sol` | — | Store risk grade on-chain (hash only) |

**API Endpoints:**
```
POST   /api/v1/blockchain/mint-invoice
POST   /api/v1/blockchain/deploy-vault
GET    /api/v1/blockchain/tx/:hash
GET    /api/v1/blockchain/events
POST   /api/v1/blockchain/sync
GET    /api/v1/blockchain/gas-estimate
```

---

### 4.8 Notification Service

**Tanggung Jawab:** Kirim notifikasi ke pengguna via email, push, dan in-app.

**Fitur:**
- Email transaksional: registrasi, KYC approved, invoice listed, bid placed, auction won, repayment received, overdue reminder.
- Push notification untuk mobile (opsional).
- In-app notification center.
- Template management.
- Preference center: user bisa atur jenis notifikasi.

**API Endpoints:**
```
POST   /api/v1/notifications/send
GET    /api/v1/notifications
PUT    /api/v1/notifications/:id/read
GET    /api/v1/notifications/preferences
PUT    /api/v1/notifications/preferences
```

**Event yang dikonsumsi:**
- Semua event dari service lain (via Kafka consumer group).

---

### 4.9 Compliance Service

**Tanggung Jawab:** KYC/AML checks, sanctions screening, PEP screening, transaction monitoring, audit trail.

**Fitur:**
- KYC: verifikasi identitas (KTP, selfie, liveness).
- KYB: verifikasi perusahaan (akta, NPWP, beneficial ownership).
- AML screening: cek terhadap sanctions list (OFAC, UN, EU), PEP database.
- Transaction monitoring: deteksi pola mencurigakan (structuring, rapid movement).
- Audit trail: immutable log untuk setiap aksi compliance.
- Reporting: generate laporan untuk regulator (jika diperlukan).

**API Endpoints:**
```
POST   /api/v1/compliance/kyc/verify
POST   /api/v1/compliance/kyb/verify
POST   /api/v1/compliance/aml/screen
GET    /api/v1/compliance/audit-log
GET    /api/v1/compliance/reports
POST   /api/v1/compliance/flag
```

---

## 5. Database Schema (PostgreSQL)

### 5.1 Tabel Utama (31+ tabel)

```sql
-- ============================================
-- IDENTITY & ACCESS MANAGEMENT
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'BORROWER', 'INVESTOR', 'UNDERWRITER')),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED')),
    email_verified BOOLEAN DEFAULT FALSE,
    kyc_status VARCHAR(20) DEFAULT 'NOT_STARTED',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    granted_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, role)
);

-- ============================================
-- BUSINESS & DEBTOR PROFILES
-- ============================================
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    npwp VARCHAR(20) UNIQUE NOT NULL,
    industry VARCHAR(100),
    address TEXT,
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(10),
    bank_account_name VARCHAR(255),
    bank_account_number VARCHAR(50),
    bank_name VARCHAR(100),
    kyb_status VARCHAR(20) DEFAULT 'NOT_STARTED',
    risk_rating VARCHAR(5),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE debtors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(255) NOT NULL,
    npwp VARCHAR(20) UNIQUE,
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    address TEXT,
    industry VARCHAR(100),
    credit_score DECIMAL(5,2),
    risk_grade VARCHAR(5),
    total_invoices BIGINT DEFAULT 0,
    on_time_payments BIGINT DEFAULT 0,
    late_payments BIGINT DEFAULT 0,
    avg_days_late DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- FACTORING AGREEMENTS
-- ============================================
CREATE TABLE factoring_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID REFERENCES businesses(id),
    advance_rate DECIMAL(5,2) NOT NULL DEFAULT 85.00,
    factoring_fee_rate DECIMAL(5,2) NOT NULL DEFAULT 2.50,
    reserve_rate DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    recourse_type VARCHAR(20) CHECK (recourse_type IN ('RECOURSE', 'NON_RECOURSE')),
    max_credit_limit DECIMAL(18,2),
    valid_from DATE,
    valid_until DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- INVOICE & DOCUMENT MANAGEMENT
-- ============================================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(100) NOT NULL,
    borrower_id UUID REFERENCES businesses(id),
    debtor_id UUID REFERENCES debtors(id),
    factoring_agreement_id UUID REFERENCES factoring_agreements(id),
    face_value DECIMAL(18,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'IDR',
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'DRAFT',
    ocr_confidence DECIMAL(3,2),
    nft_token_id BIGINT,
    nft_tx_hash VARCHAR(66),
    credit_score DECIMAL(5,2),
    risk_grade VARCHAR(5),
    advance_rate DECIMAL(5,2),
    factoring_fee DECIMAL(18,2),
    reserve_amount DECIMAL(18,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    description TEXT,
    quantity DECIMAL(10,2),
    unit_price DECIMAL(18,2),
    total_amount DECIMAL(18,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE invoice_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    file_name VARCHAR(255),
    file_url TEXT NOT NULL,
    file_hash VARCHAR(66),
    ipfs_hash VARCHAR(66),
    uploaded_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- FUNDING & UNDERWRITING
-- ============================================
CREATE TABLE funding_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id),
    requested_amount DECIMAL(18,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    underwriting_decision_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE underwriting_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    funding_request_id UUID REFERENCES funding_requests(id),
    underwriter_id UUID REFERENCES users(id),
    decision VARCHAR(20) CHECK (decision IN ('APPROVED', 'REJECTED', 'CONDITIONAL')),
    approved_amount DECIMAL(18,2),
    interest_rate DECIMAL(5,2),
    conditions TEXT,
    notes TEXT,
    decided_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- MARKETPLACE & BIDDING
-- ============================================
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) UNIQUE,
    borrower_id UUID REFERENCES businesses(id),
    target_amount DECIMAL(18,2) NOT NULL,
    min_yield DECIMAL(5,2),
    auction_start TIMESTAMP NOT NULL,
    auction_end TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    winning_bid_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    investor_id UUID REFERENCES users(id),
    amount DECIMAL(18,2) NOT NULL,
    yield_rate DECIMAL(5,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    escrow_tx_hash VARCHAR(66),
    placed_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- LOANS & REPAYMENTS
-- ============================================
CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID REFERENCES listings(id),
    invoice_id UUID REFERENCES invoices(id),
    borrower_id UUID REFERENCES businesses(id),
    investor_id UUID REFERENCES users(id),
    principal_amount DECIMAL(18,2) NOT NULL,
    yield_rate DECIMAL(5,2) NOT NULL,
    total_repayment DECIMAL(18,2) NOT NULL,
    disbursed_at TIMESTAMP,
    due_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    vault_address VARCHAR(42),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE repayments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID REFERENCES loans(id),
    amount DECIMAL(18,2) NOT NULL,
    payment_method VARCHAR(50),
    tx_hash VARCHAR(66),
    status VARCHAR(20) DEFAULT 'PENDING',
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- ESCROW & SETTLEMENT
-- ============================================
CREATE TABLE escrow_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID REFERENCES loans(id),
    investor_id UUID REFERENCES users(id),
    amount DECIMAL(18,2) NOT NULL,
    escrow_address VARCHAR(42),
    tx_hash VARCHAR(66),
    status VARCHAR(20) DEFAULT 'LOCKED',
    locked_at TIMESTAMP DEFAULT NOW(),
    released_at TIMESTAMP
);

-- ============================================
-- RISK & AUDIT
-- ============================================
CREATE TABLE risk_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id),
    risk_grade VARCHAR(5),
    risk_score DECIMAL(5,2),
    default_probability DECIMAL(5,4),
    model_version VARCHAR(20),
    factors JSONB,
    assessed_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 5.2 Indexes

```sql
CREATE INDEX idx_invoices_borrower ON invoices(borrower_id);
CREATE INDEX idx_invoices_debtor ON invoices(debtor_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_auction_end ON listings(auction_end);
CREATE INDEX idx_bids_listing ON bids(listing_id);
CREATE INDEX idx_bids_investor ON bids(investor_id);
CREATE INDEX idx_loans_borrower ON loans(borrower_id);
CREATE INDEX idx_loans_investor ON loans(investor_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_loans_due_date ON loans(due_date);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
```

---

## 6. API Design

### 6.1 Autentikasi & Otorisasi
- **JWT Bearer Token** di header `Authorization: Bearer <token>`.
- Access token expiry: 1 jam.
- Refresh token expiry: 30 hari.
- Role-based access control (RBAC) di setiap endpoint.
- API key untuk integrasi server-to-server (opsional).

### 6.2 Rate Limiting
| Endpoint Category | Rate Limit |
|-------------------|------------|
| Auth (login/register) | 10 req/menit per IP |
| Read operations | 100 req/menit per user |
| Write operations | 30 req/menit per user |
| Credit scoring | 20 req/menit per user |
| Blockchain operations | 10 req/menit per user |

### 6.3 Error Handling
```json
{
  "error": {
    "code": "INVOICE_NOT_FOUND",
    "message": "Invoice with ID xxx not found",
    "details": {},
    "timestamp": "2026-09-10T10:00:00Z",
    "request_id": "req_xxx"
  }
}
```

**Error codes standar:**
| HTTP Status | Code | Deskripsi |
|-------------|------|-----------|
| 400 | `VALIDATION_ERROR` | Input tidak valid |
| 401 | `UNAUTHORIZED` | Token tidak valid/expired |
| 403 | `FORBIDDEN` | Tidak punya akses |
| 404 | `NOT_FOUND` | Resource tidak ditemukan |
| 409 | `CONFLICT` | Duplikasi data |
| 422 | `UNPROCESSABLE` | Business logic error |
| 429 | `RATE_LIMITED` | Terlalu banyak request |
| 500 | `INTERNAL_ERROR` | Server error |

### 6.4 Webhook Events
Platform mengirim webhook ke URL yang didaftarkan pengguna:

```json
{
  "event": "invoice.funded",
  "timestamp": "2026-09-10T10:00:00Z",
  "data": {
    "invoice_id": "uuid",
    "loan_id": "uuid",
    "amount": 85000000,
    "investor_id": "uuid"
  },
  "signature": "sha256=..."
}
```

**Event yang tersedia:**
- `invoice.uploaded`, `invoice.verified`, `invoice.funded`
- `bid.placed`, `auction.closed`
- `loan.created`, `loan.repayment.received`, `loan.overdue`, `loan.defaulted`
- `kyc.approved`, `kyc.rejected`

---

## 7. Smart Contract Specification

### 7.1 InvoiceNFT.sol (ERC-721)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InvoiceNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    
    struct InvoiceMetadata {
        string invoiceId;
        bytes32 debtorHash;      // Hash of debtor identity (privacy)
        uint256 faceValue;
        uint256 dueDate;
        string ipfsHash;
        uint8 riskGrade;         // 0=A, 1=B, 2=C, 3=D
        bool verified;
    }
    
    mapping(uint256 => InvoiceMetadata) public invoices;
    mapping(address => bool) public authorizedMinters;
    
    event InvoiceMinted(uint256 indexed tokenId, string invoiceId, uint256 faceValue);
    event InvoiceVerified(uint256 indexed tokenId);
    
    constructor() ERC721("InvoiceNFT", "INV") Ownable(msg.sender) {}
    
    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    function mintInvoice(
        address to,
        string memory invoiceId,
        bytes32 debtorHash,
        uint256 faceValue,
        uint256 dueDate,
        string memory ipfsHash,
        uint8 riskGrade
    ) external onlyAuthorized returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        invoices[tokenId] = InvoiceMetadata({
            invoiceId: invoiceId,
            debtorHash: debtorHash,
            faceValue: faceValue,
            dueDate: dueDate,
            ipfsHash: ipfsHash,
            riskGrade: riskGrade,
            verified: false
        });
        emit InvoiceMinted(tokenId, invoiceId, faceValue);
        return tokenId;
    }
    
    function verifyInvoice(uint256 tokenId) external onlyAuthorized {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        invoices[tokenId].verified = true;
        emit InvoiceVerified(tokenId);
    }
    
    function getInvoice(uint256 tokenId) external view returns (InvoiceMetadata memory) {
        return invoices[tokenId];
    }
}
```

### 7.2 InvoiceVault.sol (ERC-4626)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract InvoiceVault is ERC4626, ReentrancyGuard {
    address public immutable borrower;
    address public immutable platform;
    uint256 public immutable maxCapacity;
    uint256 public immutable maturity;
    uint256 public platformFeeRate; // in basis points
    
    enum VaultState { FUNDING, ACTIVE, REPAID, DEFAULTED }
    VaultState public state;
    
    event FundsReleased(address indexed borrower, uint256 amount);
    event RepaymentReceived(uint256 amount);
    event YieldDistributed(uint256 totalYield, uint256 platformFee);
    
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address borrower_,
        address platform_,
        uint256 maxCapacity_,
        uint256 maturity_,
        uint256 platformFeeRate_
    ) ERC4626(asset_) ERC20(name_, symbol_) {
        borrower = borrower_;
        platform = platform_;
        maxCapacity = maxCapacity_;
        maturity = maturity_;
        platformFeeRate = platformFeeRate_;
        state = VaultState.FUNDING;
    }
    
    function releaseFunds() external nonReentrant {
        require(state == VaultState.FUNDING, "Invalid state");
        require(totalAssets() > 0, "No funds");
        state = VaultState.ACTIVE;
        uint256 amount = totalAssets();
        IERC20(asset()).transfer(borrower, amount);
        emit FundsReleased(borrower, amount);
    }
    
    function receiveRepayment() external nonReentrant {
        require(state == VaultState.ACTIVE, "Invalid state");
        uint256 repaymentAmount = IERC20(asset()).balanceOf(address(this)) - totalAssets();
        if (repaymentAmount > 0) {
            emit RepaymentReceived(repaymentAmount);
        }
    }
    
    function settle() external nonReentrant {
        require(state == VaultState.ACTIVE, "Invalid state");
        require(block.timestamp >= maturity, "Not matured");
        state = VaultState.REPAID;
        uint256 total = totalAssets();
        uint256 platformFee = (total * platformFeeRate) / 10000;
        uint256 investorYield = total - platformFee;
        IERC20(asset()).transfer(platform, platformFee);
        emit YieldDistributed(investorYield, platformFee);
    }
}
```

### 7.3 Escrow.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is ReentrancyGuard, Ownable {
    enum EscrowState { LOCKED, RELEASED, REFUNDED }
    
    struct EscrowRecord {
        address investor;
        address borrower;
        uint256 amount;
        EscrowState state;
        uint256 lockedAt;
    }
    
    mapping(bytes32 => EscrowRecord) public escrows;
    IERC20 public immutable usdc;
    
    event EscrowLocked(bytes32 indexed escrowId, address investor, uint256 amount);
    event EscrowReleased(bytes32 indexed escrowId, address borrower, uint256 amount);
    event EscrowRefunded(bytes32 indexed escrowId, address investor, uint256 amount);
    
    constructor(IERC20 _usdc) Ownable(msg.sender) {
        usdc = _usdc;
    }
    
    function lockEscrow(
        bytes32 escrowId,
        address investor,
        address borrower,
        uint256 amount
    ) external onlyOwner {
        require(escrows[escrowId].state == EscrowState.LOCKED, "Invalid state");
        require(usdc.transferFrom(investor, address(this), amount), "Transfer failed");
        escrows[escrowId] = EscrowRecord({
            investor: investor,
            borrower: borrower,
            amount: amount,
            state: EscrowState.LOCKED,
            lockedAt: block.timestamp
        });
        emit EscrowLocked(escrowId, investor, amount);
    }
    
    function releaseEscrow(bytes32 escrowId) external onlyOwner nonReentrant {
        EscrowRecord storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.LOCKED, "Invalid state");
        escrow.state = EscrowState.RELEASED;
        usdc.transfer(escrow.borrower, escrow.amount);
        emit EscrowReleased(escrowId, escrow.borrower, escrow.amount);
    }
    
    function refundEscrow(bytes32 escrowId) external onlyOwner nonReentrant {
        EscrowRecord storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.LOCKED, "Invalid state");
        escrow.state = EscrowState.REFUNDED;
        usdc.transfer(escrow.investor, escrow.amount);
        emit EscrowRefunded(escrowId, escrow.investor, escrow.amount);
    }
}
```

---

## 8. AI Credit Scoring Engine

### 8.1 Feature Engineering Pipeline

```python
# features/invoice_features.py
import pandas as pd
import numpy as np
from datetime import datetime

class InvoiceFeatureEngineer:
    def __init__(self):
        self.feature_names = []
    
    def extract_features(self, invoice_data: dict, debtor_history: dict, borrower_history: dict) -> pd.DataFrame:
        features = {}
        
        # --- Invoice Features ---
        features['face_value'] = invoice_data['face_value']
        features['tenor_days'] = (invoice_data['due_date'] - invoice_data['issue_date']).days
        
        # --- Debtor Features ---
        features['debtor_total_invoices'] = debtor_history.get('total_invoices', 0)
        features['debtor_on_time_ratio'] = (
            debtor_history.get('on_time_payments', 0) / 
            max(debtor_history.get('total_invoices', 1), 1)
        )
        features['debtor_avg_days_late'] = debtor_history.get('avg_days_late', 0)
        features['debtor_credit_score'] = debtor_history.get('credit_score', 500)
        
        # --- Borrower Features ---
        features['borrower_total_invoices'] = borrower_history.get('total_invoices', 0)
        features['borrower_on_time_ratio'] = (
            borrower_history.get('on_time_payments', 0) / 
            max(borrower_history.get('total_invoices', 1), 1)
        )
        features['borrower_default_count'] = borrower_history.get('default_count', 0)
        
        # --- Industry & Macro Features ---
        features['industry_risk_score'] = self._get_industry_risk(invoice_data.get('industry'))
        features['inflation_rate'] = invoice_data.get('macro_indicators', {}).get('inflation_rate', 3.0)
        features['interest_rate'] = invoice_data.get('macro_indicators', {}).get('interest_rate', 5.5)
        
        # --- Derived Features ---
        features['invoice_to_debtor_ratio'] = (
            invoice_data['face_value'] / 
            max(debtor_history.get('total_face_value', invoice_data['face_value']), 1)
        )
        features['debtor_concentration'] = self._calculate_concentration(borrower_history)
        
        df = pd.DataFrame([features])
        return df
    
    def _get_industry_risk(self, industry: str) -> float:
        risk_map = {
            'MANUFACTURING': 0.3,
            'RETAIL': 0.4,
            'CONSTRUCTION': 0.6,
            'TECHNOLOGY': 0.2,
            'HEALTHCARE': 0.25,
            'FOOD_BEVERAGE': 0.35,
            'LOGISTICS': 0.45,
            'ENERGY': 0.3,
        }
        return risk_map.get(industry, 0.5)
    
    def _calculate_concentration(self, borrower_history: dict) -> float:
        # Herfindahl-Hirschman Index style concentration
        debtors = borrower_history.get('debtor_distribution', [])
        if not debtors:
            return 1.0
        total = sum(d['face_value'] for d in debtors)
        if total == 0:
            return 1.0
        hhi = sum((d['face_value'] / total) ** 2 for d in debtors)
        return hhi
```

### 8.2 Model Training Pipeline

```python
# models/train_credit_model.py
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import joblib

class CreditScoringModel:
    def __init__(self):
        self.model = None
        self.feature_engineer = InvoiceFeatureEngineer()
    
    def train(self, X: pd.DataFrame, y: pd.Series):
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        self.model = lgb.LGBMRegressor(
            n_estimators=500,
            learning_rate=0.05,
            max_depth=7,
            num_leaves=31,
            min_child_samples=20,
            subsample=0.8,
            colsample_bytree=0.8,
            reg_alpha=0.1,
            reg_lambda=0.1,
            random_state=42
        )
        
        self.model.fit(
            X_train, y_train,
            eval_set=[(X_test, y_test)],
            eval_metric='rmse',
            callbacks=[lgb.early_stopping(50), lgb.log_evaluation(100)]
        )
        
        y_pred = self.model.predict(X_test)
        print(f"R²: {r2_score(y_test, y_pred):.4f}")
        print(f"MAE: {mean_absolute_error(y_test, y_pred):.4f}")
        print(f"RMSE: {mean_squared_error(y_test, y_pred, squared=False):.4f}")
        
        return self.model
    
    def predict_risk_grade(self, features: pd.DataFrame) -> dict:
        risk_score = self.model.predict(features)[0]
        risk_score = max(0, min(100, risk_score))
        
        if risk_score >= 80:
            grade = 'A'
            default_prob = 0.01
        elif risk_score >= 60:
            grade = 'B'
            default_prob = 0.04
        elif risk_score >= 40:
            grade = 'C'
            default_prob = 0.10
        else:
            grade = 'D'
            default_prob = 0.25
        
        return {
            'risk_score': round(risk_score, 2),
            'risk_grade': grade,
            'default_probability': default_prob,
            'recommended_yield': self._calculate_yield(grade, default_prob),
            'recommended_advance_rate': self._calculate_advance_rate(grade)
        }
    
    def _calculate_yield(self, grade: str, default_prob: float) -> float:
        base_yield = {'A': 0.08, 'B': 0.12, 'C': 0.18, 'D': 0.25}
        return base_yield.get(grade, 0.15) + default_prob * 0.5
    
    def _calculate_advance_rate(self, grade: str) -> float:
        return {'A': 0.95, 'B': 0.85, 'C': 0.75, 'D': 0.60}.get(grade, 0.80)
    
    def save(self, path: str):
        joblib.dump(self.model, path)
    
    def load(self, path: str):
        self.model = joblib.load(path)
```

### 8.3 FastAPI Microservice

```python
# api/credit_scoring.py
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import uuid

app = FastAPI(title="Credit Scoring Service")

class ScoringRequest(BaseModel):
    invoice_id: str
    debtor_name: str
    debtor_npwp: Optional[str]
    face_value: float
    due_date: str
    borrower_history: dict
    debtor_history: dict
    industry: str
    macro_indicators: Optional[dict] = {}

class ScoringResponse(BaseModel):
    invoice_id: str
    risk_grade: str
    risk_score: float
    default_probability: float
    recommended_yield: float
    recommended_advance_rate: float
    factors: List[dict]
    model_version: str

model = CreditScoringModel()
model.load("/models/credit_model_v2.3.1.pkl")

@app.post("/api/v1/credit-score/evaluate", response_model=ScoringResponse)
async def evaluate_credit(request: ScoringRequest):
    try:
        features = model.feature_engineer.extract_features(
            invoice_data={
                'face_value': request.face_value,
                'due_date': datetime.fromisoformat(request.due_date),
                'issue_date': datetime.now(),
                'industry': request.industry,
                'macro_indicators': request.macro_indicators
            },
            debtor_history=request.debtor_history,
            borrower_history=request.borrower_history
        )
        
        result = model.predict_risk_grade(features)
        
        return ScoringResponse(
            invoice_id=request.invoice_id,
            risk_grade=result['risk_grade'],
            risk_score=result['risk_score'],
            default_probability=result['default_probability'],
            recommended_yield=result['recommended_yield'],
            recommended_advance_rate=result['recommended_advance_rate'],
            factors=[],
            model_version="v2.3.1"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/credit-score/health")
async def health():
    return {"status": "healthy", "model_loaded": model.model is not None}
```

---

## 9. Event-Driven Workflow (Kafka Topics)

### 9.1 Topic Design

| Topic | Partitions | Retention | Producer | Consumer |
|-------|------------|-----------|----------|----------|
| `invoice.events` | 6 | 7 days | Invoice Service | Credit Score, Marketplace, Notification |
| `bid.events` | 6 | 7 days | Marketplace Service | Loan Service, Notification |
| `loan.events` | 6 | 30 days | Loan Service | Payment, Notification, Compliance |
| `payment.events` | 6 | 30 days | Payment Service | Loan, Notification, Blockchain |
| `kyc.events` | 3 | 90 days | Compliance Service | User, Notification, Audit |
| `audit.events` | 3 | 365 days | All Services | Compliance, Audit Log |

### 9.2 Workflow: Invoice Funding

```
1. Borrower uploads invoice
   → invoice.uploaded (Kafka)
   → Credit Score Service consume → evaluate → credit.score.completed
   → Invoice Service update status → invoice.verified

2. Invoice verified → tokenized on-chain
   → invoice.tokenized
   → Marketplace Service create listing → listing.created

3. Investor places bid
   → bid.placed
   → Payment Service lock escrow → payment.escrow.locked

4. Auction closes
   → auction.closed
   → Loan Service determine winner → loan.created
   → Payment Service disburse to borrower → payment.disbursed
   → Blockchain Service deploy vault

5. Debtor repays
   → payment.received
   → Loan Service process repayment → loan.repayment.received
   → Payment Service distribute yield → payment.settled
   → Blockchain Service settle vault on-chain
```

### 9.3 Consumer Groups

```
credit-score-group:
  - credit-scoring-service-1
  - credit-scoring-service-2

notification-group:
  - notification-service-1

payment-group:
  - payment-service-1
  - payment-service-2

audit-group:
  - compliance-service-1
```

---

## 10. Security & Compliance

### 10.1 Keamanan Backend

| Area | Implementasi |
|------|-------------|
| **Autentikasi** | JWT + refresh token, OAuth2 untuk integrasi pihak ketiga |
| **Otorisasi** | RBAC di setiap endpoint, scope-based access |
| **Enkripsi data** | AES-256 untuk data sensitif at-rest, TLS 1.3 in-transit |
| **Enkripsi PII** | Debtor identity di-encrypt client-side sebelum on-chain |
| **API Security** | Rate limiting, input validation, SQL injection prevention (parameterized queries) |
| **Smart Contract** | Audited, ReentrancyGuard, SafeERC20, OpenZeppelin library |
| **Key Management** | AWS KMS / HashiCorp Vault untuk private key signer |
| **Audit Trail** | Immutable log untuk setiap aksi, hash di blockchain |

### 10.2 KYC/AML Compliance

- **KYC**: verifikasi KTP, selfie, liveness detection, NPWP.
- **KYB**: akta perusahaan, NPWP, beneficial ownership, akta perubahan.
- **AML Screening**: sanctions list (OFAC, UN, EU), PEP database, adverse media.
- **Continuous KYC**: monitoring perubahan data perusahaan dan risk database.
- **Transaction Monitoring**: deteksi structuring, rapid movement, unusual patterns.
- **Counterparty Verification**: verifikasi debtor sebelum invoice di-funding.

### 10.3 Regulatory Framework

- **RBI Guidelines** (jika beroperasi di India): NBFC-Factors registration, exposure limits, prudential norms.
- **OJK Regulations** (jika beroperasi di Indonesia): POJK tentang Layanan Pinjam Meminjam Berbasis Teknologi.
- **Companies Act**: pencatatan transaksi invoice financing dalam laporan keuangan.
- **Tax & GST**: pemisahan antara loan/funding dan revenue, dokumentasi untuk audit pajak.

---

## 11. Deployment & Infrastructure

### 11.1 Environment

| Environment | Platform | Database | Blockchain |
|-------------|----------|----------|------------|
| **Local Dev** | Docker Compose | PostgreSQL (Docker) | Polygon Mumbai |
| **Staging** | Railway / Render | Supabase | Polygon Mumbai |
| **Production** | AWS ECS / GCP Cloud Run | RDS PostgreSQL | Polygon Mainnet |

### 11.2 Docker Compose (Local Dev)

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: invoiceflow
      POSTGRES_USER: invoiceflow
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  kafka:
    image: confluentinc/cp-kafka:latest
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper

  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    ports:
      - "2181:2181"

volumes:
  postgres_data:
```

### 11.3 Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/invoiceflow
REDIS_URL=redis://localhost:6379

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Blockchain
POLYGON_RPC_URL=https://polygon-rpc.com
PRIVATE_KEY=0x...
INVOICE_NFT_ADDRESS=0x...
VAULT_FACTORY_ADDRESS=0x...
ESCROW_ADDRESS=0x...
USDC_ADDRESS=0x...

# AI/ML
MODEL_PATH=/models/credit_model_v2.3.1.pkl
OPENAI_API_KEY=sk-...  # fallback untuk AI features

# External Services
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJ...
STRIPE_SECRET_KEY=sk_live_...
XENDIT_SECRET_KEY=xnd_...

# Monitoring
SENTRY_DSN=https://...
PROMETHEUS_PORT=9090

# Security
JWT_SECRET=your-256-bit-secret
JWT_EXPIRY=1h
REFRESH_TOKEN_EXPIRY=30d
ENCRYPTION_KEY=32-byte-key
```

---

## 12. Testing Strategy

| Layer | Tool | Coverage Target |
|-------|------|-----------------|
| Unit Test | Jest / pytest | > 80% |
| Integration Test | Supertest / TestContainers | Critical paths |
| Smart Contract Test | Foundry / Hardhat | 100% contract coverage |
| Load Test | k6 / Locust | 10.000 concurrent users |
| Security Test | OWASP ZAP / Slither | No critical/high findings |
| E2E Test | Playwright | Full user journeys |

### 12.1 Smart Contract Test (Foundry)

```solidity
// test/InvoiceNFT.t.sol
import "forge-std/Test.sol";
import "../src/InvoiceNFT.sol";

contract InvoiceNFTTest is Test {
    InvoiceNFT public nft;
    address public admin = address(1);
    address public borrower = address(2);
    
    function setUp() public {
        vm.prank(admin);
        nft = new InvoiceNFT();
    }
    
    function testMintInvoice() public {
        vm.prank(admin);
        uint256 tokenId = nft.mintInvoice(
            borrower,
            "INV-001",
            keccak256("PT Maju Jaya"),
            100000000,
            block.timestamp + 60 days,
            "ipfs://Qm...",
            1 // B
        );
        
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(0), borrower);
        
        InvoiceNFT.InvoiceMetadata memory meta = nft.getInvoice(0);
        assertEq(meta.invoiceId, "INV-001");
        assertEq(meta.faceValue, 100000000);
        assertEq(meta.riskGrade, 1);
    }
    
    function testVerifyInvoice() public {
        vm.prank(admin);
        nft.mintInvoice(borrower, "INV-001", bytes32(0), 100000000, 0, "", 0);
        
        vm.prank(admin);
        nft.verifyInvoice(0);
        
        InvoiceNFT.InvoiceMetadata memory meta = nft.getInvoice(0);
        assertTrue(meta.verified);
    }
    
    function testUnauthorizedMintReverts() public {
        vm.prank(borrower);
        vm.expectRevert("Not authorized");
        nft.mintInvoice(borrower, "INV-001", bytes32(0), 100000000, 0, "", 0);
    }
}
```

### 12.2 Integration Test (pytest)

```python
# tests/test_invoice_workflow.py
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_full_invoice_workflow(client: AsyncClient, auth_token: str):
    headers = {"Authorization": f"Bearer {auth_token}"}
    
    # 1. Upload invoice
    response = await client.post(
        "/api/v1/invoices/upload",
        headers=headers,
        files={"file": ("invoice.pdf", open("test_invoice.pdf", "rb"), "application/pdf")},
        data={"debtor_name": "PT Maju Jaya", "face_value": 100000000}
    )
    assert response.status_code == 201
    invoice_id = response.json()["id"]
    
    # 2. Verify invoice
    response = await client.post(
        f"/api/v1/invoices/{invoice_id}/verify",
        headers=headers
    )
    assert response.status_code == 200
    assert response.json()["status"] == "VERIFIED"
    
    # 3. Check credit score
    response = await client.get(
        f"/api/v1/credit-score/{invoice_id}",
        headers=headers
    )
    assert response.status_code == 200
    assert response.json()["risk_grade"] in ["A", "B", "C", "D"]
    
    # 4. Tokenize
    response = await client.post(
        f"/api/v1/invoices/{invoice_id}/tokenize",
        headers=headers
    )
    assert response.status_code == 200
    assert response.json()["nft_token_id"] is not None
```

---

## 13. Monitoring & Observability

### 13.1 Metrics (Prometheus)

| Metric | Type | Deskripsi |
|--------|------|-----------|
| `http_requests_total` | Counter | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | Latency per endpoint |
| `invoices_uploaded_total` | Counter | Total invoice uploaded |
| `invoices_funded_total` | Counter | Total invoice funded |
| `credit_scoring_duration_seconds` | Histogram | Credit scoring latency |
| `blockchain_tx_total` | Counter | Total on-chain transactions |
| `blockchain_tx_failed_total` | Counter | Failed on-chain transactions |
| `kafka_consumer_lag` | Gauge | Kafka consumer lag |
| `active_loans_total` | Gauge | Jumlah loan aktif |
| `default_rate` | Gauge | Default rate |

### 13.2 Alerting

| Alert | Condition | Severity |
|-------|-----------|----------|
| High Error Rate | HTTP 5xx > 5% selama 5 menit | Critical |
| High Latency | P95 latency > 2s selama 10 menit | Warning |
| Kafka Consumer Lag | Lag > 10.000 messages | Warning |
| Blockchain Tx Failed | > 3 failed tx dalam 1 jam | Critical |
| Default Rate Spike | > 5% dalam 24 jam | Critical |
| Database Connection Pool | > 90% usage | Warning |

### 13.3 Logging

- Structured logging (JSON format).
- Log level: DEBUG (dev), INFO (staging), WARN (production).
- Correlation ID di setiap request.
- Sensitive data di-mask (PII, password, private key).
- Centralized log: ELK Stack / Grafana Loki.

---

## 14. Roadmap Pengembangan

### Fase 1 — Core Backend (Minggu 1–8)
- [ ] User Service: auth, KYC/KYB, RBAC
- [ ] Invoice Service: upload, OCR, validasi, tokenisasi
- [ ] Credit Scoring Service: feature engineering, model v1
- [ ] Database schema & migration
- [ ] API Gateway setup
- [ ] Smart contract: InvoiceNFT, Escrow

### Fase 2 — Marketplace & Loan (Minggu 9–16)
- [ ] Marketplace Service: listing, bidding, auction
- [ ] Loan Service: creation, repayment, default
- [ ] Payment Service: escrow, disbursement, settlement
- [ ] Smart contract: InvoiceVault (ERC-4626)
- [ ] Kafka event bus setup
- [ ] Blockchain Service: event indexing

### Fase 3 — AI & Compliance (Minggu 17–24)
- [ ] Credit Scoring Service: model v2, fraud detection
- [ ] Compliance Service: AML screening, transaction monitoring
- [ ] Notification Service: email, push, in-app
- [ ] Model retraining pipeline
- [ ] Audit trail & reporting

### Fase 4 — Scale & Optimization (Bulan 7–12)
- [ ] Multi-chain support (Base, Arbitrum)
- [ ] Advanced AI: predictive default modeling
- [ ] API publik untuk partner
- [ ] White-label solution
- [ ] Cross-border financing
- [ ] Mobile SDK

---

## 15. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Smart contract vulnerability | Kehilangan dana investor | Audit oleh pihak ketiga, bug bounty, ReentrancyGuard, SafeERC20 |
| Data debtor bocor | Pelanggaran privasi, reputasi | Enkripsi PII client-side, TEE untuk AI scoring |
| Model AI bias | Diskriminasi, regulasi | Fairness testing, explainability, human review untuk kasus marginal |
| Regulatory perubahan | Non-compliance | Legal counsel, modular compliance layer, multi-jurisdiction support |
| Default tinggi | Kerugian investor | Diversifikasi, credit scoring ketat, reserve fund, asuransi |
| Scalability bottleneck | Downtime, kehilangan revenue | Horizontal scaling, Kafka partitioning, database read replicas |
| Oracle manipulation | Data on-chain salah | Multiple oracle sources, Chainlink, fallback mechanism |
| Gas price spike | Biaya operasional tinggi | Layer 2 (Polygon), batch transactions, gas optimization |

---

## 16. Kriteria Penerimaan (Acceptance Criteria)

1. Borrower dapat upload invoice dan mendapatkan hasil OCR dalam < 30 detik.
2. Credit scoring selesai dalam < 2 detik per invoice.
3. Invoice ter-tokenize on-chain dengan biaya gas < $0.01.
4. Investor dapat bid dan escrow terkunci dalam < 5 detik.
5. Auction close otomatis pada waktu yang ditentukan, dengan anti-snipe extension.
6. Loan created dan dana didisburse ke borrower dalam < 60 detik setelah auction close.
7. Repayment diproses dan yield didistribusikan ke investor dalam < 30 detik.
8. KYC/KYB selesai dalam < 5 menit (automated) atau < 24 jam (manual review).
9. Semua event tercatat di audit log dan dapat di-query.
10. API uptime 99,9% selama 30 hari berturut-turut.
11. Load test: 10.000 concurrent users tanpa error.
12. Smart contract audit: tidak ada critical/high findings.

---

## 17. Penutup

PRD Backend ini menjadi acuan utama untuk pengembangan **InvoiceFlow AI**. Setiap microservice, smart contract, dan AI engine harus mengikuti spesifikasi yang telah dijabarkan. Perubahan signifikan harus melalui revisi dokumen dan persetujuan product owner.

**Target MVP Backend:** 8 minggu setelah persetujuan PRD.
**Target Production Ready:** 6 bulan.

