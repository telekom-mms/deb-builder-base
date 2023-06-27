FROM ubuntu:jammy

RUN set -eu ; \
  export DEBIAN_FRONTEND=noninteractive ; \
  apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install --no-install-recommends -y \
  sudo \
  git \
  curl \
  jq \
  ca-certificates \
  software-properties-common \
  build-essential \
  debhelper \
  devscripts \
  libdistro-info-perl \
  libpcsclite1 \
  pandoc \
  moreutils