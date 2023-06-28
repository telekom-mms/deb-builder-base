# deb-builder-base
Builds a container image to build debian packages.

## Usage
The provided docker image can be used for github, gitlab workflows/pipelines: `ghcr.io/telekom-mms/deb-builder-base:jammy`

## Build helper scripts

### Local docker build
If you want to build a debian package locally without installing all debian packages, you can use the provided `docker-build.sh` script. It is necessary to create a `Makefile` with the goals package_build and package_clean:
```make
package_build: package_clean
	debuild -i -uc -us -b

package_clean:
	-rm -Rf debian/.debhelper
	-rm -Rf debian/$(firstword $(subst _, ,$(lastword $(subst /, ,$(shell pwd)))))*
	-rm debian/debhelper-build-stamp debian/files
	-rm ../$(lastword $(subst /, ,$(shell pwd)))?*
```

### Generate complete changelog from git log
If you want to generate the whole changelog file from git log, you can use `git-dch.sh` script. Add a goal to the `Makefile` or call it otherwise.
```make
package_build: package_clean generate_changelog
	debuild -i -uc -us -b

generate_changelog:
	curl -sL https://raw.githubusercontent.com/telekom-mms/deb-builder-base/main/git-dch.sh | /usr/bin/bash -s $(TAG)

package_clean:
	-rm -Rf debian/.debhelper
	-rm -Rf debian/$(firstword $(subst _, ,$(lastword $(subst /, ,$(shell pwd)))))*
	-rm debian/debhelper-build-stamp debian/files
	-rm ../$(lastword $(subst /, ,$(shell pwd)))?*
```
To call `git-dch.sh` within `Makefile` and set a version/tag name use: `make package_build TAG='-t 1.0.0'`

### Example package
Under [example-package](/example-package/) you can find a complete example for a debian package, which can be build with docker and has auto generated changelog included.