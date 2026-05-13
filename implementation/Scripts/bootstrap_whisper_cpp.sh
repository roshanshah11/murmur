#!/usr/bin/env bash
set -euo pipefail

# Bootstrap helper for local development.
# This script intentionally clones/builds whisper.cpp as a local sidecar.
# The FlowLite app itself does not use network calls during dictation.

DEV_DIR="${HOME}/dev"
WHISPER_DIR="${DEV_DIR}/whisper.cpp"
MODEL_DIR="${HOME}/models"
MODEL_NAME="small.en-q5_1"

mkdir -p "$DEV_DIR" "$MODEL_DIR"

if [ ! -d "$WHISPER_DIR" ]; then
  git clone https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
fi

cd "$WHISPER_DIR"

# Optionally pin to a known-good tag/commit via WHISPER_TAG env var.
if [ -n "${WHISPER_TAG:-}" ]; then
  echo "Checking out whisper.cpp tag: ${WHISPER_TAG}"
  git fetch --tags --quiet || true
  git checkout "$WHISPER_TAG"
fi

# Build with Metal acceleration on Apple Silicon, plain CPU on Intel.
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  echo "Detected Apple Silicon — building with Metal acceleration."
  cmake -B build -DGGML_METAL=ON
else
  echo "Detected ${ARCH} — building CPU-only."
  cmake -B build
fi
cmake --build build -j

# Model download helper from whisper.cpp repository.
bash ./models/download-ggml-model.sh "${MODEL_NAME}"
cp "models/ggml-${MODEL_NAME}.bin" "${MODEL_DIR}/ggml-${MODEL_NAME}.bin"

cat <<EOF

whisper.cpp built and model installed.

Binary path:
  ${WHISPER_DIR}/build/bin/whisper-cli

Model path:
  ${MODEL_DIR}/ggml-${MODEL_NAME}.bin

Next steps:
  1. Disable Apple's built-in Dictation:
     System Settings → Keyboard → Dictation shortcut → Off.
     (FlowLite owns the double-tap fn trigger; the OS Dictation feature
     will steal the keypress otherwise.)

  2. On first run of FlowLite, grant the following permissions to the
     FlowLite binary when macOS prompts:
       • Microphone           (for audio capture)
       • Accessibility        (for paste / Cmd+V simulation)
       • Input Monitoring     (for the fn double-tap hotkey)

  3. Defaults in ~/.flow-lite/config.json already match the paths above.
     If you changed MODEL_NAME or installed elsewhere, update:
       whisperBinaryPath  → ${WHISPER_DIR}/build/bin/whisper-cli
       modelPath          → ${MODEL_DIR}/ggml-${MODEL_NAME}.bin
EOF
