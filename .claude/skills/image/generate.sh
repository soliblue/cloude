#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output/misc"
MODEL="${GEMINI_MODEL:-gemini-3-pro-image-preview}"
API_BASE="https://generativelanguage.googleapis.com/v1beta/models"

usage() {
    cat <<'USAGE'
Usage: generate.sh --prompt "description" [options]

Options:
  --prompt TEXT        Image description (required)
  --output NAME        Output filename without extension (default: image-TIMESTAMP)
  --output-dir DIR     Output directory (default: .claude/skills/image/output/misc/)
  --edit PATH          Existing image to edit (sends image + prompt to Gemini)
  --aspect RATIO       Aspect ratio hint in prompt (e.g. "16:9", "square", "portrait")
  --grid SPEC          Generate multiple images in a grid (e.g. "2x2", "3x3")
  --model MODEL        Gemini model (default: gemini-2.0-flash-exp)
USAGE
    exit 1
}

PROMPT=""
OUTPUT_NAME=""
EDIT_IMAGE=""
ASPECT=""
GRID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt) PROMPT="$2"; shift 2 ;;
        --output) OUTPUT_NAME="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --edit) EDIT_IMAGE="$2"; shift 2 ;;
        --aspect) ASPECT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --grid) GRID="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$PROMPT" ]]; then
    echo "Error: --prompt is required"
    usage
fi

if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
    echo "Error: GOOGLE_API_KEY not set"
    exit 1
fi

if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="image-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUTPUT_DIR"

if [[ -n "$ASPECT" ]]; then
    PROMPT="$PROMPT. Aspect ratio: $ASPECT"
fi

GRID_BORDER=6
if [[ -n "$GRID" ]]; then
    GRID_TEMPLATE=$(mktemp /tmp/grid-template-XXXX.png)
    python3 "$SCRIPT_DIR/grid.py" create --grid "$GRID" --border "$GRID_BORDER" --output "$GRID_TEMPLATE"
    EDIT_IMAGE="$GRID_TEMPLATE"
    PROMPT="This is a grid template with ${GRID} cells separated by black borders. Fill each cell with a different variation of: ${PROMPT}. Keep each cell distinct. Do not remove or alter the grid borders."
fi

build_request_body() {
    local parts_json

    if [[ -n "$EDIT_IMAGE" ]]; then
        if [[ ! -f "$EDIT_IMAGE" ]]; then
            echo "Error: edit image not found: $EDIT_IMAGE"
            exit 1
        fi

        local mime_type
        case "${EDIT_IMAGE##*.}" in
            jpg|jpeg) mime_type="image/jpeg" ;;
            png) mime_type="image/png" ;;
            webp) mime_type="image/webp" ;;
            gif) mime_type="image/gif" ;;
            *) mime_type="image/png" ;;
        esac

        local b64_data
        b64_data="$(base64 < "$EDIT_IMAGE")"

        parts_json=$(printf '[{"text": "%s"}, {"inline_data": {"mime_type": "%s", "data": "%s"}}]' \
            "$(echo "$PROMPT" | sed 's/"/\\"/g; s/\n/\\n/g')" \
            "$mime_type" \
            "$b64_data")
    else
        parts_json=$(printf '[{"text": "%s"}]' "$(echo "$PROMPT" | sed 's/"/\\"/g; s/\n/\\n/g')")
    fi

    printf '{"contents": [{"parts": %s}], "generationConfig": {"responseModalities": ["image", "text"]}}' "$parts_json"
}

echo "Generating: $PROMPT"
echo "Model: $MODEL"
[[ -n "$EDIT_IMAGE" ]] && echo "Editing: $EDIT_IMAGE"

RESPONSE_FILE=$(mktemp)
REQUEST_FILE=$(mktemp)
trap "rm -f '$RESPONSE_FILE' '$REQUEST_FILE'" EXIT

build_request_body > "$REQUEST_FILE"

HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
    -X POST \
    -H "Content-Type: application/json" \
    "${API_BASE}/${MODEL}:generateContent?key=${GOOGLE_API_KEY}" \
    -d @"$REQUEST_FILE")

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "Error: API returned HTTP $HTTP_CODE"
    cat "$RESPONSE_FILE"
    exit 1
fi

MIME_TYPE=$(python3 -c "
import json, sys
data = json.load(open('$RESPONSE_FILE'))
for part in data['candidates'][0]['content']['parts']:
    if 'inlineData' in part:
        print(part['inlineData']['mimeType'])
        sys.exit(0)
print('none')
")

if [[ "$MIME_TYPE" == "none" ]]; then
    echo "Error: No image in response"
    python3 -c "
import json
data = json.load(open('$RESPONSE_FILE'))
for part in data['candidates'][0]['content']['parts']:
    if 'text' in part:
        print(part['text'])
"
    exit 1
fi

EXT="png"
case "$MIME_TYPE" in
    image/jpeg) EXT="jpg" ;;
    image/webp) EXT="webp" ;;
    image/gif) EXT="gif" ;;
esac

OUTPUT_PATH="$OUTPUT_DIR/${OUTPUT_NAME}.${EXT}"

python3 -c "
import json, base64
data = json.load(open('$RESPONSE_FILE'))
for part in data['candidates'][0]['content']['parts']:
    if 'inlineData' in part:
        img_bytes = base64.b64decode(part['inlineData']['data'])
        with open('$OUTPUT_PATH', 'wb') as f:
            f.write(img_bytes)
        break
"

echo "Saved: $OUTPUT_PATH"

if [[ -n "$GRID" ]]; then
    echo "Splitting grid into individual images..."
    python3 "$SCRIPT_DIR/grid.py" split \
        --input "$OUTPUT_PATH" \
        --grid "$GRID" \
        --border "$GRID_BORDER" \
        --output-dir "$OUTPUT_DIR" \
        --prefix "$OUTPUT_NAME"
    rm -f "$OUTPUT_PATH" "${GRID_TEMPLATE:-}"
fi

TEXT_RESPONSE=$(python3 -c "
import json
data = json.load(open('$RESPONSE_FILE'))
for part in data['candidates'][0]['content']['parts']:
    if 'text' in part:
        print(part['text'])
" 2>/dev/null || true)

if [[ -n "$TEXT_RESPONSE" ]]; then
    echo "Model notes: $TEXT_RESPONSE"
fi

if [[ -z "$GRID" ]]; then
    echo "$OUTPUT_PATH"
fi
