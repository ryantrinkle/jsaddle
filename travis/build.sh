#!/bin/bash -ex

echo $PATH
export LC_ALL=C.UTF-8
GHCVER=`ghc --numeric-version`

JSADDLE_VERSION=`head -n2 jsaddle.cabal | tail -n1 | sed 's/[^0-9.]//g'`

if [[ -d .cabal && -d .ghc ]]; then
    cp -a .cabal .ghc /root
fi

npm install ws

cabal update
cabal new-build 'jsaddle:lib:jsaddle' 'jsaddle:test:test-tool'
GHC_PACKAGE_PATH=/opt/ghc/$GHCVER/lib/ghc-$GHCVER/package.conf.d:~/.cabal/store/ghc-$GHCVER/package.db:./dist-newstyle/packagedb/ghc-$GHCVER jsaddle_datadir=`pwd` ./dist-newstyle/build/jsaddle-$JSADDLE_VERSION/build/test-tool/test-tool

# update the cache
rm -rf .cabal
cp -a /root/.cabal ./
rm -rf .ghc
cp -a /root/.ghc ./
