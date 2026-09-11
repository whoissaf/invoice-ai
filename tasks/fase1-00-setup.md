# Task 1.0 — Setup Proyek & Infrastruktur

Berdasarkan PRD Section 3.2 (Stack), Section 5 (Database Schema), dan Section 11 (Deployment).

## Deliverables

1. **Struktur monorepo**:
   - `services/user-service/` (Python FastAPI)
   - `services/invoice-service/` (Node.js TypeScript)
   - `services/credit-score-service/` (Python FastAPI + LightGBM)
   - `services/marketplace-service/` (Node.js TypeScript)
   - `services/loan-service/` (Node.js TypeScript)
   - `services/payment-service/` (Node.js TypeScript)
   - `services/blockchain-service/` (Node.js TypeScript + ethers.js)
   - `services/notification-service/` (Node.js TypeScript)
   - `services/compliance-service/` (Python FastAPI)

2. **File `docker-compose.yml`** di root (PRD Section 11.2):
   - PostgreSQL 15
   - Redis 7
   - Kafka + Zookeeper
   - Volume untuk persistensi

3. **File `.env.example`** di root (PRD Section 11.3):
   - Semua environment variable yang dibutuhkan
   - TANPA nilai asli (placeholder saja)

4. **Migrasi SQL awal** di `infra/migrations/`:
   - SEMUA tabel di PRD Section 5.1
   - SEMUA index di PRD Section 5.2
   - Gunakan Alembic (Python) atau Knex (Node)

5. **File `shared/`** untuk kode yang dipakai bersama:
   - `shared/logger.py` (structured logging JSON)
   - `shared/errors.py` (custom exception classes)
   - `shared/kafka_client.py` (producer/consumer dengan fallback)
   - `shared/db_client.py` (connection pool + read replica fallback)
   - `shared/retry.py` (retry decorator dengan exponential backoff)

6. **CI/CD awal** `.github/workflows/test.yml`:
   - Lint (ruff untuk Python, eslint untuk Node)
   - Unit test (pytest + jest)
   - Contract test (foundry)
   - Coverage report

## Aturan
- Ikuti `AGENTS.md` untuk anti-fall logic & fall safety security
- Setiap service punya `Dockerfile` dan `README.md` minimal
- TIDAK ADA logic bisnis di task ini — hanya struktur dan infrastruktur
- Setiap file Python/TypeScript minimal punya docstring/comment

## Output yang Diharapkan
- Semua folder dan file terbuat
- `docker-compose up` berhasil menjalankan PostgreSQL, Redis, Kafka
- Migrasi SQL berhasil dijalankan
- CI/CD workflow berjalan (walaupun test masih kosong)
- `pytest` dan `npm test` berjalan tanpa error (walaupun 0 test)