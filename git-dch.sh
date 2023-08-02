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

function dpkg_version_isgreater() {
  local first="${1}"
  local than_second="${2}"
  if dpkg --compare-versions "${first}" gt "${than_second}"; then
    return 0
  fi
  return 1
}

function sort_by_dpkg_version() {
  declare -a data
  while read -r line; do
    data+=("${line}")
  done

  # Bubble sort the array of lines
  local len=${#data[@]}
  for ((i = 0; i<len; i++)); do
    for ((j = 0; j<len-i-1; j++)); do
      if dpkg_version_isgreater "${data[j]}" "${data[$((j+1))]}"; then
        local swapval="${data[j]}"
        data[$j]="${data[$((j+1))]}"
        data[$((j+1))]="${swapval}"
      fi
    done
  done

  for ((i = 0; i<len; i++)); do
    printf "%s\n" "${data[i]}"
  done
}

DIST=jammy
PKG_NAME=$(awk '/^Package:/ { print $2 }' debian/control)
LAST_TAG=$(git tag -l | sort_by_dpkg_version | tail -1)

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

validateVersion () {
	local got_version="${1}"
	# Check if remaining version, without the leading v, is a valid version for Debian
	if ! dpkg --validate-version "${got_version}"
	then
		printf "%s: Faild dpkg --validate-version\n" "${got_version}" >&2
		return 1
	fi
	return 0
}

# check tag name
if [[ "$TAG" != "" ]] ; then
  # This is a tagged version
  if ! validateVersion "$TAG" ; then
    echo "[$TAG] is not a valid tag name."
    exit 1
  fi
  VERSION="${TAG}"
  if [[ "$LAST_TAG" != "$TAG" ]] ; then
    RANGE="$([[ "$LAST_TAG" != "" ]] && echo "$LAST_TAG.." || echo "")HEAD"
  fi
else
  # This is not a tagged version - Derive prerelease version from current time
  if [[ "$LAST_TAG" != "" ]] && validateVersion "$LAST_TAG"; then
    TAG="${LAST_TAG}"
    RANGE="$LAST_TAG..HEAD"
  else
    # Fallback if no previous tagged version available
    TAG="0.0.1"
    RANGE="HEAD"
  fi
  VERSION="${TAG}+n$(date +%s)"
fi

# generate changelog
rm debian/changelog 2>/dev/null || true
# Merge historic changelog if it exists
if [[ -s debian/changelog.legacy ]]
then
	cp debian/changelog.legacy debian/changelog
fi
git tag -l | sort_by_dpkg_version | while read CUR_TAG; do
  appendChangelog ${CUR_TAG#v} "$PREV_TAG$CUR_TAG"
  PREV_TAG="$CUR_TAG.."
done
if [[ "$RANGE" != "" ]] && [[ "$(git log $RANGE | wc -l)" != 0 ]] ; then
  appendChangelog $VERSION $RANGE
fi
