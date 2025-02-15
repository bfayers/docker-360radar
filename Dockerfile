FROM debian:stable-slim

ENV BEASTPORT=30005 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    URL_MLAT_CLIENT_LFW="http://radar.lowflyingwales.co.uk/files/rpi/python3.11/64-bit/lfw-mlat-client-rx3_0.0.1_all.deb" \
    URL_MLAT_CLIENT_360R="http://radar.lowflyingwales.co.uk/files/rpi/python3.11/64-bit/360r-mlat-test-svr1_0.0.1_all.deb" \
    S6OVERLAY_VERSION="v2.2.0.3" \
    S6OVERLAY_ARCH="armhf"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update --allow-unauthenticated --allow-insecure-repositories
RUN apt-get install --allow-unauthenticated --no-install-recommends -y \
        binutils \
        build-essential \
        ca-certificates \
        curl \
        file \
        git \
        gnupg2 \
        python3 \
        python3-dev \
        python3-setuptools \
        socat \
        xz-utils

RUN git clone https://github.com/mutability/mlat-client.git /src/mlat-client && \
    pushd /src/mlat-client && \
    BRANCH_MLAT_CLIENT="$(git tag --sort="-creatordate" | head -1)" && \
    git checkout "$BRANCH_MLAT_CLIENT" && \
    ./setup.py install && \
    popd

# Deploy 360Radar specific files (Scotland, Northern Ireland and Eire only)
RUN mkdir -p /opt/mlat-client-lfw && \
    pushd /opt/mlat-client-lfw && \
    curl --location -o lfw-mlat-client-rx3_all.deb "$URL_MLAT_CLIENT_LFW" && \
    ar x ./lfw-mlat-client-rx3_all.deb && \
    tar xvf data.tar.xz && \
    tar xvf control.tar.xz && \
    popd && \
    # Deploy 360Radar specific files (SE England, SW England, Wales, Midlands, Northern England)
    mkdir -p /opt/mlat-client-360r && \
    pushd /opt/mlat-client-360r && \
    curl --location -o 360r-mlat-test-svr1_all.deb "$URL_MLAT_CLIENT_360R" && \
    ar x ./360r-mlat-test-svr1_all.deb && \
    tar xvf data.tar.xz && \
    tar xvf control.tar.xz && \
    popd && \
    # Get the supplied MLAT server & port for (Scotland, Northern Ireland and Eire only)
    grep -m 1 -A 999 'Template: lfw-mlat-client-rx3/server-hostport' /opt/mlat-client-lfw/templates | \
        grep -B 999 -m 1 'Default:' | \
        grep 'Default:' | \
        cut -d ':' -f 2- | \
        tr -d " " > /mlat_serverport_lfw && \
    # Get the supplied MLAT server & port for (SE England, SW England, Wales, Midlands, Northern England)
    grep -m 1 -A 999 'Template: 360r-mlat-test-svr1/server-hostport' /opt/mlat-client-360r/templates | \
        grep -B 999 -m 1 'Default:' | \
        grep 'Default:' | \
        cut -d ':' -f 2- | \
        tr -d " " > /mlat_serverport_360r

# RUN curl -s --location --output /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"

# RUN tar -hxzf /tmp/s6-overlay.tar.gz -C /

RUN apt-get remove -y \
        binutils \
        build-essential \
        curl \
        file \
        git \
        gnupg2 \
        python3-dev \
        xz-utils \
        && \
    apt-get autoremove -y && \
    rm -rf /tmp/* /src /var/lib/apt/lists/* && \
    # Record versions
    echo "mlat-client $BRANCH_MLAT_CLIENT" > /VERSIONS && \
    cat /VERSIONS

# Copy config files
COPY etc/ /etc/

# Entrypoint is s6-overlay
ENTRYPOINT [ "/etc/services.d/mlat-client/run" ]
