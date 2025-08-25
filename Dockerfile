# Stage 1: base - Minimal Ubuntu 24.04
FROM ubuntu:24.04 AS base

# 設定非互動模式
#（在 ubuntu 安裝過程中會跳出互動式選單要求設定，而安裝過程 docker 沒辦法回應系統就會導致 build 卡住）
ENV DEBIAN_FRONTEND=noninteractive 
ENV TZ=Asia/Taipei

# 更新 apt-get 並安裝 tzdata 來設定時區
RUN apt-get update && \
    # HTTPS 支援
    apt-get install -y --no-install-recommends tzdata ca-certificates && \
    # 設定時區
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    # 重新配置 tzdata
    dpkg-reconfigure --frontend noninteractive tzdata && \
    # 清理 apt cache
    rm -rf /var/lib/apt/lists/*

# 建立 non-root user (UID/GID 固定為 1000 名稱是 devuser)
ARG USERNAME=devuser
ARG UID=200
ARG GID=200
RUN set -eux; \
    if getent group ${GID}; then \
        EXIST_GROUP=$(getent group ${GID} | cut -d: -f1); \
    else \
        groupadd -g ${GID} ${USERNAME}; \
        EXIST_GROUP=${USERNAME}; \
    fi; \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

WORKDIR /home/${USERNAME}

# Stage 2: common_pkg_provider - Core CLI Tools
FROM ubuntu:24.04 AS common_pkg_provider

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Taipei

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    vim git gedit curl wget ca-certificates build-essential && \
    rm -rf /var/lib/apt/lists/*

# Stage 3: common_pkg_provider - Python & pip
FROM ubuntu:24.04 AS python_provider

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# Stage 4: common_pkg_provider - Miniconda
FROM ubuntu:24.04 AS conda_provider

# Docker 會自動傳 TARGETARCH
ARG TARGETARCH
ENV PATH=/opt/conda/bin:$PATH

# 依 CPU 架構下載 Miniconda 安裝 script
RUN apt-get update && apt-get install -y wget bzip2 ca-certificates && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        wget -qO miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh; \
    elif [ "$TARGETARCH" = "x86_64" ]; then \
        wget -qO miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh

# Stage 5: verilator_provider - Build Verilator
FROM ubuntu:24.04 AS verilator_provider

RUN apt-get update && apt-get install -y --no-install-recommends \
    git autoconf flex bison g++ make perl && \
    git clone https://github.com/verilator/verilator.git /tmp/verilator && \
    cd /tmp/verilator && git checkout stable && \
    autoconf && ./configure && make -j$(nproc) && make install && \
    rm -rf /var/lib/apt/lists/*

# Stage 6: systemc_provider - Build SystemC
FROM ubuntu:24.04 AS systemc_provider

ARG SYSTEMC_VERSION=2.3.4
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget tar g++ make && \
    wget -qO systemc.tar.gz https://github.com/accellera-official/systemc/archive/refs/tags/${SYSTEMC_VERSION}.tar.gz && \
    tar -xzf systemc.tar.gz && \
    cd systemc-${SYSTEMC_VERSION} && \
    mkdir build && cd build && \
    ../configure --prefix=/opt/systemc && \
    make -j$(nproc) && make install && \
    rm -rf /var/lib/apt/lists/* systemc.tar.gz systemc-${SYSTEMC_VERSION}

# Stage 7: final - Assemble Base + Providers
FROM base AS final

# 切回 root，才能 copy 安裝好的工具
USER root

# 複製 common tools
COPY --from=common_pkg_provider /usr/bin/vim /usr/bin/vim
COPY --from=common_pkg_provider /usr/bin/git /usr/bin/git
COPY --from=common_pkg_provider /usr/bin/curl /usr/bin/curl
COPY --from=common_pkg_provider /usr/bin/wget /usr/bin/wget
COPY --from=common_pkg_provider /usr/bin/gcc /usr/bin/gcc
COPY --from=common_pkg_provider /usr/bin/g++ /usr/bin/g++
COPY --from=common_pkg_provider /usr/bin/make /usr/bin/make

# 複製 Python
COPY --from=python_provider /usr/bin/python3 /usr/bin/python3
COPY --from=python_provider /usr/bin/pip3 /usr/bin/pip3
COPY --from=python_provider /usr/bin/python /usr/bin/python

# 複製 Miniconda
COPY --from=conda_provider /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH

# 複製 Verilator
COPY --from=verilator_provider /usr/local/bin/verilator /usr/local/bin/verilator

# 複製 SystemC
COPY --from=systemc_provider /opt/systemc /opt/systemc
RUN mkdir -p /etc/profile.d && \
    echo "export SYSTEMC_HOME=/opt/systemc" >> /etc/profile.d/systemc.sh && \
    echo "export LD_LIBRARY_PATH=/opt/systemc/lib-linux64:/opt/systemc/lib-linux:/opt/systemc/lib:\$LD_LIBRARY_PATH" >> /etc/profile.d/systemc.sh && \
    echo "export SYSTEMC_CXXFLAGS=-I\$SYSTEMC_HOME/include" >> /etc/profile.d/systemc.sh && \
    echo "export SYSTEMC_LDFLAGS=-L\$SYSTEMC_HOME/lib -lsystemc" >> /etc/profile.d/systemc.sh

# 切回非 root
USER devuser
WORKDIR /home/devuser

RUN echo "source /etc/profile.d/systemc.sh" >> /home/devuser/.bashrc

CMD ["/bin/bash", "-l"]