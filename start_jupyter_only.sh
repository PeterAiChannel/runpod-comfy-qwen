#!/usr/bin/env bash
set -e

# =========================
# CẤU HÌNH
# =========================
WORKDIR="/workspace"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# =========================
# ONE-TIME SETUP (idempotent)
# =========================
if [ ! -f "$WORKDIR/.comfy_only_setup_done" ]; then
  echo "[SETUP] Creating Python venv..."
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip wheel

  echo "[SETUP] Cloning ComfyUI..."
  if [ ! -d "$WORKDIR/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
  fi

  echo "[SETUP] Installing ComfyUI requirements..."
  pip install -r ComfyUI/requirements.txt || true

  touch "$WORKDIR/.comfy_only_setup_done"
  echo "[SETUP] Done."
else
  echo "[SETUP] Already initialized. Skipping setup."
  source venv/bin/activate
fi

# =========================
# KHÔNG CHẠY GÌ HẾT — chỉ chuẩn bị xong môi trường
# =========================
echo "[INFO] ComfyUI setup is ready at $WORKDIR/ComfyUI"
echo "[INFO] Để chạy ComfyUI thủ công, mở terminal và gõ:"
echo "   cd /workspace/ComfyUI"
echo "   source /workspace/venv/bin/activate"
echo "   python main.py --listen 0.0.0.0 --port 8188"
