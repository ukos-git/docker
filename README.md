# Monorepo for various Dockerfiles

Instead of keeping every docker container in its separate repository, this is an attempt to use a single repository for all Dockerfiles. The containers are built and available on [docker hub](https://cloud.docker.com/u/ukos/)

# Image description

The images are located under subfolders in this repository.

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
