ARG IMAGE
FROM ${IMAGE}

RUN set -eu ; \
  export DEBIAN_FRONTEND=noninteractive ; \
  apt-get update -y && apt-get -y upgrade