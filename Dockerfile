# WanGP (Wan2GP, deepbeepmeep) sur GPU NVIDIA, pour la machine de prototypage de l'EPF.
# Versions conseillées par docs/INSTALLATION.md de WanGP : Python 3.10, PyTorch 2.6.0 + CUDA 12.4
# (RTX 10xx à 40xx, A100, H100). Pour une RTX 50xx : TORCH_VERSION=2.7.0, TORCH_CUDA=cu128 et une
# image de base CUDA 12.8 (voir README).
ARG CUDA_IMAGE=nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

ARG WANGP_REPO=https://github.com/deepbeepmeep/Wan2GP.git
# Commit ou tag de WanGP : fixe-le (README, « Figer la version ») pour que les mesures soient comparables.
ARG WANGP_REF=main
ARG TORCH_VERSION=2.6.0
ARG TORCH_CUDA=cu124
# 1 = installe Sage Attention 1.0.6 (environ 30 % plus rapide d'après WanGP) ; 0 = attention sdpa.
ARG WITH_SAGE=1

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/data/cache/huggingface \
    TORCH_HOME=/data/cache/torch \
    XDG_CACHE_HOME=/data/cache

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3.10-venv python3-pip git ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.10 /usr/local/bin/python

WORKDIR /opt
RUN git clone ${WANGP_REPO} wangp && cd wangp && git checkout ${WANGP_REF} && git log -1 --format='WanGP %h %cs' > /opt/WANGP_VERSION
WORKDIR /opt/wangp

RUN python -m pip install --upgrade pip \
    && python -m pip install torch==${TORCH_VERSION} torchvision torchaudio --index-url https://download.pytorch.org/whl/${TORCH_CUDA} \
    && python -m pip install -r requirements.txt \
    && if [ "${WITH_SAGE}" = "1" ]; then python -m pip install sageattention==1.0.6; fi

# Utilisateur sans droits root, avec l'UID de l'hôte (fichiers de /data lisibles par toi).
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} wangp 2>/dev/null || true \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash wangp 2>/dev/null || true \
    && chown -R ${UID}:${GID} /opt/wangp
USER ${UID}:${GID}

COPY --chown=${UID}:${GID} scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
EXPOSE 7860
ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
