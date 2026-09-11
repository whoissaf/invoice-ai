#!/bin/bash

# Gunakan ABSOLUTE PATH agar tidak error saat pindah direktori
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$ROOT_DIR/PRD.md"
CONVENTIONS_FILE="$ROOT_DIR/CONVENTIONS.md"
BACKEND_DIR="$ROOT_DIR/backend"
MAX_FIX_RETRIES=5

mkdir -p "$BACKEND_DIR"
cd "$BACKEND_DIR" || exit 1

# Flag hemat RAM & matikan warning model
AIDER_BASE_FLAGS="--yes --no-pretty --no-show-model-warnings --map-tokens 1024 --max-chat-history-tokens 1024"

FILES=("requirements.txt" "database.py" "models.py" "schemas.py" "security.py" "routers.py" "main.py")

run_aider() {
    local prompt="$1"
    local extra_flags="$2"
    
    echo "🤖 [INFO] Menggunakan Provider: Gemini (gemini-1.5-flash)"
    export GEMINI_API_KEY="$GEMINI_KEY"
    # Format model yang benar untuk LiteLLM/Aider dengan Gemini API
    MODEL="gemini/gemini-1.5-flash"

    echo "⏳ Memproses... (mohon tunggu, sedang membaca PRD & menulis kode)"
    OUTPUT=$(aider $AIDER_BASE_FLAGS $extra_flags --model "$MODEL" --message "$prompt" 2>&1)
    EXIT_CODE=$?
    echo "$OUTPUT"
    
    # Deteksi Rate Limit
    if echo "$OUTPUT" | grep -iqE "rate limit|429|quota exceeded"; then
        echo "⚠️ Rate limit terdeteksi! Cooldown 60 detik sebelum retry..."
        sleep 60
        run_aider "$prompt" "$extra_flags"
        return $?
    fi
    
    return $EXIT_CODE
}

echo "🏗️ [FASE 1] Sequential Generation (Satu per satu)..."
for file in "${FILES[@]}"; do
    if [ ! -f "$BACKEND_DIR/$file" ]; then
        echo "📝 [GENERATE] Membuat file: $file"
        PROMPT="Baca $PRD_FILE dan $CONVENTIONS_FILE. Tugasmu: Buat HANYA file '$file' berdasarkan spesifikasi. Pastikan logika bisnis aman. JANGAN buat atau modifikasi file lain."
        run_aider "$PROMPT" "--read $PRD_FILE --read $CONVENTIONS_FILE"
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
    echo "⏳ Memeriksa status GitHub Actions..."
    
    # Ambil run ID terbaru
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    
    if [ -z "$RUN_ID" ]; then 
        echo "⚠️ Belum ada workflow berjalan. Menunggu 15 detik..."
        sleep 15
        continue
    fi

    # Cek kesimpulan (conclusion) workflow secara eksplisit agar tidak salah deteksi
    CONCLUSION=$(gh run view "$RUN_ID" --json conclusion -q '.conclusion')
    
    if [ "$CONCLUSION" == "success" ]; then
        echo "✅ [SUCCESS] Backend berhasil Build & Test di GitHub Actions!"
        exit 0
    fi

    if [ "$CONCLUSION" == "failure" ] || [ "$CONCLUSION" == "cancelled" ]; then
        echo "❌ [FAIL] GitHub Actions selesai dengan status: $CONCLUSION. Mengambil log error..."
        gh run view "$RUN_ID" --log > "$ROOT_DIR/gh_log.txt"
    else
        echo "⏳ Workflow masih berjalan, menunggu selesai..."
        gh run watch "$RUN_ID" --exit-status
        STATUS=$?
        if [ "$STATUS" -eq 0 ]; then
            echo "✅ [SUCCESS] Backend berhasil Build & Test di GitHub Actions!"
            exit 0
        fi
        echo "❌ [FAIL] Gagal. Mengambil log error..."
        gh run view "$RUN_ID" --log > "$ROOT_DIR/gh_log.txt"
    fi
    
    # Ekstrak hanya baris error agar hemat token & RAM
    grep -iE "error|failed|exception|traceback" "$ROOT_DIR/gh_log.txt" | head -n 30 > "$ROOT_DIR/filtered_errors.txt"
    
    ERROR_CONTEXT=$(cat "$ROOT_DIR/filtered_errors.txt")
    if [ -z "$ERROR_CONTEXT" ]; then
        ERROR_CONTEXT="Tidak ada error spesifik yang tertangkap. Silakan periksa log secara manual."
    fi

    PROMPT="Build/Test di GitHub Actions GAGAL. Berikut log error-nya:
$ERROR_CONTEXT
Tugasmu: Analisis dan perbaiki HANYA file yang disebutkan di error log. Jangan sentuh file lain."
    
    run_aider "$PROMPT"
done
echo "⛔ Mencapai batas maksimal retry ($MAX_FIX_RETRIES). Silakan periksa manual."
exit 1
