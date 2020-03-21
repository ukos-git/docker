# vim: set noet ts=4
FROM ubuntu:bionic

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	ninja-build \
	build-essential \
	git-core \
	debhelper \
	cdbs \
	dpkg-dev \
	autotools-dev \
	cmake \
	pkg-config \
	xmlto \
	libssl-dev \
	docbook-xsl \
	xsltproc \
	libxkbfile-dev \
	libx11-dev \
	libwayland-dev \
	libxrandr-dev \
	libxi-dev \
	libxrender-dev \
	libxext-dev \
	libxinerama-dev \
	libxfixes-dev \
	libxcursor-dev \
	libxv-dev \
	libxdamage-dev \
	libxtst-dev \
	libcups2-dev \
	libpcsclite-dev \
	libasound2-dev \
	libpulse-dev \
	libjpeg-dev \
	libgsm1-dev \
	libusb-1.0-0-dev \
	libudev-dev \
	libdbus-glib-1-dev \
	uuid-dev \
	libxml2-dev \
	libgstreamer1.0-dev \
	libgstreamer-plugins-base1.0-dev \
	libcairo2-dev

# packages missing in docker image ubuntu:bionic
RUN apt-cache policy \
	libgstreamer0.10-0 \
	libgstreamer-plugins-base0.10-0

# required for master
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	libavutil-dev \
	libavcodec-dev \
	libavresample-dev

# optional unit testing and doxygen api
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	libcunit1-dev \
	libdirectfb-dev \
	xmlto \
	doxygen \
	libxtst-dev

# required package for dpkg-buildpackage
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
	fakeroot \
	dpkg-dev

# reduce image size
RUN apt-get clean

# go to opt
RUN mkdir -p /opt/freerdp

# clone main git repo
RUN git clone git://github.com/FreeRDP/FreeRDP.git /opt/freerdp
WORKDIR /opt/freerdp

# prepare for entrypoint
RUN ln -s packaging/deb/freerdp-nightly debian
RUN mkdir /opt/deb

# build the package with GFX support and move it to /opt/deb
ENTRYPOINT \
	sed --in-place 's/DEB_CMAKE_EXTRA_FLAGS := /\0 -DWITH_GFX_H264=ON /' debian/rules && \
	dpkg-buildpackage && \
	cp -f /opt/*.deb /opt/deb
