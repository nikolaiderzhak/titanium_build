#!/bin/sh

# A hudson build driver for Titanium Mobile 

export PATH=/bin:/usr/bin:$PATH
echo
echo 'this is path-env'
echo
echo $PATH
echo
echo


GIT_BRANCH=$1
echo
echo 'this is git_branch-env'
echo
echo $GIT_BRANCH
echo
echo


GIT_REVISION=`git log --pretty=oneline -n 1 | sed 's/ .*//' | tr -d '\n' | tr -d '\r'`
echo
echo 'git_revision-env'
echo
echo $GIT_REVISION
echo
echo



VERSION=`python $TITANIUM_BUILD/common/get_version.py | tr -d '\r'`
echo
echo 'version-env'
echo
echo $VERSION
echo
echo



TIMESTAMP=`date +'%Y%m%d%H%M%S'`
echo
echo 'timestamp-env'
echo
echo $TIMESTAMP
echo
echo




BASENAME=dist/mobilesdk-$VERSION.v$TIMESTAMP
echo
echo 'basename-env'
echo
echo $BASENAME
echo
echo


