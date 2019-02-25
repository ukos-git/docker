# docker

my public docker collection

## printserver-postprocess

Available settings variables and their standard settings:

```bash
    PLUGIN_VERBOSE=1
    PLUGIN_BASE_DIR="/printserver/data"
    PLUGIN_STORAGE="cache"
    PLUGIN_OUTPUT="_build"
    PLUGIN_DESTINATION="processed.pdf"
    PLUGIN_FILE_POOL=SnapScanLossless
    PLUGIN_FILE_FORMAT=tiff
    PLUGIN_SCAN_LANG=deu
```

Remove `PLUGIN_` prefix when configuring the `.drone.yml` plugin.

Example plugin:

```yml
kind: pipeline
name: default

clone:
  depth: 1

steps:
- name: postprocess
  image: ukos/printserver-postprocess
  settings:
    BASE_DIR: .
    STORAGE: cache
    DESTINATION: processed.pdf
    FILE_POOL: SnapScanLossless
    FILE_FORMAT: tiff
    SCAN_LANG: deu
    VERBOSE: 1
  when:
    branch:
      exclude:
      - master

trigger:
  branch:
    - scan/*
  event:
  - push
```

## iputils

This Package builds the current debian package of
[freerdp](https://github.com/FreeRDP/FreeRDP)

The only difference is that the deb files are built with the cflag `WITH_GFX_H264=on`. This enables h264 support.

### howto

The build is done from current freerdp master with ad docker file for the build
environment. The build can be easily done by calling the make file in the
source dir. The `*.deb` files are then placed unter the `deb/` sub directory:

```bash
git clone git@github.com:ukos-git/docker-freerdp.git
cd docker-freerdp
make
sudo dpkg -i deb/*.deb
```
