# Anon Release

## Installing Debian Package

Replace `<version>` with the Anon version and `<package_name>` with the name of the package that corresponds to your OS and CPU architecture.

1. Download package. You can find full link to any of the desired packages in the release assets section below.
```sh
curl -o anon.deb https://github.com/ATOR-Development/ator-protocol/releases/download/<version>/<package_name>
```
2. Install package using apt
```sh
apt-get -y install ./anon.deb
```
