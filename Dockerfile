FROM alpine:3.20

ARG XRAY_VERSION=26.2.6
ARG SUB_URL=""
ENV SUB_URL="${SUB_URL}"
ENV UPDATE_INTERVAL=1800

RUN apk add --no-cache ca-certificates curl jq tzdata bash python3 unzip iptables iptables-legacy iproute2 \
 && update-ca-certificates

RUN set -eux; \
  arch="$(uname -m)"; \
  case "$arch" in \
    x86_64)  XRAY_ARCH="64" ;; \
    aarch64) XRAY_ARCH="arm64-v8a" ;; \
    armv7l)  XRAY_ARCH="arm32-v7a" ;; \
    *) echo "Unsupported arch: $arch" && exit 1 ;; \
  esac; \
  url="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"; \
  curl -fsSL "$url" -o /tmp/xray.zip; \
  mkdir -p /opt/xray /usr/local/share/xray; \
  unzip -q /tmp/xray.zip -d /opt/xray; \
  install -m 0755 /opt/xray/xray /usr/local/bin/xray; \
  install -m 0644 /opt/xray/geoip.dat /usr/local/share/xray/geoip.dat; \
  install -m 0644 /opt/xray/geosite.dat /usr/local/share/xray/geosite.dat; \
  rm -rf /tmp/xray.zip /opt/xray

COPY base.template.json /etc/xray/base.template.json
COPY build_config.py /usr/local/bin/build_config.py
COPY update-sub.sh /usr/local/bin/update-sub.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/update-sub.sh /usr/local/bin/entrypoint.sh \
 && mkdir -p /etc/xray/runtime

RUN adduser -D -u 10001 xray \
 && mkdir -p /etc/xray/runtime \
 && chown -R xray:xray /etc/xray /etc/xray/runtime

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]