#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/netcup-monitor}"
BRANCH="${BRANCH:-main}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/backups}"

log() { echo "[netcup-monitor/upgrade] $*"; }
fatal() { echo "[netcup-monitor/upgrade][ERROR] $*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fatal "请使用 root 运行升级脚本。"
  fi
}

ensure_repo_exists() {
  [[ -d "${APP_DIR}" ]] || fatal "目录不存在: ${APP_DIR}"
  [[ -d "${APP_DIR}/.git" ]] || fatal "${APP_DIR} 不是 Git 仓库，无法代码升级。"
}

backup_config() {
  mkdir -p "${BACKUP_DIR}"
  local ts backup_file
  ts="$(date +%Y%m%d_%H%M%S)"
  backup_file="${BACKUP_DIR}/config-${ts}.json"
  if [[ -f "${APP_DIR}/data/config.json" ]]; then
    cp "${APP_DIR}/data/config.json" "${backup_file}"
    log "配置备份完成: ${backup_file}"
  else
    log "未找到 data/config.json，跳过配置备份。"
  fi
}

pull_latest() {
  cd "${APP_DIR}"
  log "切换分支并拉取最新代码: ${BRANCH}"
  git fetch --all --prune
  git checkout "${BRANCH}"
  git pull --ff-only origin "${BRANCH}"
}

ensure_compose_exists() {
  if [[ ! -f "${APP_DIR}/docker-compose.yml" ]]; then
    fatal "未找到 ${APP_DIR}/docker-compose.yml，请先执行安装脚本。"
  fi
}

compose_upgrade() {
  cd "${APP_DIR}"
  if docker compose version >/dev/null 2>&1; then
    log "重新构建并滚动升级容器..."
    docker compose up -d --build
    docker compose ps
  elif command -v docker-compose >/dev/null 2>&1; then
    log "使用 docker-compose (v1) 重新构建并升级容器..."
    docker-compose up -d --build
    docker-compose ps
  else
    fatal "未找到 docker compose 或 docker-compose。"
  fi
}

show_result() {
  local port
  port="$(awk -F'[:"]+' '/- "[0-9]+:5000"/{print $2; exit}' "${APP_DIR}/docker-compose.yml" || true)"
  log "升级完成。"
  if [[ -n "${port}" ]]; then
    echo "本机检查: curl -fsS -I http://127.0.0.1:${port}"
  fi
}

main() {
  require_root
  ensure_repo_exists
  ensure_compose_exists
  backup_config
  pull_latest
  compose_upgrade
  show_result
}

main "$@"
