# Aturan Proyek InvoiceFlow AI — Backend

## Stack Wajib (dari PRD Section 3.2)
- **Backend utama**: Python 3.11 + FastAPI (untuk AI/ML & OCR), Node.js 20 + TypeScript (untuk orchestration & I/O-heavy)
- **Database**: PostgreSQL 15 + Redis
- **Event Bus**: Apache Kafka
- **Object Storage**: Supabase Storage (S3-compatible)
- **Smart Contract**: Solidity 0.8.20 + OpenZeppelin + Foundry
- **AI/ML**: LightGBM / XGBoost + FastAPI
- **Testing**: pytest (backend), Foundry (contract), Jest (Node), TestContainers (integration)
- **Monitoring**: Prometheus + Grafana + Sentry

## Struktur Folder
invoice-ai/
├── services/
│ ├── user-service/ # Auth, KYC, Profile
│ ├── invoice-service/ # Upload, OCR, Validation, Tokenization
│ ├── credit-score-service/ # AI/ML credit scoring
│ ├── marketplace-service/ # Listing, Bid, Auction
│ ├── loan-service/ # Loan, Repayment, Default
│ ├── payment-service/ # Escrow, Disbursement, Settlement
│ ├── blockchain-service/ # Smart contract interaction
│ ├── notification-service/ # Email, Push, In-app
│ └── compliance-service/ # KYC/AML, Audit
├── contracts/ # Solidity smart contracts
│ ├── src/
│ ├── test/
│ └── script/
├── infra/ # Docker, K8s, Terraform
├── docs/ # PRD, ADR, API docs
└── tasks/ # Task files untuk Plandex


## Aturan Anti-Fall Logic (WAJIB di setiap service)
1. Setiap external API call: timeout 5s + retry 3x exponential backoff
2. Setiap database operation: fallback ke read replica/cache jika primary gagal
3. Setiap Kafka producer: fallback ke synchronous call jika broker unavailable
4. Setiap error: log dengan correlation ID, TIDAK ADA silent failure
5. Setiap endpoint: health check + circuit breaker
6. **Fail fast, fail clearly** — jangan sembunyikan error dengan fallback object
7. Setiap background job: idempotency key untuk mencegah double-processing
8. Setiap service: graceful shutdown dengan drain period

## Aturan Fall Safety Security (WAJIB di setiap service)
1. Validasi input dengan Pydantic (Python) / Zod (TypeScript) sebelum diproses
2. SQL injection prevention: parameterized queries only, TIDAK ADA string concatenation
3. Rate limiting sesuai PRD Section 6.2
4. JWT secret rotation, refresh token disimpan hashed (bcrypt/argon2)
5. Smart contract: signer terpisah (KMS/Vault), BUKAN private key di kode
6. Error message TIDAK BOLEH mengungkap stack trace/internal path ke client
7. Semua aksi admin tercatat di `audit_logs` dengan old_values & new_values
8. ReentrancyGuard + SafeERC20 di semua smart contract dengan external call
9. PII di-encrypt at-rest (AES-256), di-mask di logs
10. Continuous KYC: monitoring perubahan data perusahaan
11. Webhook signature verification (HMAC-SHA256) untuk Stripe/Xendit
12. Setiap endpoint auth: rate limit 10 req/menit per IP

## Konvensi Kode
- Setiap service punya folder sendiri di `services/<nama>/`
- Setiap service punya `Dockerfile`, `README.md`, `pyproject.toml` atau `package.json`
- Setiap endpoint punya unit test minimal 1 test case + 1 edge case
- Setiap smart contract punya Foundry test dengan coverage 100%
- Setiap service punya `health` endpoint
- Commit message format: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`
- Gunakan structured logging (JSON) dengan correlation ID

## Testing Wajib
- Unit test: setiap fungsi publik
- Integration test: setiap API endpoint (happy path + error path)
- Contract test: setiap smart contract function (100% coverage)
- Anti-fall test: timeout, retry, fallback, circuit breaker
- Security test: SQL injection, rate limit, unauthorized access

## Bahasa
- Kode: Inggris
- Komentar: Inggris (untuk konsistensi)
- Dokumentasi (README, PRD): Indonesia boleh