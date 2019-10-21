#!/bin/bash

set -e

if [ $EUID -ne 0 ]; then
	echo "This tool must be run as root"
	exit 1
fi

if [[ ${TRAVIS_TAG} == v* ]]; then
	VERSION=${TRAVIS_TAG:1}
else
	echo "Not in a tag, exit"
	exit 1
fi

dist=${1}

mkdir -p debs_to_deploy_${dist}

if [ ! -d raspbian-deb-builder ]; then
	git clone https://github.com/oytis/raspbian-deb-builder
fi

pushd ./raspbian-deb-builder

echo "Starting building azure-iot-sdk-c packages for Raspbian ${dist}"
DEBS=$(./cross-build.sh ${dist} azure-iot-sdk-c:${TRAVIS_TAG}:${VERSION} 2>../build.log)
echo "Done building azure-iot-sdk-c packages for Raspbian ${dist}"

popd

for d in ${DEBS}; do
	mv ${d} debs_to_deploy_${dist}
done

NUM_LIB_DEBS=$(ls -1q debs_to_deploy_${dist}/azure-iot-sdk-c-twilio-lib* | wc -l)
NUM_DEV_DEBS=$(ls -1q debs_to_deploy_${dist}/azure-iot-sdk-c-twilio-dev* | wc -l)

if [ ${NUM_LIB_DEBS} -ne 1 ]; then
	echo "Exactly one lib debian file for ${dist} expected"
	ls -1q debs_to_deploy_${dist}/*

	echo "Build log: "
	cat build.log
	exit 1
fi

if [ ${NUM_DEV_DEBS} -ne 1 ]; then
	echo "Exactly one dev debian file for ${dist} expected"
	ls -1q debs_to_deploy_${dist}/*

	echo "Build log: "
	cat build.log
	exit 1
fi

cat >deploy-${dist}-lib.json <<EOF
{
  "package": {
    "name":"azure-iot-sdk-c-twilio-lib",
    "repo":"wireless",
    "subject":"twilio",
    "licenses": ["MIT"],
    "public_stats": true,
    "public_download_numbers": false
  },

  "version": {
    "name":"${VERSION}",
    "gpgSign":true
  },

  "files":
    [{"includePattern": "debs_to_deploy_${dist}/(azure-iot-sdk-c-twilio-lib.*\.deb)", "uploadPattern": "pool/main/m/azure-iot-sdk-c-twilio-lib/\$1",
      "matrixParams": {
        "deb_distribution": "${dist}",
        "deb_component": "main",
        "deb_architecture": "armhf"}
    }],
  "publish": true
}
EOF

cat >deploy-${dist}-dev.json <<EOF
{
  "package": {
    "name":"azure-iot-sdk-c-twilio-dev",
    "repo":"wireless",
    "subject":"twilio",
    "licenses": ["MIT"],
    "public_stats": true,
    "public_download_numbers": false
  },

  "version": {
    "name":"${VERSION}",
    "gpgSign":true
  },

  "files":
    [{"includePattern": "debs_to_deploy_${dist}/(azure-iot-sdk-c-twilio-dev.*\.deb)", "uploadPattern": "pool/main/m/azure-iot-sdk-c-twilio-dev/\$1",
      "matrixParams": {
        "deb_distribution": "${dist}",
        "deb_component": "main",
        "deb_architecture": "armhf"}
    }],
  "publish": true
}
EOF
