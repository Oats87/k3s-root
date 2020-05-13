#!/bin/bash
set -x -e -m

BUILD_ARCHS=${BUILD_ARCHS:-amd64 arm64 arm ppc64le}

build_and_tar()
{
    arch=$1
    docker build --build-arg ARCH=${arch} --tag k3s-root-${arch} .
    docker run --rm k3s-root-${arch} \
        tar cf - -C /usr/src ./bin ./etc > dist/k3s-root-${arch}.tar
    docker run --rm k3s-root-${arch} \
        tar cf - -C /usr/src --transform s/xtables-bin/bin/ ./xtables-bin > dist/k3s-root-xtables-${arch}.tar
}

mkdir -p dist
for arch in ${BUILD_ARCHS}; do
    build_and_tar ${arch} &
done

while [ 1 ]; do fg 2> /dev/null; [ $? == 1 ] && break; done