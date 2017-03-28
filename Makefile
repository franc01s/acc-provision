
BASE=github.com/noironetworks/aci-containers
METADATA_SRC=$(wildcard pkg/metadata/*.go)
IPAM_SRC=$(wildcard pkg/ipam/*.go)
INDEX_SRC=$(wildcard pkg/index/*.go)
HOSTAGENT_SRC=$(wildcard cmd/hostagent/*.go pkg/hostagent/*.go)
AGENTCNI_SRC=$(wildcard cmd/opflexagentcni/*.go)
CONTROLLER_SRC=$(wildcard cmd/controller/*.go pkg/controller/*.go)
ACIKUBECTL_SRC=$(wildcard cmd/acikubectl/*.go cmd/acikubectl/cmd/*.go)

HOSTAGENT_DEPS=${METADATA_SRC} ${IPAM_SRC} ${HOSTAGENT_SRC}
AGENTCNI_DEPS=${METADATA_SRC} ${AGENTCNI_SRC}
CONTROLLER_DEPS=${METADATA_SRC} ${IPAM_SRC} ${INDEX_SRC} ${CONTROLLER_SRC}
ACIKUBECTL_DEPS=${METADATA_SRC} ${ACIKUBECTL_SRC}

BUILD_CMD ?= go build -v
TEST_CMD ?= go test -cover
TEST_ARGS ?=
INSTALL_CMD ?= go install -v
STATIC_BUILD_CMD ?= CGO_ENABLED=0 GOOS=linux ${BUILD_CMD} \
	-ldflags="-s -w" -a -installsuffix cgo
DOCKER_BUILD_CMD ?= docker build

.PHONY: clean goinstall check all

all: vendor dist/aci-containers-host-agent dist/opflex-agent-cni \
	dist/aci-containers-controller dist/acikubectl
all-static: vendor dist-static/aci-containers-host-agent \
	dist-static/opflex-agent-cni dist-static/aci-containers-controller \
	dist-static/acikubectl

vendor:
	glide install -strip-vendor

clean-dist:
	rm -rf dist
clean-vendor:
	rm -rf vendor
clean: clean-dist clean-vendor

goinstall:
	${INSTALL_CMD} ${BASE}/cmd/opflexagentcni
	${INSTALL_CMD} ${BASE}/cmd/controller
	${INSTALL_CMD} ${BASE}/cmd/hostagent

dist/opflex-agent-cni: ${AGENTCNI_DEPS}
	${BUILD_CMD} -o $@ ${BASE}/cmd/opflexagentcni
dist-static/opflex-agent-cni: ${AGENTCNI_DEPS}
	${STATIC_BUILD_CMD} -o $@ ${BASE}/cmd/opflexagentcni

dist/aci-containers-host-agent: ${HOSTAGENT_DEPS}
	${BUILD_CMD} -o $@ ${BASE}/cmd/hostagent
dist-static/aci-containers-host-agent: ${HOSTAGENT_DEPS}
	${STATIC_BUILD_CMD} -o $@ ${BASE}/cmd/hostagent

dist/aci-containers-controller: ${CONTROLLER_DEPS}
	${BUILD_CMD} -o $@ ${BASE}/cmd/controller
dist-static/aci-containers-controller: ${CONTROLLER_DEPS}
	${STATIC_BUILD_CMD} -o $@ ${BASE}/cmd/controller

dist/acikubectl: ${ACIKUBECTL_DEPS}
	${BUILD_CMD} -o $@ ${BASE}/cmd/acikubectl
dist-static/acikubectl: ${ACIKUBECTL_DEPS}
	${STATIC_BUILD_CMD} -o $@ ${BASE}/cmd/acikubectl

container-all: container-host container-controller
container-host: dist-static/aci-containers-host-agent dist-static/opflex-agent-cni
	${DOCKER_BUILD_CMD} -t noiro/aci-containers-host -f ./docker/Dockerfile-host .
container-controller: dist-static/aci-containers-controller
	${DOCKER_BUILD_CMD} -t noiro/aci-containers-controller -f ./docker/Dockerfile-controller .

container-opflex-build-base:
	${DOCKER_BUILD_CMD} -t noiro/opflex-build-base -f ./docker/Dockerfile-opflex-build-base docker
container-openvswitch:
	${DOCKER_BUILD_CMD} -t noiro/openvswitch -f ./docker/Dockerfile-openvswitch docker

check: check-ipam check-index check-controller check-hostagent
check-ipam:
	${TEST_CMD} ${BASE}/pkg/ipam ${TEST_ARGS}
check-index:
	${TEST_CMD} ${BASE}/pkg/index ${TEST_ARGS}
check-hostagent:
	${TEST_CMD} ${BASE}/pkg/hostagent ${TEST_ARGS}
check-controller:
	${TEST_CMD} ${BASE}/pkg/controller ${TEST_ARGS}
