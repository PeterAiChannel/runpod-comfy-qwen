#!/usr/bin/env bash
set -e

# =========================
# CẤU HÌNH CHUNG (CHỈNH NẾU CẦN)
# =========================
export WORKDIR="/workspace"           # <<<KIỂM TRA/CHỈNH>>> Thư mục volume bền vững
export ENABLE_JUPYTER="1"             # 1=bật JupyterLab (8888), 0=tắt
export JUPYTER_TOKEN=""               # <<<KIỂM TRA/CHỈNH>>> Đặt token cho Jupyter (có thể để trống)
: "${HF_TOKEN?Thiếu HF_TOKEN - hãy tạo Secret HF_TOKEN và map vào ENV}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# =========================
# ONE-TIME SETUP (idempotent)
# =========================
if [ ! -f "$WORKDIR/.setup_done" ]; then
  echo "[SETUP] One-time environment setup..."

  # Python venv + pip
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip wheel

  # Jupyter (tùy chọn)
  if [ "$ENABLE_JUPYTER" = "1" ]; then
    pip install jupyterlab
  fi

  # Hugging Face CLI + Git LFS
  pip install "huggingface_hub[cli]"
  (sudo apt-get update -y || true)
  (sudo apt-get install -y git-lfs || true)
  (git lfs install || true)

  # ComfyUI (repo chính thức, bản mới)
  if [ ! -d "$WORKDIR/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
  fi
  pip install -r ComfyUI/requirements.txt || true

  # =========================
  # CÀI ĐẶT CUSTOM NODES PHỔ BIẾN
  # =========================
  CUSTOM_NODES_DIR="$WORKDIR/ComfyUI/custom_nodes"
  mkdir -p "$CUSTOM_NODES_DIR"

  # Danh sách node: [tên-thư-mục]=[git-url]
  declare -A NODES_LIST=(
    ["ComfyUI-Manager"]="https://github.com/Comfy-Org/ComfyUI-Manager.git"
    ["was-node-suite-comfyui"]="https://github.com/WASasquatch/was-node-suite-comfyui.git"
    ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    ["ComfyUI_essentials"]="https://github.com/cubiq/ComfyUI_essentials.git"
    ["ComfyUI-KJNodes"]="https://github.com/kijai/ComfyUI-KJNodes.git"
    ["cg-use-everywhere"]="https://github.com/chrisgoringe/cg-use-everywhere.git"
    # <<<KIỂM TRA/CHỈNH>>> thêm node mới: ["FolderName"]="https://github.com/owner/repo.git"
  )

  for NODE_DIR in "${!NODES_LIST[@]}"; do
    NODE_PATH="$CUSTOM_NODES_DIR/$NODE_DIR"
    if [ ! -d "$NODE_PATH" ]; then
      echo "[NODE] Installing $NODE_DIR ..."
      git clone "${NODES_LIST[$NODE_DIR]}" "$NODE_PATH"
    else
      echo "[NODE] $NODE_DIR đã tồn tại, bỏ qua."
    fi
  done

  touch "$WORKDIR/.setup_done"
  echo "[SETUP] Base setup done."
else
  echo "[SETUP] Already initialized. Skipping base setup."
  source venv/bin/activate
fi

# =========================
# QWEN MODELS (UNet + CLIP + VAE)
# =========================
# Thư mục đích trong ComfyUI
export QWEN_UNET_DIR="$WORKDIR/ComfyUI/models/unet"
export QWEN_CLIP_DIR="$WORKDIR/ComfyUI/models/clip"
export QWEN_VAE_DIR="$WORKDIR/ComfyUI/models/vae"

# Repo & file trên Hugging Face (theo các link bạn cung cấp)
# 1) Diffusion / UNet
export QWEN_UNET_REPO="f5aiteam/Diffusion_Models"
export QWEN_UNET_FILE="qwen_image_fp8_e4m3fn.safetensors"
# 2) CLIP
export QWEN_CLIP_REPO="f5aiteam/CLIP"
export QWEN_CLIP_FILE="qwen_2.5_vl_7b_fp8_scaled.safetensors"
# 3) VAE
export QWEN_VAE_REPO="f5aiteam/VAE"
export QWEN_VAE_FILE="qwen_image_vae.safetensors"

# Helper tải 1 file (idempotent)
hf_pull () {
  local repo="$1"; local file="$2"; local out="$3"
  mkdir -p "$out"
  if [ -f "$out/$file" ]; then
    echo "[HF] Exists: $out/$file"
  else
    echo "[HF] Download $repo :: $file -> $out"
    huggingface-cli download "$repo" "$file"       --local-dir "$out"       --local-dir-use-symlinks False       --token "$HF_TOKEN" || true
  fi
}

# Tải bộ 3 model (chạy ở mỗi boot, nhưng chỉ tải nếu thiếu)
hf_pull "$QWEN_UNET_REPO" "$QWEN_UNET_FILE" "$QWEN_UNET_DIR"
hf_pull "$QWEN_CLIP_REPO" "$QWEN_CLIP_FILE" "$QWEN_CLIP_DIR"
hf_pull "$QWEN_VAE_REPO" "$QWEN_VAE_FILE" "$QWEN_VAE_DIR"

# ComfyUI (foreground) 0.0.0.0:8188
cd "$WORKDIR/ComfyUI"
exec python main.py --listen 0.0.0.0 --port 8188
