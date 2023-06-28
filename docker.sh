#!/usr/bin/bash

set -e

if ! which docker &> /dev/null ; then
  echo "docker is required."
  exit 1
fi

DIST=jammy

function help(){
  cat <<Here

docker.sh
  -d <distribution> (jammy, ...)
  -t <tag>

Here
  exit 1
}

while getopts ':d:t:' option
do
  case "${option}" in
    'd')
      DIST="${OPTARG}"
      ;;
    't')
      TAG="-t ${OPTARG}"
      ;;
    :)
      echo "-${OPTARG} requires an argument."
      help
      ;;
    *)
      help
      ;;
  esac
done

DIR=$(basename $(pwd))
cd ..
docker run --user=$UID --rm -v ./:/work "ghcr.io/telekom-mms/deb-builder-base:$DIST" /usr/bin/bash -c "cd /work/$DIR && make package_build DIST='-d $DIST' TAG='$TAG' && cp ../*.deb . && make package_clean"
