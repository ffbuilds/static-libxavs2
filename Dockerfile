
# bump: xavs2 /XAVS2_VERSION=([\d.]+)/ https://github.com/pkuvcl/xavs2.git|^1
# bump: xavs2 after ./hashupdate Dockerfile XAVS2 $LATEST
# bump: xavs2 link "Release" https://github.com/pkuvcl/xavs2/releases/tag/$LATEST
# bump: xavs2 link "Source diff $CURRENT..$LATEST" https://github.com/pkuvcl/xavs2/compare/v$CURRENT..v$LATEST
ARG XAVS2_VERSION=1.4
ARG XAVS2_URL="https://github.com/pkuvcl/xavs2/archive/refs/tags/$XAVS2_VERSION.tar.gz"
ARG XAVS2_SHA256=1e6d731cd64cb2a8940a0a3fd24f9c2ac3bb39357d802432a47bc20bad52c6ce

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG XAVS2_URL
ARG XAVS2_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O xavs2.tar.gz "$XAVS2_URL" && \
  echo "$XAVS2_SHA256  xavs2.tar.gz" | sha256sum --status -c - && \
  mkdir xavs2 && \
  tar xf xavs2.tar.gz -C xavs2 --strip-components=1 && \
  rm xavs2.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/xavs2/ /tmp/xavs2/
WORKDIR /tmp/xavs2/build/linux
RUN \
  apk add --no-cache --virtual build \
    build-base bash pkgconf && \
  # TODO: seems to be issues with asm on musl
  ./configure --disable-asm --enable-pic --disable-cli && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path xavs2 && \
  ar -t /usr/local/lib/libxavs2.a && \
  readelf -h /usr/local/lib/libxavs2.a && \
  # Cleanup
  apk del build

FROM scratch
ARG XAVS2_VERSION
COPY --from=build /usr/local/lib/pkgconfig/xavs2.pc /usr/local/lib/pkgconfig/xavs2.pc
COPY --from=build /usr/local/lib/libxavs2.a /usr/local/lib/libxavs2.a
COPY --from=build /usr/local/include/xavs2*.h /usr/local/include/
