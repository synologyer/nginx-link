群晖webstation部署web时nginx自定义配置

# 使用前提
# 1. 在/volume*/web下创建部署web项目的文件夹。
# 2. 在/volume*/web_packages文件夹下创建nginx文件夹，并且在nginx文件夹下面再创建一个跟二级域名前缀一样的文件夹。这里不一定要放到/volume*/web_packages这个文件夹里，也可以自定义其他路径。可以在directory_user_conf这里修改路径
# 3. 创建user.conf文件并写入配置。然后把它放到你想修改配置的二级域名前缀文件夹内。
