NAME       := ukos/printserver-postprocess
LATEST     := ${NAME}:latest
LOCAL_DIR  := ${HOME}/tank/programs/printserver
DOCKER_DIR := /printserver/data
LINKDIR    := -v ${LOCAL_DIR}:${DOCKER_DIR}

default: build-docker

build-docker:
	docker build -t ${LATEST} .

push: build-docker
	git push
	docker push ukos/printserver-postprocess:latest

shell: build-docker
	docker run --rm -it --entrypoint /bin/bash ${LINKDIR} ${LATEST}

run: build-docker
	docker run --rm ${LINKDIR} ${LATEST}
