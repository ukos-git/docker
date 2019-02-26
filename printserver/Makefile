NAME       := ukos/printserver-postprocess
LATEST     := ${NAME}:latest
LOCAL_DIR  := ${HOME}/tank/programs/printserver
DOCKER_DIR := /printserver/data
LINKDIR    := -v ${LOCAL_DIR}:${DOCKER_DIR}

default: build-docker

build-docker:
	docker build -t ${LATEST} .

shell: build-docker
	docker run --rm -it ${LINKDIR} ${LATEST} /bin/bash

run: build-docker
	docker run --rm ${LINKDIR} ${LATEST}
