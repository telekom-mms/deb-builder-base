#!/usr/bin/bash
DIR=$(basename $(pwd))
cd .. && docker run --user=$UID --rm -v ./:/work ghcr.io/telekom-mms/deb-builder-base:jammy /usr/bin/bash -c "cd /work/$DIR && make package_build && cp ../*.deb . && make package_clean"
