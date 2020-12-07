#!/usr/bin/env bash

# Copyright 2020 The Cockroach Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then # Running inside bazel
  echo "OPM INDEX build..." >&2
elif ! command -v bazel &>/dev/null; then
  echo "Install bazel at https://bazel.build" >&2
  exit 1
else
  (
    set -o xtrace
    bazel run //hack:opm-build-index
  )
  exit 0
fi

# This script should be run via `bazel run //hack:gen-csv`
REPO_ROOT=${BUILD_WORKSPACE_DIRECTORY}
cd "${REPO_ROOT}"
echo ${REPO_ROOT}

OLM_REPO=$2
OLM_BUNDLE_REPO=$3
TAG=$4
VERSION=$5

echo "Running with $2 $3 $4 $5"

# TO DO-Hard coded for now
# echo "Calculator Versions"
# VERSIONS=$(git tag | xargs)

VERSIONS_LIST="$OLM_REPO:1.0.1"
# VERSIONS_LIST="$OLM_REPO:$TAG,$VERSIONS_LIST"
VERSIONS_LIST="$OLM_REPO:$TAG"

echo "Using tag ${OLM_BUNDLE_REPO}:${TAG}"
echo "Building index with $VERSIONS_LIST"
echo ""
./opm index add -u docker --generate --bundles "$VERSIONS_LIST" --tag "${OLM_BUNDLE_REPO}:${TAG}"
# ./opm index add --bundles "$OLM_REPO:$TAG" --from-index quay.io/my-container-registry-namespace/my-index:1.0.0 --tag quay.io/my-container-registry-namespace/my-index:1.0.1
if [ $? -ne 0 ]; then
    echo "fail to build opm"
    exit 1
fi

    RH_BUNDLE_REGISTRY=${RH_BUNDLE_REGISTRY} \
	RH_BUNDLE_IMAGE_REPOSITORY=${OLM_BUNDLE_REPO} \
	RH_BUNDLE_VERSION=${RH_BUNDLE_VERSION} \
	RH_DEPLOY_PATH=${RH_DEPLOY_PATH} \
	RH_BUNDLE_IMAGE_TAG=${TAG} \
	bazel run --stamp --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		//:push_operator_bundle_image 
# docker build -f custom-index.Dockerfile -t "${OLM_BUNDLE_REPO}:${TAG}" .
# docker push "${OLM_BUNDLE_REPO}:${TAG}"