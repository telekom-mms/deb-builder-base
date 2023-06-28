# example-package
This folder holds a example of a debian package, which can be build locally with docker without debian packaging tool chain and automatic changelog creation.

For a new package copy all contents of example_package folder and replace all occurrences starting `example-package` with package name or package related config, data, description .

To build package run:
```bash
$ ./docker.sh
```