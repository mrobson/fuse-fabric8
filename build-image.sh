DOCKER_IMAGE_NAME=mrobson/fuse-fabric8
DOCKER_IMAGE_VERSION=6.2.1.090

docker rmi --force=true ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}
docker build --force-rm=true --rm=true -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION} .
