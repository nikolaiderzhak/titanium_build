#!/bin/sh

# A hudson build driver for Titanium Mobile Modules

export PATH=/Users/nikolai/bin:/usr/local/git/bin:$PATH

export TITANIUM_BUILD=/Users/nikolai/build/titanium_build
export WORKSPACE=/Users/nikolai/build/workspace/titanium_mobile_modules

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

# iOS modules

for MODULE in `ls $WORKSPACE/iphone`; do
	cd $WORKSPACE/iphone/$MODULE
	echo "building $MODULE (iOS)..."
	./build.py  >& build.log
	grep 'BUILD SUCCEEDED'  build.log | uniq
	grep -q 'BUILD SUCCEEDED' build.log || cat build.log
	# check if zip was updated
	ZIP=`ls *\.zip`
	if [ -z "$ZIP" ]; then continue; fi
	STAMPED_ZIP=`echo $ZIP| sed "s/\(.*\).zip/\1-$TIMESTAMP.zip/"`
	mv $ZIP $STAMPED_ZIP
	$PYTHON $TITANIUM_BUILD/common/s3_uploader.py modules $STAMPED_ZIP $GIT_BRANCH $GIT_REVISION $BUILD_URL
	rm $STAMPED_ZIP
	echo
done

# Android modules

export ANDROID_SDK=/Users/vasyl/android-sdk-mac_x86
export ANDROID_NDK=/Users/nikolai/android-ndk-r7

for MODULE in `ls $WORKSPACE/android`; do
#	skip build.xml
	if [ "$MODULE" = "build.xml" ]; then continue; fi
#	for debugging of particular module
#	if [ "$MODULE" != "urbanAirship" ]; then continue; fi

	#MIN_SDK=`grep minsdk $WORKSPACE/android/$MODULE/manifest | cut -f3 -d' '`
	MSDK_VERSION=`grep titanium.version= $WORKSPACE/android/$MODULE/build.properties.example|cut -d= -f2`
	MODULE_DIR=$WORKSPACE/android/$MODULE

	for BRANCH in `s3cmd ls s3://builds.appcelerator.com/mobile/| grep DIR| awk '{print $2}'`; do
		SDK_BUCKET=`s3cmd ls $BRANCH | grep "\-$MSDK_VERSION" | grep $PLATFORM | tail -n1 | awk '{print $4}'`;
		if [ -n "$SDK_BUCKET" ]; then break; fi
	done
	if echo $SDK_BUCKET| grep -q master; then
		SDK=`echo $SDK_BUCKET| cut -d/ -f6`
		MSDK_VERSION_STAMP=`echo $SDK_BUCKET| cut -d- -f2`

		if [ ! -d  ~/Titanium/mobilesdk/osx/$MSDK_VERSION_STAMP ]; then
			rm -rf ~/Titanium/mobilesdk/osx/$MSDK_VERSION*
			s3cmd get --force $SDK_BUCKET && tar xzf $SDK -C ~/Titanium/
			rm $SDK
		fi	
		MSDK_VERSION=$MSDK_VERSION_STAMP
		TITANIUM_SDK="$HOME/Titanium/"
	else
		MSDK_VERSION=$MSDK_VERSION
		TITANIUM_SDK="/Library/Application Support/Titanium/"
	fi
	sed s/TITANIUM_VERSION/$MSDK_VERSION/ $TITANIUM_BUILD/modules/build.properties.template > $MODULE_DIR/build.properties

	TMP=`echo $TITANIUM_SDK|sed "s/\//\\\\\\\\\//g"`
	ESCAPED_TITANIUM_SDK=`echo $TMP|sed "s/\ /\\\\\\\\\\\\\\\\\ /g"`
	sed -i -e "s/TITANIUM_SDK/$ESCAPED_TITANIUM_SDK/" $MODULE_DIR/build.properties

	if [ -f $MODULE_DIR/build.properties.example ]; then
		grep -s android.platform $MODULE_DIR/build.properties.example >> $MODULE_DIR/build.properties
		grep -s google.apis $MODULE_DIR/build.properties.example >> $MODULE_DIR/build.properties
	else
		grep default $TITANIUM_BUILD/modules/build.properties.template| sed s/default\.// >> $MODULE_DIR/build.properties
	fi

	cd $WORKSPACE/android/$MODULE
	mkdir lib
	echo "building $MODULE (Android)..."

	ant -v clean dist >& ant.log
	grep 'BUILD SUCCESSFUL' ant.log || cat ant.log

	ZIP=`ls dist/*\.zip`
	if [ -z "$ZIP" ]; then continue; fi
	STAMPED_ZIP=`echo $ZIP| sed "s/\/\(.*\).zip/\/\1-$TIMESTAMP.zip/"`
	mv $ZIP $STAMPED_ZIP
	$PYTHON $TITANIUM_BUILD/common/s3_uploader.py modules $STAMPED_ZIP $GIT_BRANCH $GIT_REVISION $BUILD_URL
	rm $STAMPED_ZIP
	echo
done

$PYTHON $TITANIUM_BUILD/common/s3_cleaner.py modules $GIT_BRANCH
