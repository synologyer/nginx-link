#!/bin/bash

# 外部conf文件目录
directory_user_conf="/volume2/web_packages/nginx/"

# web station conf文件目录
directory_conf_d="/usr/local/etc/nginx/conf.d"

# web station文件夹
directory_web="/volume2/web/"

# 存储提取到的域名列表及其对应的 include 文件路径
declare -A domain_include_map

echo "开始扫描符合条件的文件..."

for file in $directory_conf_d/.service*; do
    # 提取域名
    domains=($(grep -Po "root\s+\"$directory_web\K[^\"]+" "$file"))
    # 提取文件夹路径，并将结果存储在 include_files 数组中
    include_files=($(grep -Po 'include\s+\K[^"]+/([^/]+)(?=\/user\.conf\*)' "$file"))

    # 如果没有找到域名，则跳过该文件
    if [ ${#domains[@]} -eq 0 ] || [ ${#domains[@]} -ne ${#include_files[@]} ]; then
        continue
    fi

    # 将域名及其对应的 include 文件路径添加到映射中
    for ((i=0; i<${#domains[@]}; i++)); do
        domain=${domains[$i]}
        include_file=${include_files[$i]}
        # 使用basename命令获取文件名并存储
        filename=$(basename "$include_file")
        domain_include_map["$domain"]="$filename"
    done
done

echo "扫描完成."

# 列出所有域名和对应的 include 文件路径
echo "找到以下域名及其对应的文件夹路径名："
for domain in "${!domain_include_map[@]}"; do
    echo "$domain (${domain_include_map[$domain]})"
done

# 等待 30 秒
echo "等待 5 秒..."
sleep 5

# 遍历所有域名并创建符号链接
for domain in "${!domain_include_map[@]}"; do
    # 查找匹配的配置文件夹
    config_folder=$(find "$directory_user_conf" -type d -name "$domain")

    if [ -z "$config_folder" ]; then
        echo "未找到匹配的配置文件夹: $domain"
        continue
    fi

    # 获取目标文件路径
    target_file="${directory_conf_d}/${domain_include_map[$domain]}"
    echo "为域名 $domain 创建符号链接，目标文件路径是: $target_file"

    # 创建符号链接
    ln -sf "$config_folder" "$target_file"

    if [ $? -eq 0 ]; then
        echo "已创建 $target_file 链接到 $config_folder"
    else
        echo "创建符号链接失败: $target_file -> $config_folder"
    fi
done

# 重新加载 nginx 配置
echo "重新加载 NGINX 配置..."
sudo nginx -s reload

if [ $? -eq 0 ]; then
    echo "NGINX 配置重新加载成功！"
else
    echo "NGINX 配置重新加载失败！"
fi

echo "配置完成"
