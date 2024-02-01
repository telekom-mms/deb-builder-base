#!/usr/bin/env bash

set -e

if ! which git &> /dev/null ; then
  echo "git is required."
  exit 1
fi

if ! which ifne &> /dev/null ; then
  echo "ifne (from moreutils) is required."
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

# Helper function for sort_by_dpkg_version
function dpkg_version_isgreater() {
  local first="${1}"
  local than_second="${2}"
  if dpkg --compare-versions "${first}" gt "${than_second}"; then
    return 0
  fi
  return 1
}

# Bubble sort the array of lines, using dpkg_version_isgreater as helper function
# https://www.geeksforgeeks.org/sorting-the-array-in-bash-using-bubble-sort/
# https://github.com/mschmitt/dpkg-sort-versions
function sort_by_dpkg_version() {
  declare -a data
  while read -r line; do
    data+=("${line}")
  done

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

PKG_NAME=$(awk '/^Package:/ { print $2 }' debian/control)

function help(){
  cat <<Here

git-dch.sh
  -d <distribution> (noble, ...)
  -t <tag>
  -p <tag-pattern, e.g. 2404-*>

Here
  exit 1
}

# Default dist in case none is specified on command line
DIST=noble
# Default tag pattern
PATTERN='*'

while getopts ':d:p:t:' option
do
  case "${option}" in
    'd')
      DIST="${OPTARG}"
      ;;
    't')
      TAG="${OPTARG}"
      ;;
    'p')
      PATTERN="${OPTARG}"
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
  git log --pretty=tformat:'%s' "${range}" | ifne -n echo "No changes." | while read -r entry; do
    $cmd "${entry}"
    cmd="dch --append --controlmaint"
  done
}

validateVersion () {
	local got_version="${1}"
	# Check if version is a valid version for Debian in general
	if ! dpkg --validate-version "${got_version}"
	then
		printf "%s: Faild dpkg --validate-version\n" "${got_version}" >&2
		return 1
	fi
	return 0
}

LAST_TAG="$(git tag --list "${PATTERN}" | sort_by_dpkg_version | tail -1)"

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
    # The first commit needs a tag, otherwise no prerelease version can be derived
    echo "No tag for commit and no previous tag to derive prerelease from. Aborting."
    exit 1
  fi
  VERSION="${TAG}+n$(date +%s)"
fi

# generate changelog
rm -v -f debian/changelog
# Merge historic changelog if it exists
if [[ -s debian/changelog.legacy ]]
then
  cp -v debian/changelog.legacy debian/changelog
  printf -- "--- Legacy Changelog:\n"
  cat debian/changelog
  printf -- "--- ---\n"
else
  printf "Info: No debian/changelog.legacy in repository."
fi
git tag --list "${PATTERN}" | sort_by_dpkg_version | while read -r CUR_TAG; do
  appendChangelog "${CUR_TAG#v}" "$PREV_TAG$CUR_TAG"
  PREV_TAG="$CUR_TAG.."
done
if [[ "$RANGE" != "" ]] && [[ "$(git log "$RANGE" | wc -l)" != 0 ]] ; then
  appendChangelog "$VERSION" "$RANGE"
fi

printf -- "--- Generated Changelog:\n"
cat debian/changelog
printf -- "--- ---\n"
