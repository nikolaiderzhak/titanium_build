#!/bin/sh

# A hudson build driver for Titanium HTML5 

export PATH=/bin:/usr/bin:$PATH
scons package_all=1

GIT_BRANCH=$1
GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
PLATFORM=`python -c "import platform; print ({'Darwin':'osx','Windows':'win32','Linux':'linux'})[platform.system()]" | tr -d '\r' | tr -d '\n'`
TIMESTAMP=`date +'%Y%m%d%H%M%S'`
BASENAME=dist/mobilesdk_html5-$VERSION-$TIMESTAMP

mv dist/linux-$VERSION-mobilesdk.zip $BASENAME-linux.zip
mv dist/osx-$VERSION-mobilesdk.zip $BASENAME-osx.zip
mv dist/win32-$VERSION-mobilesdk.zip $BASENAME-win32.zip

if [ "$PYTHON" = "" ]; then
	PYTHON=python
fi

$PYTHON $TITANIUM_BUILD/common/s3_cleaner.py html5 $GIT_BRANCH
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py html5 $BASENAME-linux.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py html5 $BASENAME-osx.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py html5 $BASENAME-win32.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
