#!/bin/bash
# Copyright 2015, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# This script is invoked by run_interop_tests.py to build the docker image
# for interop testing. You should never need to call this script on your own.

set -x

cd `dirname $0`/../..
GRPC_ROOT=`pwd`
MOUNT_ARGS="-v $GRPC_ROOT:/var/local/jenkins/grpc"

GRPC_JAVA_ROOT=`cd ../grpc-java && pwd`
if [ "$GRPC_JAVA_ROOT" != "" ]
then
  MOUNT_ARGS+=" -v $GRPC_JAVA_ROOT:/var/local/jenkins/grpc-java"
else
  echo "WARNING: grpc-java not found, it won't be mounted to the docker container."
fi

GRPC_GO_ROOT=`cd ../grpc-go && pwd`
if [ "$GRPC_GO_ROOT" != "" ]
then
  MOUNT_ARGS+=" -v $GRPC_GO_ROOT:/var/local/jenkins/grpc-go"
else
  echo "WARNING: grpc-go not found, it won't be mounted to the docker container."
fi

mkdir -p /tmp/ccache

# Params:
#  INTEROP_IMAGE - name of tag of the final interop image
#  BASE_NAME - base name used to locate the base Dockerfile and build script
#  TTY_FLAG - optional -t flag to make docker allocate tty.

# Use image name based on Dockerfile checksum
BASE_IMAGE=${BASE_NAME}_base:`sha1sum tools/jenkins/$BASE_NAME/Dockerfile | cut -f1 -d\ `

# Make sure base docker image has been built. Should be instantaneous if so.
docker build -t $BASE_IMAGE --force-rm=true tools/jenkins/$BASE_NAME || exit $?

# Create a local branch so the child Docker script won't complain
git branch -f jenkins-docker

CIDFILE=`mktemp -u --suffix=.cid`

# Prepare image for interop tests, commit it on success.
(docker run \
  -e CCACHE_DIR=/tmp/ccache \
  -i $TTY_FLAG \
  $MOUNT_ARGS \
  -v /tmp/ccache:/tmp/ccache \
  --cidfile=$CIDFILE \
  $BASE_IMAGE \
  bash -l /var/local/jenkins/grpc/tools/jenkins/$BASE_NAME/build_interop.sh \
  && docker commit `cat $CIDFILE` $INTEROP_IMAGE \
  && echo "Successfully built image $INTEROP_IMAGE")
EXITCODE=$?

# remove intermediate container, possibly killing it first
docker rm -f `cat $CIDFILE`

# remove the cidfile
rm -rf `cat $CIDFILE`

exit $EXITCODE
