#!/bin/bash

# Gunakan ABSOLUTE PATH
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$ROOT_DIR/PRD.md"
CONVENTIONS_FILE="$ROOT_DIR/CONVENTIONS.md"
BACKEND_DIR="$ROOT_DIR/backend"
MAX_FIX_RETRIES=5

mkdir -p "$BACKEND_DIR"
cd "$BACKEND_DIR" || exit 1

# Flag hemat RAM. Peringatan context limit diabaikan karena Gemini 1.5 Flash aslinya support 1 Juta token.
AIDER_BASE_FLAGS="--yes --no-pretty --no-show-model-warnings --map-tokens 1024 --max-chat-history-tokens 1024"

FILES=("requirements.txt" "database.py" "models.py" "schemas.py" "security.py" "routers.py" "main.py")

run_aider() {
    local prompt="$1"
    local extra_flags="$2"
    
    echo "🤖 [INFO] Menggunakan Provider: Gemini (gemini-1.5-flash-latest)"
    export GEMINI_API_KEY="$GEMINI_KEY"
    # FORMAT MODEL PALING STABIL UNTUK GOOGLE AI STUDIO
    MODEL="gemini/gemini-1.5-flash-latest"

    echo "⏳ Memproses... (mohon tunggu)"
    OUTPUT=$(aider $AIDER_BASE_FLAGS $extra_flags --model "$MODEL" --message "$prompt" 2>&1)
    EXIT_CODE=$?
    echo "$OUTPUT"
    
    if echo "$OUTPUT" | grep -iqE "rate limit|429|quota exceeded"; then
        echo "⚠️ Rate limit! Cooldown 60 detik..."
        sleep 60
        run_aider "$prompt" "$extra_flags"
        return $?
    fi
    
    return $EXIT_CODE
}

echo "🏗️ [FASE 1] Sequential Generation..."
for file in "${FILES[@]}"; do
    if [ ! -f "$BACKEND_DIR/$file" ]; then
        echo "📝 [GENERATE] Membuat file: $file"
        PROMPT="Baca $PRD_FILE dan $CONVENTIONS_FILE. Buat HANYA file '$file'. JANGAN modifikasi file lain."
        run_aider "$PROMPT" "--read $PRD_FILE --read $CONVENTIONS_FILE"
    else
        echo "⏭️ [SKIP] File $file sudah ada."
    fi
done

echo "🚀 [FASE 2] CI/CD Agentic Loop..."
cd "$ROOT_DIR" || exit 1

echo "🔄 Sinkronisasi dengan GitHub..."
git fetch origin main
git merge origin/main --allow-unrelated-histories -m "Merge remote" || true

for (( i=1; i<=MAX_FIX_RETRIES; i++ )); do
    echo "🔄 [ITERASI $i] Commit dan Push..."
    
    # AMAN: git add . TIDAK AKAN MENG-UPLOAD FILE DI .gitignore
    git add .
    
    if git diff --staged --quiet; then
        echo "ℹ️ Tidak ada perubahan kode untuk di-commit."
    else
        git commit -m "Agentic backend iteration $i"
        git push origin main || true
    fi

    cd "$BACKEND_DIR" || exit 1
    echo "⏳ Memeriksa status GitHub Actions..."
    
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    
    if [ -z "$RUN_ID" ]; then 
        echo "⚠️ Belum ada workflow. Menunggu 15 detik..."
        sleep 15
        continue
    fi

    CONCLUSION=$(gh run view "$RUN_ID" --json conclusion -q '.conclusion')
    
    if [ "$CONCLUSION" == "success" ]; then
        echo "✅ [SUCCESS] Backend berhasil Build & Test!"
        exit 0
    fi

    echo "❌ [FAIL] Status: $CONCLUSION. Mengambil log..."
    gh run view "$RUN_ID" --log > "$ROOT_DIR/gh_log.txt"
    
    grep -iE "error|failed|exception|traceback" "$ROOT_DIR/gh_log.txt" | head -n 30 > "$ROOT_DIR/filtered_errors.txt"
    
    ERROR_CONTEXT=$(cat "$ROOT_DIR/filtered_errors.txt")
    [ -z "$ERROR_CONTEXT" ] && ERROR_CONTEXT="Tidak ada error spesifik tertangkap."

    PROMPT="GitHub Actions GAGAL. Log error:
$ERROR_CONTEXT
Tugasmu: Analisis dan perbaiki HANYA file yang disebutkan di error log."
    
    run_aider "$PROMPT"
done
echo "⛔ Mencapai batas maksimal retry."
exit 1
