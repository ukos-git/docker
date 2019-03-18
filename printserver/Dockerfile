FROM debian:buster
MAINTAINER Matthias J. Kastner matthias@project-moby.net

RUN mkdir /printserver
WORKDIR /printserver

# install JBIG2 encoder
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		automake \
		build-essential \
		ca-certificates \
		git \
		libleptonica-dev \
		libtool \
		zlib1g-dev
RUN git clone https://github.com/agl/jbig2enc
WORKDIR /printserver/jbig2enc
RUN /bin/sh autogen.sh
RUN ./configure && make
RUN make install
WORKDIR /printserver

# install fixed ocrmypdf from pip
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		ghostscript \
		libleptonica-dev \
		python3-pip \
		qpdf \
		tesseract-ocr tesseract-ocr-deu \
		unpaper && \
	apt-get clean
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
RUN pip3 install ocrmypdf

# install postprocess.sh script dependencies
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		bc \
		exactimage \
		imagemagick \
		img2pdf \
		libtiff-tools \
		netpbm \
		pngtools \
		pngquant \
		tesseract-ocr tesseract-ocr-deu \
		unpaper && \
	apt-get clean

COPY postprocess.sh filepool.sh /printserver/
ENTRYPOINT /bin/bash /printserver/postprocess.sh
