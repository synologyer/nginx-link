# nginx-link

为**群晖 WebStation** 自动建立 nginx 用户配置符号链接。

WebStation 每次重启或更新都会重新生成 nginx 的 `conf.d` 目录，导致手动写入的自定义配置丢失。本脚本通过符号链接的方式将你维护在固定位置的 `user.conf` 挂载到 WebStation 的 conf.d 中，重启后只需重新运行一次脚本即可恢复所有配置。

---

## 目录结构

```
/volume2/
├── web/                        # WebStation Web 根目录
│   └── <subdomain>/            # 每个二级域名对应一个子目录
│
├── web_packages/
│   └── nginx/                  # 用户自定义配置根目录（USER_CONF_DIR）
│       └── <subdomain>/        # 目录名须与对应的二级域名前缀完全一致
│           └── user.conf       # 自定义 nginx 配置片段
│
└── ...

/usr/local/etc/nginx/conf.d/    # WebStation 自动管理的 conf.d（CONF_D_DIR）
    ├── .service_xxxx            # WebStation 生成的虚拟主机配置（只读）
    └── <subdomain> -> ...       # 本脚本创建的符号链接
```

---

## 使用方法

### 1. 准备目录和配置文件

以二级域名 `app` 为例（对应 `app.example.com`）：

```bash
# 创建 web 根目录（如果还没有）
mkdir -p /volume2/web/app

# 创建用户配置目录
mkdir -p /volume2/web_packages/nginx/app

# 创建并编辑 user.conf
cat > /volume2/web_packages/nginx/app/user.conf << 'EOF'
# 在此写入自定义 nginx 配置，例如：
location /api/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
EOF
```

多个域名重复以上步骤，每个域名一个独立子目录。

### 2. 下载脚本

```bash
curl -O https://raw.githubusercontent.com/synologyer/nginx-link/main/nginx-link.sh
chmod +x nginx-link.sh
```

### 3. 修改脚本顶部的路径配置（按需）

```bash
# 打开脚本，修改以下三个常量
readonly USER_CONF_DIR="/volume2/web_packages/nginx"  # 用户配置根目录
readonly CONF_D_DIR="/usr/local/etc/nginx/conf.d"     # WebStation conf.d 目录
readonly WEB_ROOT="/volume2/web"                       # web 根目录
```

### 4. 运行脚本

```bash
sudo bash nginx-link.sh
```

脚本会自动扫描所有虚拟主机配置，匹配对应的用户配置目录，创建符号链接，并重载 nginx。

---

## 自动化（开机自动运行）

在群晖「控制面板 → 任务计划」中新增一条**触发的任务**：

| 设置项 | 值 |
|--------|-----|
| 任务类型 | 触发的任务 → 用户定义的脚本 |
| 触发事件 | 开机 |
| 用户 | root |
| 命令 | `bash /path/to/nginx-link.sh` |

---

## 工作原理

1. 脚本扫描 `conf.d` 下所有 `.service*` 文件（WebStation 自动生成的虚拟主机配置）。
2. 通过正则从每个文件中提取 `root` 路径（域名标识）和 `include` 路径（符号链接目标目录名）。
3. 在 `USER_CONF_DIR` 下查找与域名同名的子目录。
4. 以 `ln -sf` 创建符号链接，将用户配置目录挂载到 conf.d 对应位置。
5. 执行 `nginx -s reload` 使配置生效。

---

## 注意事项

- 用户配置目录名须与二级域名前缀**完全一致**（区分大小写）。
- `user.conf` 只是片段文件，不需要包含 `server { }` 块，直接写 `location`、`add_header` 等指令即可。
- 脚本需要以 `root` 权限运行（或通过 `sudo`），因为需要在 `conf.d` 目录下创建链接并重载 nginx。
- WebStation 更新或重启后需重新运行脚本（建议配置开机自动运行）。
