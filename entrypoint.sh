#!/usr/bin/env bash
set -euo pipefail

RUNTIME="/etc/xray/runtime"
CFG="${RUNTIME}/config.json"
PIDFILE="${RUNTIME}/xray.pid"
RESTART_FLAG="${RUNTIME}/restart.required"
UPDATE_INTERVAL="${UPDATE_INTERVAL:-1800}"

TCP_PORT=12345
IPTABLES_ENABLED_FLAG="/etc/xray/runtime/iptables.enabled"
UDP_PORT=12346

if command -v iptables-legacy >/dev/null 2>&1; then
  export IPT=iptables-legacy
else
  export IPT=iptables
fi

setup_iptables() {
  echo "[entrypoint] setting up iptables (TCP REDIRECT only)"

  IPT="${IPT:-iptables}"

  # clean old
  $IPT -t nat -D OUTPUT -p tcp -j XRAY 2>/dev/null || true
  $IPT -t nat -F XRAY 2>/dev/null || true
  $IPT -t nat -X XRAY 2>/dev/null || true

  $IPT -t nat -N XRAY

  # bypass traffic from xray user (so it can fetch subscription / do healthchecks without loop)
  $IPT -t nat -A XRAY -m owner --uid-owner 10001 -j RETURN

  # bypass local/private
  $IPT -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
  $IPT -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
  $IPT -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
  $IPT -t nat -A XRAY -d 192.168.0.0/16 -j RETURN
  $IPT -t nat -A XRAY -d 169.254.0.0/16 -j RETURN

  # redirect all tcp
  $IPT -t nat -A XRAY -p tcp -j REDIRECT --to-ports 12345
  $IPT -t nat -A OUTPUT -p tcp -j XRAY
}

start_xray() {
  if [[ ! -f "$CFG" ]]; then
    echo "[entrypoint] config not found yet, will retry..."
    return 1
  fi

  echo "[entrypoint] starting xray"
  su -s /bin/sh -c "xray run -c '$CFG'" xray &
  echo $! > "$PIDFILE"

  # ждём, пока порт начнёт слушаться
  for _ in $(seq 1 50); do
    if ss -lnt | grep -q ":${TCP_PORT}"; then
      return 0
    fi
    sleep 0.1
  done

  echo "[entrypoint] xray did not open port ${TCP_PORT}"
  return 1
}

stop_xray() {
  if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE" || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "[entrypoint] stopping xray pid=$pid"
      kill "$pid" 2>/dev/null || true
      for _ in $(seq 1 30); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PIDFILE"
}
# 1) пробуем скачать и собрать конфиг ДО iptables
su -s /bin/sh -c "/usr/local/bin/update-sub.sh || true" xray

# 2) пытаемся стартовать xray
if start_xray; then
  setup_iptables
  touch "$IPTABLES_ENABLED_FLAG"
fi

while true; do
  # 1) обновляем подписку (безопасно даже если xray нет)
  su -s /bin/sh -c "/usr/local/bin/update-sub.sh || true" xray

  # 2) если xray не запущен — пробуем запустить
  if [[ ! -f "$PIDFILE" ]] || ! kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    rm -f "$PIDFILE" 2>/dev/null || true
    if start_xray; then
      if [[ ! -f "$IPTABLES_ENABLED_FLAG" ]]; then
        setup_iptables
        touch "$IPTABLES_ENABLED_FLAG"
      fi
    fi
  fi

  # 3) если update-sub попросил рестарт
  if [[ -f "$RESTART_FLAG" ]]; then
    rm -f "$RESTART_FLAG"
    stop_xray
    if start_xray; then
      # iptables уже стоят
      touch "$IPTABLES_ENABLED_FLAG"
    fi
  fi

  sleep "$UPDATE_INTERVAL"
done