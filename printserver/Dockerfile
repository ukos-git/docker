FROM debian:latest
MAINTAINER Matthias J. Kastner matthias@project-moby.net
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		bc \
		imagemagick \
		img2pdf \
		libtiff-tools \
		netpbm \
		python3-pip \
		pngtools \
		pngquant \
		tesseract-ocr tesseract-ocr-deu \
		unpaper

# install ocrmypdf from pip
RUN pip3 install ocrmypdf

# install JBIG2 encoder
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get install --assume-yes \
		automake \
		build-essential \
		ca-certificates \
		git \
		libleptonica-dev \
		libtool \
		zlib1g-dev
RUN mkdir /printserver
COPY postprocess.sh filepool.sh /printserver/
WORKDIR /printserver
RUN git clone https://github.com/agl/jbig2enc
WORKDIR /printserver/jbig2enc
RUN /bin/sh autogen.sh
RUN ./configure && make
RUN make install

RUN apt-get clean
WORKDIR /printserver
ENTRYPOINT /bin/bash /printserver/postprocess.sh
