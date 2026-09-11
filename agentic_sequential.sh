#!/bin/bash
PRD_FILE="../PRD.md"
CONVENTIONS_FILE="../CONVENTIONS.md"
BACKEND_DIR="./backend"
MAX_FIX_RETRIES=5
# Default ke OpenRouter karena routing modelnya lebih stabil
CURRENT_PROVIDER="openrouter"

mkdir -p $BACKEND_DIR
cd $BACKEND_DIR || exit

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
            # Model stabil terbaru dari Google
            MODEL="gemini/gemini-1.5-flash"
        else
            export OPENROUTER_API_KEY="$OPENROUTER_KEY"
            unset GEMINI_API_KEY
            # Model stabil via OpenRouter
            MODEL="openrouter/google/gemini-pro-1.5"
        fi

        echo "⏳ Memproses... (mohon tunggu, sedang membaca PRD & menulis kode)"
        OUTPUT=$(aider $AIDER_BASE_FLAGS $extra_flags --model "$MODEL" --message "$prompt" 2>&1)
        EXIT_CODE=$?
        echo "$OUTPUT"
        
        # Deteksi Rate Limit
        if echo "$OUTPUT" | grep -iqE "rate limit|429|quota exceeded"; then
            echo "⚠️ Rate limit terdeteksi pada $CURRENT_PROVIDER!"
            if [ "$CURRENT_PROVIDER" == "gemini" ]; then
                CURRENT_PROVIDER="openrouter"
                continue
            else
                echo "❌ Kedua provider limit. Cooldown 60 detik..."
                sleep 60
                CURRENT_PROVIDER="gemini"
                continue
            fi
        fi
        return $EXIT_CODE
    done
}

echo "🏗️ [FASE 1] Sequential Generation (Satu per satu)..."
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "📝 [GENERATE] Membuat file: $file"
        PROMPT="Baca $PRD_FILE dan $CONVENTIONS_FILE. Tugasmu: Buat HANYA file '$file' berdasarkan spesifikasi. Pastikan logika bisnis aman. JANGAN buat atau modifikasi file lain."
        run_aider_with_fallback "$PROMPT" "--read $PRD_FILE --read $CONVENTIONS_FILE"
    else
        echo "⏭️ [SKIP] File $file sudah ada."
    fi
done

echo "🚀 [FASE 2] CI/CD Agentic Loop..."
cd ..

# PENTING: Tarik perubahan dari GitHub dulu untuk mencegah error 'rejected'
echo "🔄 Sinkronisasi dengan GitHub..."
git pull origin main --allow-unrelated-histories || true

for (( i=1; i<=MAX_FIX_RETRIES; i++ )); do
    echo "🔄 [ITERASI $i] Commit dan Push..."
    git add .
    git commit -m "Agentic backend iteration $i" || echo "Tidak ada perubahan"
    
    # Push ke GitHub
    git push origin main
    PUSH_STATUS=$?
    if [ $PUSH_STATUS -ne 0 ]; then
        echo "⚠️ Gagal push biasa, mencoba force push (aman untuk repo baru)..."
        git push -f origin main || true
    fi

    cd $BACKEND_DIR
    echo "⏳ Menunggu GitHub Actions selesai..."
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    
    if [ -z "$RUN_ID" ]; then 
        echo "⚠️ Belum ada workflow berjalan. Menunggu 15 detik..."
        sleep 15
        continue
    fi

    gh run watch $RUN_ID --exit-status
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        echo "✅ [SUCCESS] Backend berhasil Build & Test di GitHub Actions!"
        exit 0
    fi

    echo "❌ [FAIL] Gagal. Mengambil log error..."
    gh run view $RUN_ID --log > gh_log.txt
    # Ekstrak hanya baris error agar hemat token & RAM
    grep -iE "error|failed|exception|traceback" gh_log.txt | head -n 30 > filtered_errors.txt
    
    ERROR_CONTEXT=$(cat filtered_errors.txt)
    PROMPT="Build/Test di GitHub Actions GAGAL. Berikut log error-nya:
$ERROR_CONTEXT
Tugasmu: Analisis dan perbaiki HANYA file yang disebutkan di error log. Jangan sentuh file lain."
    
    run_aider_with_fallback "$PROMPT"
done
echo "⛔ Mencapai batas maksimal retry."
exit 1
