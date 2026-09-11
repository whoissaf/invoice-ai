# Backend Development Conventions & Security Rules

## 1. Arsitektur
- Pisahkan tanggung jawab: `models.py` (DB), `schemas.py` (Validasi), `routers.py` (HTTP), `security.py` (Auth).
- JANGAN menggabungkan logika bisnis kompleks di dalam `routers.py`.

## 2. Keamanan (WAJIB)
- JANGAN PERNAH menyimpan plain-text password. Gunakan `passlib` dengan `bcrypt`.
- JANGAN PERNAH menggunakan string concatenation untuk SQL query (cegah SQL Injection). Gunakan SQLAlchemy ORM.
- Semua endpoint yang membutuhkan auth WAJIB memiliki dependency `Depends(get_current_user)`.
- Jangan hardcode `SECRET_KEY`. Gunakan `os.getenv("SECRET_KEY", "fallback_dev_key")`.

## 3. Aturan untuk Agentic AI (PENTING)
- Saat diminta membuat file, buat HANYA file tersebut. Jangan memodifikasi file lain kecuali secara eksplisit diminta.
- Jika terjadi error di GitHub Actions, baca log error, identifikasi file yang bermasalah, dan perbaiki HANYA file tersebut.
- Pastikan semua import statement valid dan tidak ada unused imports.
