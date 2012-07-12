#!/bin/sh

# A hudson build driver for Titanium Mobile 

export PATH=/bin:/usr/bin:$PATH

GIT_BRANCH=$1
GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
TIMESTAMP=`date +'%Y%m%d%H%M%S'`
BASENAME=dist/mobilesdk-$VERSION.v$TIMESTAMP

scons package_all=1 version_tag=$VERSION.v$TIMESTAMP $TI_MOBILE_SCONS_ARGS

if [ "$PYTHON" = "" ]; then
	PYTHON=python
fi

$PYTHON $TITANIUM_BUILD/common/s3_cleaner.py mobile $GIT_BRANCH
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-osx.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-linux.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-win32.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
