FROM runpod/base:0.6.3-cuda11.8.0

# Install base
RUN apt-get update && apt-get install -y git wget libgl1-mesa-glx libglib2.0-0 && rm -rf /var/lib/apt/lists/*

# Set python3.11 as the default python
RUN ln -sf $(which python3.11) /usr/local/bin/python && \
    ln -sf $(which python3.11) /usr/local/bin/python3

# Install ComfyUI
WORKDIR /
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

# Install dependencies
WORKDIR /ComfyUI
COPY requirements.txt /requirements.txt
RUN uv pip install --upgrade -r /requirements.txt --no-cache-dir --system

# Install custom_nodes
WORKDIR /ComfyUI/custom_nodes

RUN git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager

RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts

RUN git clone https://github.com/rgthree/rgthree-comfy

RUN git clone https://github.com/kijai/ComfyUI-KJNodes

RUN git clone https://github.com/kijai/ComfyUI-Florence2

RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale

RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes

RUN git clone https://github.com/welltop-cn/ComfyUI-TeaCache

RUN git clone https://github.com/cubiq/ComfyUI_essentials

RUN git clone http://github.com/Jonseed/ComfyUI-Detail-Daemon

RUN git clone https://github.com/Acly/comfyui-tooling-nodes

RUN git clone https://github.com/BadCafeCode/masquerade-nodes-comfyui

RUN git clone https://github.com/filliptm/ComfyUI_Fill-Nodes

RUN git clone https://github.com/bash-j/mikey_nodes

RUN git clone https://github.com/evanspearman/ComfyMath

RUN git clone https://github.com/alexopus/ComfyUI-Image-Saver

RUN git clone https://github.com/ProGamerGov/ComfyUI_preview360panorama

# Install models
WORKDIR /ComfyUI/models

RUN git clone https://huggingface.co/happyneishon/models360 

# Add files
WORKDIR /ComfyUI
ADD handler.py .
ADD 360.json .

# Run the handler
CMD python main.py --listen 0.0.0.0 & python -u /handler.py
