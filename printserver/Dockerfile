FROM debian:latest
MAINTAINER Matthias J. Kastner matthias@project-moby.net
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update && \
	apt-get upgrade --assume-yes && \
	apt-get install --assume-yes --no-install-recommends \
		bc \
		imagemagick \
		img2pdf \
		libtiff-tools \
		netpbm \
		ocrmypdf \
		pngtools \
		tesseract-ocr tesseract-ocr-deu \
		unpaper && \
	apt-get clean
RUN mkdir /printserver
COPY postprocess.sh filepool.sh /printserver/
WORKDIR /printserver
ENTRYPOINT /bin/bash /printserver/postprocess.sh
