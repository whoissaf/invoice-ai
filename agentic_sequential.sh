#!/bin/bash

# Gunakan ABSOLUTE PATH agar tidak error saat pindah direktori (cd ..)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$ROOT_DIR/PRD.md"
CONVENTIONS_FILE="$ROOT_DIR/CONVENTIONS.md"
BACKEND_DIR="$ROOT_DIR/backend"
MAX_FIX_RETRIES=5
CURRENT_PROVIDER="openrouter"

mkdir -p "$BACKEND_DIR"
cd "$BACKEND_DIR" || exit 1

# Flag hemat RAM & matikan warning model
AIDER_BASE_FLAGS="--yes --no-pretty --no-show-model-warnings --map-tokens 1024 --max-chat-history-tokens 1024"

FILES=("requirements.txt" "database.py" "models.py" "schemas.py" "security.py" "routers.py" "main.py")

run_aider_with_fallback() {
    local prompt="$1"
    local extra_flags="$2"
    while true; do
        echo "🤖 [INFO] Provider: $CURRENT_PROVIDER"
        if [ "$CURRENT_PROVIDER" == "gemini" ]; then
            export GEMINI_API_KEY="$GEMINI_KEY"
            unset OPENROUTER_API_KEY
            MODEL="gemini/gemini-1.5-flash"
        else
            export OPENROUTER_API_KEY="$OPENROUTER_KEY"
            unset GEMINI_API_KEY
            # Model ID yang BENAR di OpenRouter
            MODEL="google/gemini-1.5-flash"
        fi

        echo "⏳ Memproses... (mohon tunggu, sedang membaca PRD & menulis kode)"
        OUTPUT=$(aider $AIDER_BASE_FLAGS $extra_flags --model "$MODEL" --message "$prompt" 2>&1)
        EXIT_CODE=$?
        echo "$OUTPUT"
        
        # Deteksi Rate Limit ATAU Model Not Found
        if echo "$OUTPUT" | grep -iqE "rate limit|429|quota exceeded|not found"; then
            echo "⚠️ Error atau Rate limit terdeteksi pada $CURRENT_PROVIDER!"
            if [ "$CURRENT_PROVIDER" == "gemini" ]; then
                CURRENT_PROVIDER="openrouter"
                continue
            else
                echo "❌ Kedua provider bermasalah. Cooldown 30 detik..."
                sleep 30
                CURRENT_PROVIDER="gemini"
                continue
            fi
        fi
        return $EXIT_CODE
    done
}

echo "🏗️ [FASE 1] Sequential Generation (Satu per satu)..."
for file in "${FILES[@]}"; do
    if [ ! -f "$BACKEND_DIR/$file" ]; then
        echo "📝 [GENERATE] Membuat file: $file"
        PROMPT="Baca $PRD_FILE dan $CONVENTIONS_FILE. Tugasmu: Buat HANYA file '$file' berdasarkan spesifikasi. Pastikan logika bisnis aman. JANGAN buat atau modifikasi file lain."
        run_aider_with_fallback "$PROMPT" "--read $PRD_FILE --read $CONVENTIONS_FILE"
    else
        echo "⏭️ [SKIP] File $file sudah ada."
    fi
done

echo "🚀 [FASE 2] CI/CD Agentic Loop..."
cd "$ROOT_DIR" || exit 1

# Sinkronisasi dengan GitHub untuk mencegah konflik
echo "🔄 Sinkronisasi dengan GitHub..."
git fetch origin main
git merge origin/main --allow-unrelated-histories -m "Merge remote changes" || true

for (( i=1; i<=MAX_FIX_RETRIES; i++ )); do
    echo "🔄 [ITERASI $i] Commit dan Push..."
    git add .
    git commit -m "Agentic backend iteration $i" || echo "Tidak ada perubahan"
    
    git push origin main || true

    cd "$BACKEND_DIR" || exit 1
    echo "⏳ Menunggu GitHub Actions selesai..."
    
    # Ambil run ID terbaru
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    
    if [ -z "$RUN_ID" ]; then 
        echo "⚠️ Belum ada workflow berjalan. Menunggu 15 detik..."
        sleep 15
        continue
    fi

    # Tunggu workflow selesai
    gh run watch "$RUN_ID" --exit-status || true
    STATUS=${PIPESTATUS[0]}

    if [ "$STATUS" -eq 0 ]; then
        echo "✅ [SUCCESS] Backend berhasil Build & Test di GitHub Actions!"
        exit 0
    fi

    echo "❌ [FAIL] Gagal. Mengambil log error..."
    gh run view "$RUN_ID" --log > "$ROOT_DIR/gh_log.txt"
    
    # Ekstrak hanya baris error agar hemat token & RAM
    grep -iE "error|failed|exception|traceback" "$ROOT_DIR/gh_log.txt" | head -n 30 > "$ROOT_DIR/filtered_errors.txt"
    
    ERROR_CONTEXT=$(cat "$ROOT_DIR/filtered_errors.txt")
    PROMPT="Build/Test di GitHub Actions GAGAL. Berikut log error-nya:
$ERROR_CONTEXT
Tugasmu: Analisis dan perbaiki HANYA file yang disebutkan di error log. Jangan sentuh file lain."
    
    run_aider_with_fallback "$PROMPT"
done
echo "⛔ Mencapai batas maksimal retry."
exit 1
