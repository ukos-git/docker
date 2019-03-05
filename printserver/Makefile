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
	cd ${LOCAL_DIR} && git diff --cached --exit-code
	cd ${LOCAL_DIR} && \
		git checkout master && \
		git branch -D unittest || /bin/true && \
		git checkout -b unittest

	docker run --rm \
		--env PLUGIN_BASE_DIR=${DOCKER_DIR} \
		--env PLUGIN_INPUT_DIR=unittest \
		--env PLUGIN_FILE_POOL=status \
		--env PLUGIN_FILE_FORMAT=pnm \
		--env PLUGIN_SCAN_DPI=72 \
		--env PLUGIN_VERBOSE=1 \
		${LINKDIR} ${LATEST}

	docker run --rm \
		--env PLUGIN_BASE_DIR=${DOCKER_DIR} \
		--env PLUGIN_INPUT_DIR=unittest \
		--env PLUGIN_FILE_POOL=status \
		--env PLUGIN_FILE_FORMAT=tiff \
		--env PLUGIN_SCAN_DPI=72 \
		--env PLUGIN_VERBOSE=1 \
		${LINKDIR} ${LATEST}

	cd ${LOCAL_DIR} && \
		git clean -f && \
		git reset --hard && \
		git checkout master && \
		git branch -D unittest

process: build-docker
	docker run --rm \
		--env PLUGIN_BASE_DIR=${DOCKER_DIR} \
		--env PLUGIN_INPUT_DIR=scan \
		--env PLUGIN_FILE_POOL=SnapScanLossless \
		--env PLUGIN_FILE_FORMAT=pnm \
		--env PLUGIN_SCAN_DPI=600 \
		--env PLUGIN_DEBUG=1 \
		--env PLUGIN_VERBOSE=1 \
		${LINKDIR} ${LATEST}
