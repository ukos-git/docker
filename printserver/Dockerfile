FROM jbarlow83/ocrmypdf
MAINTAINER Matthias J. Kastner matthias@project-moby.net

# install postprocess.sh script dependencies
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

RUN mkdir /printserver
WORKDIR /printserver
COPY postprocess.sh filepool.sh /printserver/
ENTRYPOINT /bin/bash /printserver/postprocess.sh
