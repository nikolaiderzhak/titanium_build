#!/bin/sh

# A hudson build driver for Titanium Mobile Modules

export PATH=/usr/local/git/bin:~/bin:$PATH

#export TITANIUM_BUILD=/Users/nikolai/build/titanium_build
#export WORKSPACE=/Users/nikolai/build/titanium_mobile_modules

export ANDROID_SDK=/Users/vasyl/android-sdk-mac_x86
export MOBILE_SDK="/Library/Application Support/Titanium/mobilesdk"
export MSDK_BRANCHES="master 1_7_X 1_6_X"

cd $WORKSPACE

#git pull

GIT_BRANCH=$1
GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
#VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
PLATFORM=`python -c "import platform; print ({'Darwin':'osx','Windows':'win32','Linux':'linux'})[platform.system()]" | tr -d '\r' | tr -d '\n'`
TIMESTAMP=`date +'%Y%m%d%H%M%S'`

if [ "$PYTHON" = "" ]; then
	PYTHON=python
fi

for MSDK_BRANCH in $MSDK_BRANCHES; do

SDK_BUCKET=`s3cmd ls s3://builds.appcelerator.com/mobile/$MSDK_BRANCH/| grep $PLATFORM| tail -n1| awk '{print $4}'`
s3cmd get $SDK_BUCKET
SDK=`echo $SDK_BUCKET| cut -d/ -f6`
tar xzf $SDK -C ~/Titanium/

MSDK_VERSION=`tar tzf $SDK | head -n 1 | cut -d/ -f 3`
rm $SDK

# Android 

cd $WORKSPACE/Scout

APP_ID=`grep '<id>' tiapp.xml | awk -F"<|>" '{print $3}'`
APP_NAME=`grep '<name>' tiapp.xml | awk -F"<|>" '{print $3}'`

echo "building Scout (Android)..."

git show --format=%H| head -n1 > Resources/revision

/Users/nikolai/Titanium/mobilesdk/$PLATFORM/$MSDK_VERSION/android/builder.py build $APP_NAME $ANDROID_SDK . $APP_ID > build.log 2>&1

(grep app.apk build.log | grep -q jarsigner) || ( cat build.log && exit )

BUILD_DIR=build/android/bin

STAMPED_APK=scout-$TIMESTAMP-sdk-$MSDK_VERSION-android.apk

mv $BUILD_DIR/app.apk $STAMPED_APK

$PYTHON $TITANIUM_BUILD/common/s3_uploader.py scout $STAMPED_APK $GIT_BRANCH $GIT_REVISION $BUILD_URL
rm $STAMPED_APK
echo

$PYTHON $TITANIUM_BUILD/common/s3_cleaner.py scout $GIT_BRANCH

done
