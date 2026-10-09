#!/usr/bin/env bash
# Downloads the model files that ship inside the installer, so the app works
# offline from first launch with nothing to download. Run once before building.
# Without them the app still builds and offers the one-time download instead.
set -euo pipefail
cd "$(dirname "$0")/../assets/models"

get() {
  if [ -s "$2" ]; then echo "have $2"; return; fi
  echo "fetching $2"
  curl -fL --retry 3 -o "$2.part" "$1"
  mv "$2.part" "$2"
}

get https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm
get https://huggingface.co/litert-community/whisper-base/resolve/main/whisper_base_30s_i8.tflite whisper_base_30s_i8.tflite
get https://huggingface.co/openai/whisper-base/resolve/main/tokenizer.json whisper_base_tokenizer.json
ls -la
