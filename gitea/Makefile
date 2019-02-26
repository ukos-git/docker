NAME       := ukos/gitea
LATEST     := ${NAME}:latest
LINKDIR    :=

default: build-docker

build-docker:
	docker build -t ${LATEST} .

shell: build-docker
	docker run --rm -it ${LINKDIR} ${LATEST} /bin/bash

run: build-docker
	docker run --rm ${LINKDIR} ${LATEST}
