#!/bin/sh

# A hudson build driver for Titanium Mobile releases

export PATH=/bin:/usr/bin:$PATH

GIT_BRANCH=$1

RELEASE_TAG=.$2

# TODO This is a hack until we decide how to properly tag versions for OSGi
if [ "$RELEASE_TAG" = ".GA" ]; then
	RELEASE_TAG=
fi

GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
TIMESTAMP=`date +'%Y%m%d%H%M%S'`
BASENAME=dist/mobilesdk-$VERSION$RELEASE_TAG

scons package_all=1 version_tag=$VERSION$RELEASE_TAG $TI_MOBILE_SCONS_ARGS

if [ "$PYTHON" = "" ]; then
	PYTHON=python
fi

$PYTHON $TITANIUM_BUILD/common/s3_upload_release.py $VERSION$RELEASE_TAG $BASENAME-osx.zip $BASENAME-linux.zip $BASENAME-win32.zip
