FROM debian:sid
MAINTAINER Matthias J. Kastner matthias@project-moby.net

RUN mkdir /printserver

# install JBIG2 encoder
WORKDIR /printserver
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

# install fixed ocrmypdf from pip
WORKDIR /printserver
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		python3-chardet \
		python3-cffi \
		python3-img2pdf \
		python3-pip \
		python3-pikepdf \
		python3-reportlab \
		python3-ruffus \
		python3-setuptools \
		tar \
		wget && \
	apt-get clean
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
RUN wget https://github.com/jbarlow83/OCRmyPDF/archive/v9.2.0.tar.gz -O /printserver/ocrmypdf.tar.gz && \
	tar xzf ocrmypdf.tar.gz && \
	rm ocrmypdf.tar.gz
WORKDIR /printserver/OCRmyPDF-9.2.0
RUN pip3 install --no-cache-dir -r requirements/main.txt
RUN python3 setup.py install --prefix=/usr/local

# install postprocess.sh script dependencies
WORKDIR /printserver
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get install --assume-yes \
		bc \
		exactimage \
		ghostscript \
		imagemagick \
		img2pdf \
		libleptonica-dev \
		libtiff-tools \
		netpbm \
		parallel \
		pngtools \
		pngquant \
		qpdf \
		tesseract-ocr tesseract-ocr-deu \
		unpaper && \
	apt-get clean

COPY postprocess.sh filepool.sh /printserver/
ENTRYPOINT /bin/bash /printserver/postprocess.sh
