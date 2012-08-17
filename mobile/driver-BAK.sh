#!/bin/sh

# A hudson build driver for Titanium Mobile 

SLAVE_PACKAGE='slave_package.zip'

export PATH=/bin:/usr/bin:$PATH

#############################################################################

# ANDROID_SDK=/usr/local/lib/android-sdk-linux
# export ANDROID_SDK
# 
# ANDROID_NDK=/usr/local/lib/android-ndk-r8
# export ANDROID_NDK
# 
# # JAVA_HOME=/usr/local/bin/jdk1.6.0_32
# JAVA_HOME=/jdk1.6
# export JAVA_HOME
# 
# TITANIUM_BUILD=/var/lib/jenkins/Source/titanium_build
# export TITANIUM_BUILD

echo
echo -----  titanium_build  ------------------------------------------------
echo $TITANIUM_BUILD
echo

#############################################################################

GIT_BRANCH=$1
echo 'GIT_BRANCH:    ' $GIT_BRANCH

TARGET_BRANCH=titanium_mobile_$GIT_BRANCH
echo 'TARGET_BRANCH: ' $TARGET_BRANCH

GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
echo 'GIT_REVISION: ' $GIT_REVISION

VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
echo 'VERSION: ' $VERSION

TIMESTAMP=`date +'%Y%m%d%H%M%S'`
echo 'TIMESTAMP: ' $TIMESTAMP

VTAG=$VERSION.v$TIMESTAMP
echo 'VTAG: ' $VTAG

BASENAME=dist/mobilesdk-$VTAG
echo 'BASENAME: '$BASENAME

echo
echo -----  p-a-t-h  -------------------------------------------------------
echo
echo $PATH
echo


scons package_all=1 version_tag=$VTAG $TI_MOBILE_SCONS_ARGS
# scons package_all=1 version_tag=$VTAG 

if [ "$PYTHON" = "" ]; then
	PYTHON=python
fi

echo
echo 'TI_MOBILE_SCONS_ARGS: ' $TI_MOBILE_SCONS_ARGS
echo
echo 'BUILD_URL: ' $BUILD_URL

# echo 'Full Basename--->'
# e.g.,  dist/mobilesdk-2.1.0.v20120518163317-osx.zip

echo
SDK_ARCHIVE="$BASENAME-osx.zip"
echo 'SDK_ARCHIVE: ' $SDK_ARCHIVE


TARGET_EXT='master'
export TARGET_EXT

if [ $GIT_BRANCH = '2_1_X' ]
then
	echo 'Renaming TARGET_BRANCH Folder Ext from 2_1_X to 2.1.X'
	TARGET_EXT='2.1.x'
fi

if [ $GIT_BRANCH = '2_0_X' ]
then
	echo 'Renaming TARGET_BRANCH Folder Ext from 2_0_X to 2.0.X'
	TARGET_EXT='2.0.x'
fi

if [ $GIT_BRANCH = '1_8_X' ]
then
        echo 'Renaming TARGET_BRANCH Folder Ext from 1_8_X to 1.8.X'
        TARGET_EXT='1.8.x'
fi

echo
cd /var/lib/jenkins/jobs/titanium_mobile_$TARGET_EXT/workspace
pwd
ls -la $SDK_ARCHIVE

echo
if [ -e "$SDK_ARCHIVE" ]
then
	echo "$SDK_ARCHIVE - does Exist."
else
	echo "Missing SDK zip file"
	exit 1
fi

echo $VTAG > slave_version.txt

if [ -e $SLAVE_PACKAGE ]
then
	echo "removing previous package file."
	rm -r $SLAVE_PACKAGE
fi
	
# zip -rq slave_package.zip slave_version.txt build drillbit runtests.sh slave_script.sh
zip -rq $SLAVE_PACKAGE slave_version.txt build drillbit 

if [ -e "tmp_unbundle" ]
then
	echo "removing old tmp files."
	rm -r tmp_unbundle
fi
	
mkdir tmp_unbundle
mkdir tmp_unbundle/dist
cd tmp_unbundle/dist
unzip -o ../../$SDK_ARCHIVE

cd mobilesdk/osx
echo
echo 'VTAG--->  renaming...'
echo $VTAG
echo
echo 'VERSION--->  to::::'
echo $VERSION
echo
mv $VTAG $VERSION

echo
echo Take I
pwd
cd ../../..

echo
pwd
ls -la

zip -urq ../$SLAVE_PACKAGE dist/mobilesdk

echo
echo Take II
ls -la

echo
echo Take III
cd ..
ls -la $SLAVE_PACKAGE > LAST_SLAVE_PACKAGE

cd tmp_unbundle

echo
echo 'TITANIUM_BUILD---->'
echo $TITANIUM_BUILD
echo

echo 'Listing Work-Space---->'
echo
pwd
echo
cd /var/lib/jenkins/jobs/titanium_mobile_$TARGET_EXT/workspace
ls -latr dist | tail -20

TS=`date +"%m%d%y-%H%M%S"`
ARCHIVE_FNAME="slave_package-$TS.zip"
echo
echo 'ARCHIVE_FNAME: ' $ARCHIVE_FNAME
cp $SLAVE_PACKAGE $ARCHIVE_FNAME

echo
echo Going to s3 Uploader
echo

$PYTHON $TITANIUM_BUILD/common/s3_cleaner.py mobile $GIT_BRANCH
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-osx.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-linux.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL
$PYTHON $TITANIUM_BUILD/common/s3_uploader.py mobile $BASENAME-win32.zip $GIT_BRANCH $GIT_REVISION $BUILD_URL

