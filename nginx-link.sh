#!/usr/bin/env bash
# nginx-link.sh — 为群晖 WebStation 的 nginx 虚拟主机自动创建用户配置符号链接

set -euo pipefail

# ─── 配置 ────────────────────────────────────────────────────────────────────

# WebStation 自动生成的 nginx conf.d 目录
readonly CONF_D_DIR="/usr/local/etc/nginx/conf.d"

# ─── 函数 ────────────────────────────────────────────────────────────────────

log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# 自动查找 web_packages 所在的 volume，返回其路径（如 /volume1）
find_web_packages_volume() {
    local vol
    for vol in /volume*/; do
        if [[ -d "${vol}web_packages" ]]; then
            echo "${vol%/}"
            return 0
        fi
    done
    return 1
}

# 解析所有 .service* 文件，建立"域名 → include 目录名"映射
# 输出格式：每行 "<domain> <dirname>"
scan_service_files() {
    local file domain include_path dirname web_root="$1"

    shopt -s nullglob
    for file in "${CONF_D_DIR}"/.service*; do
        # 从 root 指令中提取 web 根目录下的子目录名（即域名标识）
        mapfile -t domains < <(grep -Po "root\s+\"${web_root}/\K[^\"]+" "$file" 2>/dev/null)

        # 从 include 指令中提取对应的目录路径（去掉末尾的 /user.conf*）
        mapfile -t include_paths < <(grep -Po 'include\s+\K[^"]+/([^/]+)(?=/user\.conf\*)' "$file" 2>/dev/null)

        # 域名数量与 include 路径数量必须一致，否则跳过
        if [[ ${#domains[@]} -eq 0 ]] || [[ ${#domains[@]} -ne ${#include_paths[@]} ]]; then
            continue
        fi

        for ((i = 0; i < ${#domains[@]}; i++)); do
            domain="${domains[$i]}"
            dirname="$(basename "${include_paths[$i]}")"
            echo "$domain $dirname"
        done
    done
    shopt -u nullglob
}

# 为单个域名创建符号链接
link_domain() {
    local domain="$1"
    local target_dir="$2"       # conf.d 下的目标目录名
    local user_conf_dir="$3"
    local target_path="${CONF_D_DIR}/${target_dir}"

    # 在用户配置根目录下查找与域名同名的文件夹
    local config_folder
    config_folder="$(find "$user_conf_dir" -maxdepth 2 -type d -name "$domain" -print -quit)"

    if [[ -z "$config_folder" ]]; then
        warn "未找到域名 '$domain' 对应的用户配置目录，跳过。"
        return 0
    fi

    ln -sf "$config_folder" "$target_path"
    log "符号链接已创建：$target_path -> $config_folder"
}

# 重新加载 nginx
reload_nginx() {
    log "正在重新加载 nginx 配置..."
    if sudo nginx -s reload; then
        log "nginx 配置重新加载成功。"
    else
        die "nginx 配置重新加载失败，请检查配置语法。"
    fi
}

# ─── 主流程 ──────────────────────────────────────────────────────────────────

main() {
    # 自动探测 web_packages 所在的 volume
    local volume
    if ! volume="$(find_web_packages_volume)"; then
        die "未在任何 /volume* 下找到 web_packages 目录，请确认 WebStation 已正确安装。"
    fi
    log "检测到 web_packages 位于：${volume}/web_packages"

    local USER_CONF_DIR="${volume}/web_packages/nginx"
    local WEB_ROOT="${volume}/web"

    log "开始扫描 ${CONF_D_DIR} 中的服务配置文件..."

    # 收集所有域名映射
    declare -A domain_map
    while read -r domain dirname; do
        domain_map["$domain"]="$dirname"
    done < <(scan_service_files "$WEB_ROOT")

    if [[ ${#domain_map[@]} -eq 0 ]]; then
        warn "未找到任何可处理的域名，退出。"
        exit 0
    fi

    log "扫描完成，共找到 ${#domain_map[@]} 个域名："
    for domain in "${!domain_map[@]}"; do
        log "  $domain  (-> ${domain_map[$domain]})"
    done

    log "5 秒后开始创建符号链接..."
    sleep 5

    for domain in "${!domain_map[@]}"; do
        link_domain "$domain" "${domain_map[$domain]}" "$USER_CONF_DIR"
    done

    reload_nginx
    log "全部配置完成。"
}

main "$@"
