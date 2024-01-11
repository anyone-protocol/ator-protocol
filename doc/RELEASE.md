# Anon Release

## Installing Debian/Ubuntu Package

1. Download package. Package name depends on your system OS and CPU architecture. You can find full link to desired package in the release assets section below. 
```sh
wget https://github.com/ATOR-Development/ator-protocol/releases/download/<version>/<package_name>
```

2. Update repository information
```sh
apt-get -y update
```

3. Install package using apt
```sh
apt-get -y install ./anon_*.deb
```

## Uninstalling Debian/Ubuntu Package (but keeping configuration)

```sh
apt-get -y remove anon
```

## Completely Uninstalling Debian/Ubuntu Package

```sh
apt-get -y purge anon
```
