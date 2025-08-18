FROM runpod/base:0.6.3-cuda11.8.0

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
COPY 360.json .
COPY requirements.txt /requirements.txt
ENV PIP_ROOT_USER_ACTION=ignore
RUN python -m pip install --upgrade pip && \
    uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu129 --no-cache-dir && \
    uv pip install --upgrade -r /requirements.txt --no-cache-dir

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

# Install models
WORKDIR /ComfyUI/models

RUN git clone https://huggingface.co/happyneishon/models360 

# Add files
WORKDIR /
COPY handler.py .
# Run the handler
CMD python /ComfyUI/main.py --listen 0.0.0.0 & python -u /handler.py
