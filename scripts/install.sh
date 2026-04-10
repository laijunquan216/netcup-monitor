#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/netcup-monitor}"
REPO_URL="${REPO_URL:-https://github.com/laijunquan216/netcup-monitor.git}"
BRANCH="${BRANCH:-main}"
PORT="${PORT:-5000}"
TZ="${TZ:-Asia/Shanghai}"
FORCE="${FORCE:-0}"

export DEBIAN_FRONTEND=noninteractive

log() { echo "[netcup-monitor/install] $*"; }
fatal() { echo "[netcup-monitor/install][ERROR] $*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fatal "请使用 root 运行安装脚本。"
  fi
}

ensure_os_supported() {
  if [[ ! -f /etc/os-release ]]; then
    fatal "无法识别系统版本，仅支持 Ubuntu/Debian。"
  fi
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *)
      if [[ "${ID_LIKE:-}" != *"debian"* ]]; then
        fatal "当前系统: ${PRETTY_NAME:-unknown}，仅支持 Ubuntu/Debian。"
      fi
      ;;
  esac
  log "系统检测通过: ${PRETTY_NAME:-$ID}"
}

ensure_arch_supported() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64|aarch64|arm64|armv7l|armv8l) ;;
    *) fatal "当前架构 ${arch} 未在支持列表（x86/ARM）中。" ;;
  esac
  log "架构检测通过: ${arch}"
}

install_base_packages() {
  log "安装基础依赖..."
  apt-get update -y
  apt-get install -y ca-certificates curl git gnupg lsb-release
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker 已安装: $(docker --version)"
  else
    log "未检测到 Docker，开始自动安装 docker.io ..."
    apt-get update -y
    apt-get install -y docker.io
  fi

  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose 插件已安装"
  else
    log "安装 docker-compose-plugin..."
    apt-get update -y
    apt-get install -y docker-compose-plugin || true
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log "docker compose 插件不可用，尝试安装 docker-compose (v1)..."
    apt-get update -y
    apt-get install -y docker-compose
  fi

  systemctl enable --now docker >/dev/null 2>&1 || true

  command -v docker >/dev/null 2>&1 || fatal "Docker 安装失败，请手动检查。"
  docker --version || true
  if docker compose version >/dev/null 2>&1; then
    docker compose version || true
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --version || true
  else
    fatal "未找到 docker compose 或 docker-compose。"
  fi
}

ensure_port_free() {
  if ss -lnt | grep -qE "[\.:]${PORT}\b"; then
    fatal "端口 ${PORT} 已被占用，请修改 PORT 环境变量后重试。"
  fi
}

fetch_repo() {
  if [[ -d "${APP_DIR}/.git" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      log "目录已存在，FORCE=1，删除后重新拉取..."
      rm -rf "${APP_DIR}"
    else
      fatal "${APP_DIR} 已存在。若要覆盖安装，请加 FORCE=1。"
    fi
  elif [[ -d "${APP_DIR}" ]] && [[ -n "$(ls -A "${APP_DIR}" 2>/dev/null || true)" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      log "目录已存在且非空，FORCE=1，删除后重新拉取..."
      rm -rf "${APP_DIR}"
    else
      fatal "${APP_DIR} 非空。若要覆盖安装，请加 FORCE=1。"
    fi
  fi

  log "拉取仓库 ${REPO_URL} (${BRANCH}) 到 ${APP_DIR} ..."
  git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
  mkdir -p "${APP_DIR}/data"
}

write_compose_file() {
  log "生成 docker-compose.yml（源码构建，自动适配 x86/ARM）..."
  cat > "${APP_DIR}/docker-compose.yml" <<YAML
services:
  netcup-monitor:
    build:
      context: .
    image: netcup-monitor:local
    container_name: netcup-monitor
    restart: unless-stopped
    ports:
      - "${PORT}:5000"
    volumes:
      - ./data:/app/data
      - /etc/localtime:/etc/localtime:ro
      # 如需自动重启 Vertex 容器请保留
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=${TZ}
YAML
}

compose_up() {
  cd "${APP_DIR}"
  log "构建并启动服务..."
  if docker compose version >/dev/null 2>&1; then
    docker compose up -d --build
    docker compose ps
  else
    docker-compose up -d --build
    docker-compose ps
  fi
}

show_result() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  log "安装完成。"
  echo "访问地址: http://${ip:-<YOUR_SERVER_IP>}:${PORT}"
  echo "本机检查: curl -fsS -I http://127.0.0.1:${PORT}"
}

main() {
  require_root
  ensure_os_supported
  ensure_arch_supported
  install_base_packages
  ensure_docker
  ensure_port_free
  fetch_repo
  write_compose_file
  compose_up
  show_result
}

main "$@"
