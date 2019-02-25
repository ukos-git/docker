NAME      := ukos/seafile-sync
LATEST    := ${NAME}:latest

default: build-docker

build-docker:
	docker build -t ${LATEST} .

shell: build-docker
	docker run --rm -it ${LATEST} /bin/bash
