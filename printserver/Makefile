NAME       := ukos/printserver-postprocess
LATEST     := ${NAME}:latest
LOCAL_DIR  := ${HOME}/tank/programs/printserver
DOCKER_DIR := /printserver/data
LINKDIR    := -v ${LOCAL_DIR}:${DOCKER_DIR}

default: build-docker

build-docker:
	docker build -t ${LATEST} .

push: test
	git push
	docker push ukos/printserver-postprocess:latest

shell: build-docker
	docker run --rm -it --entrypoint /bin/bash ${LINKDIR} ${LATEST}

test: build-docker
	cd ${LOCAL_DIR} && \
		git stash && \
		git checkout master && \
		git checkout -b unittest
	docker run --rm \
		--env PLUGIN_BASE_DIR=${DOCKER_DIR} \
		--env PLUGIN_INPUT_DIR=scan \
		--env PLUGIN_FILE_POOL=status \
		--env PLUGIN_FILE_FORMAT=pnm \
		--env PLUGIN_SCAN_DPI=72 \
		--env PLUGIN_VERBOSE=1 \
		${LINKDIR} ${LATEST}
	cd ${LOCAL_DIR} && \
		git reset --hard && \
		git clean -f && \
		git checkout master && \
		git branch -D unittest && \
		git stash pop || /bin/true
