ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}

# switch to root user to install dependencies
USER root

# Install Basic Dependencies
RUN apt update && DEBIAN_FRONTEND=noninteractive \
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

# # Download Isaac Sim as root (避免权限问题)
# RUN --mount=type=cache,target=/tmp/isaac_cache \
#     ISAAC_ZIP="isaac-sim-standalone-5.0.0-linux-x86_64.zip" && \
#     ISAAC_URL="https://download.isaacsim.omniverse.nvidia.com/isaac-sim-standalone-5.0.0-linux-x86_64.zip" && \
#     cd /tmp/isaac_cache && \
#     if [ ! -f "${ISAAC_ZIP}" ] || ! unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1; then \
#         echo "=== Downloading Isaac Sim 5.0.0 ===" && \
#         rm -f "${ISAAC_ZIP}" && \
#         wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${ISAAC_URL}" -O "${ISAAC_ZIP}" && \
#         echo "=== Verifying download ===" && \
#         if unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1; then \
#             echo "=== Download verified successfully ==="; \
#         else \
#             echo "=== Download verification failed, retrying with curl ===" && \
#             rm -f "${ISAAC_ZIP}" && \
#             curl -L --retry 3 --retry-delay 5 --connect-timeout 30 -o "${ISAAC_ZIP}" "${ISAAC_URL}" && \
#             unzip -t "${ISAAC_ZIP}" >/dev/null 2>&1 || (echo "=== Download failed ===" && exit 1); \
#         fi && \
#         echo "=== Download completed ==="; \
#     else \
#         echo "=== Using cached Isaac Sim ==="; \
#     fi
# Download Isaac Sim as root (避免权限问题)
RUN --mount=type=cache,target=/tmp/isaac_cache \
    ISAAC_ZIP="isaac-sim-standalone-5.0.0-linux-x86_64.zip" && \
    ISAAC_URL="https://download.isaacsim.omniverse.nvidia.com/isaac-sim-standalone-5.0.0-linux-x86_64.zip" && \
    cd /tmp/isaac_cache && \
    if [ ! -f "${ISAAC_ZIP}" ]; then \
        echo "=== Downloading Isaac Sim 5.0.0 ===" && \
        wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${ISAAC_URL}" -O "${ISAAC_ZIP}" && \
        echo "=== Download completed ==="; \
    else \
        echo "=== Using cached Isaac Sim ==="; \
    fi

# # Download Miniforge (as root user to avoid permission issues)
# RUN --mount=type=cache,target=/tmp/miniforge_cache \
#     cd /tmp/miniforge_cache && \
#     MINIFORGE_SCRIPT="Miniforge3-$(uname)-$(uname -m).sh" && \
#     MINIFORGE_URL="https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge/LatestRelease/${MINIFORGE_SCRIPT}" && \
#             echo "=== Downloading Miniforge from Tsinghua mirror ===" && \
#         wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${MINIFORGE_URL}" -O "${MINIFORGE_SCRIPT}" && \
#         echo "=== Miniforge download completed ==="; \
#     if [ ! -f "${MINIFORGE_SCRIPT}" ]; then \
#         echo "=== Downloading Miniforge from Tsinghua mirror ===" && \
#         wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${MINIFORGE_URL}" -O "${MINIFORGE_SCRIPT}" && \
#         echo "=== Miniforge download completed ==="; \
#     else \
#         echo "=== Using cached Miniforge ==="; \
#     fi && \
#     # Set proper permissions for the downloaded file
#     chmod 755 "${MINIFORGE_SCRIPT}" && \
#     echo "=== Miniforge download and permission setup completed ==="

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
    ISAAC_ZIP="isaac-sim-standalone-5.0.0-linux-x86_64.zip" && \
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
    echo "export ISAACSIM_PYTHON_EXE=\"\${ISAACSIM_PATH}/python.sh\"" >> /home/${USERNAME}/.bashrc

# Install Miniforge (using previously downloaded file)
RUN cd /home/${USERNAME} && \
    echo "=== Downloading Miniforge ===" && \
    MINIFORGE_SCRIPT="Miniforge3-$(uname)-$(uname -m).sh" && \
    MINIFORGE_URL="https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge/LatestRelease/${MINIFORGE_SCRIPT}" && \
    wget --progress=bar:force:noscroll --timeout=30 --tries=3 "${MINIFORGE_URL}" -O "${MINIFORGE_SCRIPT}" && \
    echo "=== Miniforge download completed ===" && \
    echo "=== Installing Miniforge as ${USERNAME} ===" && \
    # Install Miniforge
    bash "/home/${USERNAME}/${MINIFORGE_SCRIPT}" -b -p "${HOME}/conda" && \
    bash -c "source '${HOME}/conda/etc/profile.d/conda.sh' && source '${HOME}/conda/etc/profile.d/mamba.sh' && conda activate" && \
    /home/${USERNAME}/conda/bin/conda init && bash /home/${USERNAME}/.bashrc && . /home/${USERNAME}/.bashrc && \
    # Clean up the copied installer
    rm "/home/${USERNAME}/${MINIFORGE_SCRIPT}" && \
    echo "=== Miniforge installation completed ==="

# # Manually add conda initialization to .bashrc
# RUN echo "# >>> conda initialize >>>" >> /home/${USERNAME}/.bashrc && \
#     echo "# !! Contents within this block are managed by 'conda init' !!" >> /home/${USERNAME}/.bashrc && \
#     echo "__conda_setup=\"\$('/home/${USERNAME}/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"" >> /home/${USERNAME}/.bashrc && \
#     echo "if [ \$? -eq 0 ]; then" >> /home/${USERNAME}/.bashrc && \
#     echo "    eval \"\$__conda_setup\"" >> /home/${USERNAME}/.bashrc && \
#     echo "else" >> /home/${USERNAME}/.bashrc && \
#     echo "    if [ -f \"/home/${USERNAME}/conda/etc/profile.d/conda.sh\" ]; then" >> /home/${USERNAME}/.bashrc && \
#     echo "        . \"/home/${USERNAME}/conda/etc/profile.d/conda.sh\"" >> /home/${USERNAME}/.bashrc && \
#     echo "    else" >> /home/${USERNAME}/.bashrc && \
#     echo "        export PATH=\"/home/${USERNAME}/conda/bin:\$PATH\"" >> /home/${USERNAME}/.bashrc && \
#     echo "    fi" >> /home/${USERNAME}/.bashrc && \
#     echo "fi" >> /home/${USERNAME}/.bashrc && \
#     echo "unset __conda_setup" >> /home/${USERNAME}/.bashrc && \
#     echo "# <<< conda initialize <<<" >> /home/${USERNAME}/.bashrc

# # Initialize conda properly for shell usage (following official miniforge documentation)
# RUN echo "=== Initializing conda for shell ===" && \
#     "${HOME}/conda/bin/conda" init bash && \
#     echo "=== Adding conda paths to .bashrc ===" && \
#     echo "# >>> conda initialize >>>" >> /home/${USERNAME}/.bashrc && \
#     echo "# !! Contents within this block are managed by 'conda init' !!" >> /home/${USERNAME}/.bashrc && \
#     echo "__conda_setup=\"\$('${HOME}/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"" >> /home/${USERNAME}/.bashrc && \
#     echo "if [ \$? -eq 0 ]; then" >> /home/${USERNAME}/.bashrc && \
#     echo "    eval \"\$__conda_setup\"" >> /home/${USERNAME}/.bashrc && \
#     echo "else" >> /home/${USERNAME}/.bashrc && \
#     echo "    if [ -f \"${HOME}/conda/etc/profile.d/conda.sh\" ]; then" >> /home/${USERNAME}/.bashrc && \
#     echo "        . \"${HOME}/conda/etc/profile.d/conda.sh\"" >> /home/${USERNAME}/.bashrc && \
#     echo "    else" >> /home/${USERNAME}/.bashrc && \
#     echo "        export PATH=\"${HOME}/conda/bin:\$PATH\"" >> /home/${USERNAME}/.bashrc && \
#     echo "    fi" >> /home/${USERNAME}/.bashrc && \
#     echo "fi" >> /home/${USERNAME}/.bashrc && \
#     echo "unset __conda_setup" >> /home/${USERNAME}/.bashrc && \
#     echo "# <<< conda initialize <<<" >> /home/${USERNAME}/.bashrc

# Configure conda with Tsinghua mirror and settings
RUN echo "=== Configuring conda with mirrors ===" && \
    # Create .condarc file with Tsinghua mirror configuration
    echo "channel_alias: https://mirrors.tuna.tsinghua.edu.cn/anaconda" > /home/${USERNAME}/.condarc && \
    echo "channels:" >> /home/${USERNAME}/.condarc && \
    echo "  - defaults" >> /home/${USERNAME}/.condarc && \
    echo "default_channels:" >> /home/${USERNAME}/.condarc && \
    echo "  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main" >> /home/${USERNAME}/.condarc && \
    echo "  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free" >> /home/${USERNAME}/.condarc && \
    echo "  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r" >> /home/${USERNAME}/.condarc && \
    echo "  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/pro" >> /home/${USERNAME}/.condarc && \
    echo "  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2" >> /home/${USERNAME}/.condarc && \
    echo "custom_channels:" >> /home/${USERNAME}/.condarc && \
    echo "  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "  msys2: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "  bioconda: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "  menpo: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "  simpleitk: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud" >> /home/${USERNAME}/.condarc && \
    echo "show_channel_urls: True" >> /home/${USERNAME}/.condarc && \
    echo "ssl_verify: False" >> /home/${USERNAME}/.condarc && \
    echo "remote_connect_timeout_secs: 30" >> /home/${USERNAME}/.condarc && \
    echo "remote_read_timeout_secs: 120" >> /home/${USERNAME}/.condarc && \
    echo "remote_max_retries: 5" >> /home/${USERNAME}/.condarc && \
    echo "always_yes: True" >> /home/${USERNAME}/.condarc


# ENV conda /home/${USERNAME}/conda/bin/conda
# ENV bashrc /home/${USERNAME}/.bashrc
# SHELL ["/bin/bash", "--login", "-c"]

# # Verify conda installation works with new shell initialization
# RUN echo "=== Verifying conda installation ===" && \
#     $conda init && . $bashrc && \
#     # conda activate && \
#     conda activate && \
#     echo "=== Miniforge installation and configuration completed ==="


# Clone Isaac Lab repository (as per official documentation)
RUN cd /home/${USERNAME} && \
    echo "=== Cloning Isaac Lab repository ===" && \
    git clone https://gitee.com/xiaohaizhu/IsaacLab.git && \
    cd /home/${USERNAME}/IsaacLab && \
    git checkout v2.2.0 && \
    echo "=== Isaac Lab repository cloned ==="

# Create Isaac Sim symbolic link (as per official documentation)
RUN cd /home/${USERNAME}/IsaacLab && \
    echo "=== Creating Isaac Sim symbolic link ===" && \
    ln -s /home/${USERNAME}/isaacsim _isaac_sim && \
    echo "=== Isaac Sim symbolic link created ==="

# # Create Conda env for isaac lab with proper shell initialization
# RUN cd /home/${USERNAME}/IsaacLab && \
#     echo "=== Creating conda env for isaac lab ===" && \
#     bash -l -c "source '${HOME}/conda/etc/profile.d/conda.sh' && source '${HOME}/conda/etc/profile.d/mamba.sh' && conda activate && ./isaaclab.sh --conda env_isaaclab" && \
#     echo "=== Complete conda env creation ==="

# SHELL ["conda", "run", "-n", "env_isaaclab", "/bin/bash", "-c"]

# ENV PATH /home/${USERNAME}/conda/bin:$PATH

# # Verify conda environment was created successfully
# RUN echo "=== Verifying conda environment setup ===" && \
#     conda init && \
#     # conda activate env_isaaclab && \
#     pip install xgboost && \
#     echo "=== Conda environment verification completed ==="

# # Install Isaac Lab extensions and dependencies (as per official documentation)
# RUN cd /home/${USERNAME}/IsaacLab && \
#     echo "=== Installing Isaac Lab extensions ===" && \
#     conda init bash && \ 
#     . /home/${USERNAME}/.bashrc && \
#     ./isaaclab.sh --conda env_isaaclab

# ENV PATH /home/${USERNAME}/conda/envs/env_isaaclab/bin:$PATH

# SHELL ["conda", "run", "-n", "env_isaaclab", "/bin/bash", "-c"]

# RUN cd /home/${USERNAME}/IsaacLab && \     
#     export TERM=xterm && \
#     export DEBIAN_FRONTEND=noninteractive && \
#     # conda init && \ 
#     # . /home/${USERNAME}/.bashrc && \
#     # conda activate env_isaaclab && \
#     python -m pip install --upgrade pip && \
#     ./isaaclab.sh --install && \
#     # bash -l -c "source '${HOME}/conda/etc/profile.d/conda.sh' && source '${HOME}/conda/etc/profile.d/mamba.sh' && conda activate env_isaaclab && export TERM=xterm && export DEBIAN_FRONTEND=noninteractive && python -m pip install --upgrade pip && ./isaaclab.sh --install" && \
#     echo "=== Isaac Lab installation completed ==="

# # Install cyclonedx dependency for unitree_sdk2_python
# RUN cd /home/${USERNAME} && \
#     echo "=== Installing cyclonedx dependencies ===" && \
#     git clone https://gitee.com/xiaohaizhu/cyclonedds.git -b releases/0.10.x && \
#     cd cyclonedds && mkdir build install && cd build && \
#     cmake .. -DCMAKE_INSTALL_PREFIX=../install && \
#     cmake --build . --target install && \
#     echo "=== cyclonedx build completed ==="

# # Install unitree python sdk
# RUN cd /home/${USERNAME} && \
#     echo "=== Downloading unitree sdk ===" && \
#     git clone https://gitee.com/xiaohaizhu/unitree_sdk2_python.git && \
#     echo "=== unitree downloaded sdk ==="

# RUN cd /home/${USERNAME}/unitree_sdk2_python && \
#     echo "=== Installing unitree sdk ===" && \
#     export CYCLONEDDS_HOME="/home/${USERNAME}/cyclonedds/install" && \
#     bash -l -c "source '${HOME}/conda/etc/profile.d/conda.sh' && source '${HOME}/conda/etc/profile.d/mamba.sh' && conda activate env_isaaclab && pip install -e ." && \
#     echo "=== unitree sdk installation completed ==="

# # Install unitree python sdk
# RUN cd /home/${USERNAME} && \
#     echo "=== Downloading unitree sdim isaaclab ===" && \
#     git clone https://gitee.com/xiaohaizhu/unitree_sim_isaaclab.git && \
#     echo "=== unitree sdim isaaclab downloaded sdk ==="

# RUN cd /home/${USERNAME}/unitree_sim_isaaclab && \
#     echo "=== Installing unitree sdim isaaclab ===" && \
#     bash -l -c "source '${HOME}/conda/etc/profile.d/conda.sh' && source '${HOME}/conda/etc/profile.d/mamba.sh' && conda activate env_isaaclab && pip install -r requirements.txt" && \
#     echo "=== unitree sdim isaaclab installation completed ==="

########################################################################################################################
# SSH Setup
########################################################################################################################

# USER root

# # Install SSH server
# RUN apt update && \
#     apt install -y openssh-server

# # Configure SSH server
# RUN echo 'X11Forwarding yes' >> /etc/ssh/sshd_config && \
#     echo 'X11UseLocalhost no' >> /etc/ssh/sshd_config && \
#     sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
#     sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
#     sed -i 's/#Port 22/Port 2220/' /etc/ssh/sshd_config

# # Add SSHD entrypoint script
# COPY ${RESOURCES_DIR}/sshd_entrypoint.sh /usr/local/bin/sshd_entrypoint.sh

# RUN chown ${USERNAME}:${USERNAME} /usr/local/bin/sshd_entrypoint.sh && \
#     chmod +x /usr/local/bin/sshd_entrypoint.sh && \
#     mkdir -p /run/sshd && \
#     echo "" >> /etc/supervisord.conf && \
#     echo "# sshd entrypoint script" >> /etc/supervisord.conf && \
#     echo "[program:sshd]" >> /etc/supervisord.conf && \
#     echo "user=${USERNAME}" >> /etc/supervisord.conf && \
#     echo "command=/usr/local/bin/sshd_entrypoint.sh" >> /etc/supervisord.conf && \
#     echo "autostart=true" >> /etc/supervisord.conf && \
#     echo "autorestart=true" >> /etc/supervisord.conf && \
#     echo "startretries=3" >> /etc/supervisord.conf && \
#     echo "stderr_logfile=/tmp/sshd.err.log" >> /etc/supervisord.conf && \
#     echo "stdout_logfile=/tmp/sshd.out.log" >> /etc/supervisord.conf && \
#     echo "" >> /etc/supervisord.conf
# EXPOSE 2220

########################################################################################################################
# Cleanup
########################################################################################################################

# Switch back to root for system configuration
USER root

# Clean up cache but preserve Isaac Sim and Miniforge caches
RUN apt autoclean && apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* && \
    # Keep Isaac Sim cache and Miniforge cache directories, remove everything else in /tmp
    find /tmp -mindepth 1 -maxdepth 1 ! -name 'isaac_cache' ! -name 'miniforge_cache' -exec rm -rf {} + 2>/dev/null || true

# Pitch to avoid removing all content in ~/.cache
RUN sed -i "s|sudo rm -rf /tmp/.X\* ~/.cache|sudo rm -rf /tmp/.X* \&\& sudo find ~/.cache -mindepth 1 -maxdepth 1 ! -name 'pip' ! -name 'ov' ! -name 'uv' ! -name 'packman' -exec rm -rf {} +|g" /etc/entrypoint.sh

# Restore User
USER ${USERNAME}