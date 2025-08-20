FROM runpod/base:0.6.3-cuda11.8.0

ARG HF_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

# Install base
RUN apt-get update && apt-get install -y git wget libgl1-mesa-glx libglib2.0-0 && rm -rf /var/lib/apt/lists/*

# Set python3.11 venv
RUN python3.11 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

# Install ComfyUI
WORKDIR /
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

# Install dependencies
WORKDIR /ComfyUI
COPY requirements.txt /requirements.txt
ENV PIP_ROOT_USER_ACTION=ignore
RUN python -m pip install --upgrade pip && \
    uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu129 --no-cache-dir && \
    uv pip install --upgrade -r /requirements.txt --no-cache-dir


# Install models
RUN wget --header="Authorization: Bearer ${HF_TOKEN}" https://huggingface.co/neishonagenc/360models/resolve/main/diffusion_models/flux1-kontext-dev.safetensors -O /ComfyUI/models/diffusion_models/flux1-kontext-dev.safetensors

RUN wget --header="Authorization: Bearer ${HF_TOKEN}" https://huggingface.co/neishonagenc/360models/resolve/main/text_encoders/t5xxl_fp16.safetensors -O /ComfyUI/models/text_encoders/t5xxl_fp16.safetensors
RUN wget --header="Authorization: Bearer ${HF_TOKEN}" https://huggingface.co/neishonagenc/360models/resolve/main/text_encoders/clip_l.safetensors -O /ComfyUI/models/text_encoders/clip_l.safetensors

RUN wget --header="Authorization: Bearer ${HF_TOKEN}" https://huggingface.co/neishonagenc/360models/resolve/main/vae/ae.safetensors -O /ComfyUI/models/vae/ae.safetensors

RUN wget --header="Authorization: Bearer ${HF_TOKEN}" https://huggingface.co/neishonagenc/360models/resolve/main/loras/HDR360.safetensors -O /ComfyUI/models/loras/HDR360.safetensors

# Install custom_nodes
WORKDIR /ComfyUI/custom_nodes

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts && \
    git clone https://github.com/rgthree/rgthree-comfy && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    git clone https://github.com/kijai/ComfyUI-Florence2 && \
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes && \
    git clone https://github.com/welltop-cn/ComfyUI-TeaCache && \
    git clone https://github.com/cubiq/ComfyUI_essentials && \
    git clone http://github.com/Jonseed/ComfyUI-Detail-Daemon && \
    git clone https://github.com/Acly/comfyui-tooling-nodes && \
    git clone https://github.com/BadCafeCode/masquerade-nodes-comfyui && \
    git clone https://github.com/filliptm/ComfyUI_Fill-Nodes && \
    git clone https://github.com/bash-j/mikey_nodes && \
    git clone https://github.com/evanspearman/ComfyMath && \
    git clone https://github.com/alexopus/ComfyUI-Image-Saver && \
    git clone https://github.com/ProGamerGov/ComfyUI_preview360panorama

# Install custom_nodes dependencies
RUN for d in */ ; do \
        # Проверяем, что это не менеджер и что файл requirements.txt существует
        if [ "$d" != "comfyui-manager/" ] && [ -f "${d}requirements.txt" ]; then \
            echo "--- Installing requirements for $d ---"; \
            pip install -r "${d}requirements.txt"; \
        fi; \
    done



# Add files
WORKDIR /
COPY 360.json .
COPY handler.py .
# Run the handler
CMD python /ComfyUI/main.py & python -u /handler.py
