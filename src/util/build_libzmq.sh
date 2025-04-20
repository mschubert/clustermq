#!/bin/sh

cd "$(dirname $0)"/../libzmq

if [ ! -f Makefile.in ]; then
  ./autogen.sh || exit 1
fi

if [ ! -f src/.libs/libzmq.a ]; then
  CXX="$CXX" CXXFLAGS="$CXXFLAGS -fPIC" CPPFLAGS="$CPPFLAGS" ./configure \
    --enable-drafts \
    --enable-static \
    --disable-shared \
    --disable-maintainer-mode \
    --disable-Werror \
    --disable-libbsd \
    --disable-libunwind \
    --disable-perf \
    --disable-curve \
    --disable-curve-keygen \
    --disable-ws \
    --disable-radix-tree \
    --without-docs
  make || exit 1
fi
