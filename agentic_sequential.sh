#!/bin/bash
PRD_FILE="../PRD.md"
CONVENTIONS_FILE="../CONVENTIONS.md"
BACKEND_DIR="./backend"
MAX_FIX_RETRIES=5
CURRENT_PROVIDER="gemini"

mkdir -p $BACKEND_DIR
cd $BACKEND_DIR || exit

AIDER_BASE_FLAGS="--yes --no-pretty --map-tokens 1024 --max-chat-history-tokens 1024"
FILES=("requirements.txt" "database.py" "models.py" "schemas.py" "security.py" "routers.py" "main.py")

run_aider_with_fallback() {
    local prompt="$1"
    local extra_flags="$2"
    while true; do
        echo "🤖 [INFO] Menjalankan Aider dengan provider: $CURRENT_PROVIDER"
        if [ "$CURRENT_PROVIDER" == "gemini" ]; then
            export GEMINI_API_KEY="$GEMINI_KEY"
            MODEL="gemini/gemini-2.0-flash-exp"
        else
            export OPENROUTER_API_KEY="$OPENROUTER_KEY"
            MODEL="openrouter/google/gemini-2.0-flash-exp"
        fi

        OUTPUT=$(aider $AIDER_BASE_FLAGS $extra_flags --model "$MODEL" --message "$prompt" 2>&1)
        EXIT_CODE=$?
        echo "$OUTPUT"
        
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

echo "🏗️ [FASE 1] Memulai Sequential Generation (Satu per satu)..."
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "📝 [GENERATE] Membuat file: $file"
        PROMPT="Baca $PRD_FILE dan $CONVENTIONS_FILE. Tugasmu: Buat HANYA file '$file' berdasarkan spesifikasi. Pastikan logika bisnis aman. JANGAN buat atau modifikasi file lain."
        run_aider_with_fallback "$PROMPT" "--read $PRD_FILE --read $CONVENTIONS_FILE"
    else
        echo "⏭️ [SKIP] File $file sudah ada."
    fi
done

echo "🚀 [FASE 2] Memulai CI/CD Agentic Loop..."
if [ ! -d "../.git" ]; then
    cd ..
    git init
    git branch -M main
    cd $BACKEND_DIR
fi

for (( i=1; i<=MAX_FIX_RETRIES; i++ )); do
    echo "🔄 [ITERASI $i] Commit dan Push ke GitHub..."
    cd ..
    git add .
    git commit -m "Agentic backend iteration $i" || echo "Tidak ada perubahan"
    # Pastikan remote origin sudah diset sebelum run script ini!
    git push origin main || true
    cd $BACKEND_DIR

    echo "⏳ [WAIT] Menunggu GitHub Actions selesai..."
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    if [ -z "$RUN_ID" ]; then sleep 10; continue; fi

    gh run watch $RUN_ID --exit-status
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        echo "✅ [SUCCESS] Backend berhasil Build & Test!"
        exit 0
    fi

    echo "❌ [FAIL] Gagal. Mengambil log error..."
    gh run view $RUN_ID --log > gh_log.txt
    grep -iE "error|failed|exception|traceback" gh_log.txt | head -n 30 > filtered_errors.txt
    
    ERROR_CONTEXT=$(cat filtered_errors.txt)
    PROMPT="Build/Test di GitHub Actions GAGAL. Berikut log error-nya:
$ERROR_CONTEXT
Tugasmu: Analisis dan perbaiki HANYA file yang error. Jangan sentuh file lain."
    
    run_aider_with_fallback "$PROMPT"
done
echo "⛔ Mencapai batas maksimal retry."
exit 1
