# Anon Release

## Debian/Ubuntu Package

### Install

1. Download package. Package name depends on your distributive version and CPU architecture. You can find full link to desired package file (`.deb`) in the release assets section below. 
```sh
wget https://github.com/anyone-protocol/ator-protocol/releases/download/<version>/<package_name>
```

2. Update repository information
```sh
apt-get -y update
```

3. Install package using apt
```sh
apt-get -y install ./anon_*.deb
```

### Start

After installation you can start Anon by executing `anon` command in terminal. To modify configuration edit the `/etc/anon/anonrc` file.

### Uninstall

```sh
apt-get -y remove anon
```

### Uninstall and remove configuration files

```sh
apt-get -y purge anon
```

## MacOS

### Install

MacOS version of Anon is portable, you can install it by downloading `.zip` archive from the release assets section below and extracting files from it. Make sure you download right archive for your system:

- for Intel: `amd64`
- for Apple Silicon: `arm64`

### Start

1. Create `anonrc` file in the directory with extracted files.
2. Open terminal in directory with extracted files.
3. Start Anon by typing `./anon -f anonrc` in terminal.

### Uninstall

To uninstall simply remove downloaded files.

## Windows

Windows version of Anon is portable, you can install it by downloading `.zip` archive from the release assets section below and extracting files from it.

### Start

1. Create `anonrc` file in the folder with extracted files.
2. Open PowerShell in directory with extracted files.
3. Start Anon by typing `./anon -f anonrc` in PowerShell.

### Uninstall

To uninstall simply remove downloaded files.