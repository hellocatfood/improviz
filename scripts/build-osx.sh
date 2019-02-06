#! /bin/bash

BUILD_DIR="dist/improviz-osx"
mkdir -p $BUILD_DIR
cp -r ./assets $BUILD_DIR
cp -r ./stdlib $BUILD_DIR
cp -r ./usercode $BUILD_DIR
cp -r ./textures $BUILD_DIR
cp -r ./examples $BUILD_DIR
cp ./improviz.yaml $BUILD_DIR
cp $(stack exec -- which improviz) $BUILD_DIR

tar -C ./dist -zcvf improviz-osx-${TRAVIS_TAG}.tar.gz improviz-osx
