#!/usr/bin/env bash

set -e

if ! which git &> /dev/null ; then
  echo "git is required."
  exit 1
fi

if ! which dch &> /dev/null ; then
  echo "debchange is required."
  exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1 ; then
  echo "Current working directory is not a git repository."
  exit 1
fi

if ! [[ -f "debian/control" ]] ; then
  echo "Current working directory is not a debian package root. [debian/control] file is missing."
  exit 1
fi

DIST=jammy
PKG_NAME=$(awk '/^Package:/ { print $2 }' debian/control)
LAST_TAG=$(git tag -l | sort -V | tail -1)

function help(){
  cat <<Here

git-dch.sh
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
      TAG="${OPTARG}"
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

# appends debian change log
appendChangelog () {
  local version=$1
  local range=$2
  local entry
  local cmd

  cmd="dch $([[ -e 'debian/changelog' ]] || echo '--create') --distribution $DIST --package $PKG_NAME --newversion $version-1 --controlmaint"
  git log --pretty=tformat:'%s' $range | while read entry; do
    $cmd $entry
    cmd="dch --append --controlmaint"
  done
}

# check tag name
if [[ "$TAG" != "" ]] ; then
  if ! [[ "$TAG" =~ ^v?[0-9]+(\.[0-9]+){0,2}$ ]] ; then
    echo "[$TAG] is not a valid tag name."
    exit 1
  fi
  VERSION="${TAG#v}"
  if [[ "$LAST_TAG" != "$TAG" ]] ; then
    RANGE="$([[ "$LAST_TAG" != "" ]] && echo "$LAST_TAG.." || echo "")HEAD"
  fi
else
  if [[ "$LAST_TAG" != "" ]] && [[ "$LAST_TAG" =~ ^v?[0-9]+(\.[0-9]+){0,2}$ ]] ; then
    VERSION_PARTS=(${LAST_TAG//./ })
    VERSION_PARTS[-1]=$((${VERSION_PARTS[-1]}+1))
    TAG="$(IFS=. ; echo "${VERSION_PARTS[*]}")"
    RANGE="$LAST_TAG..HEAD"
  else
    TAG="0.0.1"
    RANGE="HEAD"
  fi
  VERSION="${TAG#v}~n$(date +%s)"
fi

# generate changelog
rm debian/changelog 2>/dev/null || true
git tag -l | sort -V | while read CUR_TAG; do
  appendChangelog ${CUR_TAG#v} "$PREV_TAG$CUR_TAG"
  PREV_TAG="$CUR_TAG.."
done
if [[ "$RANGE" != "" ]] && [[ "$(git log $RANGE | wc -l)" != 0 ]] ; then
  appendChangelog $VERSION $RANGE
fi