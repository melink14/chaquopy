#!/bin/bash
set -eu

HOST_TRIPLET=$(basename $CC | sed 's/-gcc$//')

cd mecab

./autogen.sh
./configure CFLAGS='-fPIC' CXXFLAGS='-fPIC' --host=$HOST_TRIPLET --enable-utf8-only
CFLAGS='-fPIC'
make clean
make -j $CPU_COUNT
make install prefix=$PREFIX

# rm -r $PREFIX/bin
# rm $PREFIX/lib/*.a
rm -r $PREFIX/share/man
