#!/usr/bin/env bash
set -e

# =========================
# CẤU HÌNH
# =========================
WORKDIR="/workspace"
JUPYTER_TOKEN=""      # để trống = không cần token, đặt chuỗi nếu muốn bảo vệ
JUPYTER_PORT="8888"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# =========================
# ONE-TIME SETUP (idempotent)
# =========================
if [ ! -f "$WORKDIR/.jupyter_only_setup_done" ]; then
  echo "[SETUP] Creating Python venv & installing minimal deps..."
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip wheel

  echo "[SETUP] Installing JupyterLab..."
  pip install jupyterlab

  echo "[SETUP] Cloning ComfyUI (no models, no custom nodes)..."
  if [ ! -d "$WORKDIR/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
  fi
  echo "[SETUP] Installing ComfyUI requirements..."
  pip install -r ComfyUI/requirements.txt || true

  touch "$WORKDIR/.jupyter_only_setup_done"
  echo "[SETUP] Done."
else
  echo "[SETUP] Already initialized. Skipping setup."
  source venv/bin/activate
fi

# =========================
# RUN JUPYTER ONLY
# =========================
echo "[RUN] Starting JupyterLab on 0.0.0.0:${JUPYTER_PORT} (root_dir=${WORKDIR})"
exec jupyter lab \
  --ServerApp.ip=0.0.0.0 \
  --ServerApp.port="${JUPYTER_PORT}" \
  --ServerApp.token="${JUPYTER_TOKEN}" \
  --ServerApp.root_dir="${WORKDIR}" \
  --ServerApp.open_browser=False
