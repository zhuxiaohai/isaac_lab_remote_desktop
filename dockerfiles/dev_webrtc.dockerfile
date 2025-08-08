ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}


# switch to root user to install dependencies
USER root

# Install Basic Dependencies


# Install Basic Dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends \
    locales \
    git \
    git-lfs \
    curl \
    wget \
    vim \
    sudo \
    software-properties-common \
    net-tools \
    htop \
    cmake \
    build-essential \
    unzip \
    python3 \
    python3-pip \
    python3-dev \
    libopencv-dev \
    python3-opencv \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-dev


# Create user if doesn't exist
RUN if [ "${USERNAME}" != "root" ]; then \
        if ! id -u ${USERNAME} >/dev/null 2>&1; then \
            useradd -m -s /bin/bash ${USERNAME}; \
        fi && \
        usermod -aG sudo ${USERNAME} && \
        echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    fi

# Configure pip to use Aliyun mirror for root user
RUN mkdir -p /root/.pip && \
    echo "[global]" > /root/.pip/pip.conf && \
    echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> /root/.pip/pip.conf && \
    echo "trusted-host = mirrors.aliyun.com" >> /root/.pip/pip.conf

# Download Isaac Sim as root (避免权限问题)
RUN --mount=type=cache,target=/tmp/isaac_cache \
    ISAAC_ZIP="isaac-sim-standalone@4.5.0-rc.36+release.19112.f59b3005.gl.linux-x86_64.release.zip" && \
    ISAAC_URL="https://download.isaacsim.omniverse.nvidia.com/isaac-sim-standalone%404.5.0-rc.36%2Brelease.19112.f59b3005.gl.linux-x86_64.release.zip" && \
    cd /tmp/isaac_cache && \
    if [ ! -f "${ISAAC_ZIP}" ] || ! unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1; then \
        echo "=== Downloading Isaac Sim 4.5.0 ===" && \
        rm -f "${ISAAC_ZIP}" && \
        wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${ISAAC_URL}" -O "${ISAAC_ZIP}" && \
        echo "=== Verifying download ===" && \
        if unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1; then \
            echo "=== Download verified successfully ==="; \
        else \
            echo "=== Download verification failed, retrying with curl ===" && \
            rm -f "${ISAAC_ZIP}" && \
            curl -L --retry 3 --retry-delay 5 --connect-timeout 30 -o "${ISAAC_ZIP}" "${ISAAC_URL}" && \
            unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1 || (echo "=== Download failed ===" && exit 1); \
        fi && \
        echo "=== Download completed ==="; \
    else \
        echo "=== Using cached Isaac Sim ==="; \
    fi


# Switch to non-root user for installation
USER ${USERNAME}

# Configure pip to use Aliyun mirror for non-root user
RUN mkdir -p /home/${USERNAME}/.pip && \
    echo "[global]" > /home/${USERNAME}/.pip/pip.conf && \
    echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> /home/${USERNAME}/.pip/pip.conf && \
    echo "trusted-host = mirrors.aliyun.com" >> /home/${USERNAME}/.pip/pip.conf

# Create Isaac Sim directory following official documentation
RUN mkdir -p /home/${USERNAME}/isaacsim


# Extract Isaac Sim to ~/isaacsim (following official documentation)
RUN --mount=type=cache,target=/tmp/isaac_cache,readonly \
    ISAAC_ZIP="isaac-sim-standalone@4.5.0-rc.36+release.19112.f59b3005.gl.linux-x86_64.release.zip" && \
    echo "=== Extracting Isaac Sim to ~/isaacsim ===" && \
    cd /home/${USERNAME} && \
    unzip -q "/tmp/isaac_cache/${ISAAC_ZIP}" -d isaacsim/ && \
    echo "=== Isaac Sim extraction completed ===" && \
    ls -la isaacsim/

# Run official post-install scripts (as per official documentation)
RUN cd /home/${USERNAME}/isaacsim && \
    echo "=== Running official post_install.sh ===" && \
    ./post_install.sh && \
    # echo "=== Running isaac-sim.selector.sh ===" && \
    # ./isaac-sim.selector.sh && \
    echo "=== Isaac Sim post-install completed ==="

# Set Isaac Sim environment variables (following official documentation)
RUN echo "# Isaac Sim environment variables" >> /home/${USERNAME}/.bashrc && \
    echo "export ISAACSIM_PATH=\"/home/${USERNAME}/isaacsim\"" >> /home/${USERNAME}/.bashrc && \
    echo "export ISAACSIM_PYTHON_EXE=\"\${ISAACSIM_PATH}/python.sh\"" >> /home/${USERNAME}/.bashrc && \
    echo "export PATH=\"\${ISAACSIM_PATH}:\${PATH}\"" >> /home/${USERNAME}/.bashrc

# Clone Isaac Lab repository (as per official documentation)
RUN cd /home/${USERNAME} && \
    echo "=== Cloning Isaac Lab repository ===" && \
    cat /etc/resolv.conf && \
    git clone https://github.com/isaac-sim/IsaacLab.git && \
    echo "=== Isaac Lab repository cloned ==="

# Create Isaac Sim symbolic link (as per official documentation)
RUN cd /home/${USERNAME}/IsaacLab && \
    echo "=== Creating Isaac Sim symbolic link ===" && \
    ln -s /home/${USERNAME}/isaacsim _isaac_sim && \
    echo "=== Isaac Sim symbolic link created ==="

# Install Isaac Lab extensions and dependencies (as per official documentation)
RUN cd /home/${USERNAME}/IsaacLab && \
    echo "=== Installing Isaac Lab extensions ===" && \
    export TERM=xterm && \
    export DEBIAN_FRONTEND=noninteractive && \
    /home/${USERNAME}/isaacsim/python.sh -m pip install --upgrade pip && \
    ./isaaclab.sh --install && \
    echo "=== Isaac Lab installation completed ==="

# Switch back to root for system configuration
USER root


# Clean up cache but preserve Isaac Sim cache
RUN apt autoclean && apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* && \
    # Keep Isaac Sim cache directory, remove everything else in /tmp
    find /tmp -mindepth 1 -maxdepth 1 ! -name 'isaac_cache' -exec rm -rf {} + 2>/dev/null || true


# Pitch to avoid removing all content in ~/.cache
RUN sed -i "s|sudo rm -rf /tmp/.X\* ~/.cache|sudo rm -rf /tmp/.X* \&\& sudo find ~/.cache -mindepth 1 -maxdepth 1 ! -name 'pip' ! -name 'ov' ! -name 'uv' ! -name 'packman' -exec rm -rf {} +|g" /etc/entrypoint.sh



# Restore User
USER ${USERNAME}