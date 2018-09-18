# vim: set noet ts=4
#
# simple makefile for building and tagging the docker container
#

NAME := ukos/freerdp:latest
LOCAL_ROOT := $$(git rev-parse --show-toplevel)

default: deb

requirements:
	docker -v
	groups | grep docker

build: requirements
	docker build -t ${NAME} .

deb: build
	docker run -it -v ${LOCAL_ROOT}/deb:/opt/deb ${NAME}

shell: build
	docker run -it --entrypoint /bin/bash -v ${LOCAL_ROOT}/deb:/opt/deb ${NAME}
