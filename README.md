# SMB + FTP Docker 镜像

基于 Alpine Linux 的轻量级文件服务器，集成 Samba 和 vsftpd。

## 项目结构

```
├── Dockerfile          # Docker 镜像构建文件
├── smb.conf            # Samba 配置模板
├── vsftpd.conf         # FTP 配置
├── vsftpd.pam          # FTP PAM 认证配置
├── start.sh            # 容器启动脚本
└── README.md
```

## 默认账号

| 项目 | 值 |
|------|-----|
| 用户名 | `test` |
| 密码 | `testpassord` |
| UID:GID | `1000:1000` |
| 共享目录 | `/share_data` |

支持通过环境变量自定义账号，见下方说明。

## 1、构建
这个仓库提交到github，会自动构建docker镜像，并推送到dockerhub上。 dockerhub 的镜像是: taanng/smb_ftp

### 2. 启动容器

**使用默认账号：**

```bash
docker run -d \
  --name smb-ftp \
  --restart=always \
  --network host \
  --privileged \
  taanng/smb_ftp
```

**自定义账号密码：**

```bash
docker run -d \
  --name smb-ftp \
  --restart=always \
  --network host \
  --privileged \
  -e USERNAME=myuser \
  -e PASSWORD=mypassword \
  taanng/smb_ftp
```

**持久化数据：**

```bash
docker run -d \
  --name smb-ftp \
  --restart=always \
  --network host \
  --privileged \
  -e USERNAME=myuser \
  -e PASSWORD=mypassword \
  -v /opt/wd_disk:/share_data \
  taanng/smb_ftp
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `USERNAME` | `test` | 用户名 |
| `PASSWORD` | `testpassord` | 密码 |
| `USER_UID` | `1000` | 用户 UID |
| `USER_GID` | `1000` | 用户组 GID |

## 使用方法

### SMB 访问

**Linux:**

```bash
# 安装客户端
sudo apt install smbclient

# 连接（共享名固定为 share）
smbclient //服务器IP/share -U 用户名%密码 -c "ls"

# 上传文件
smbclient //服务器IP/share -U 用户名%密码 -c "put /本地/文件.txt"

# 下载文件
smbclient //服务器IP/share -U 用户名%密码 -c "get 文件.txt"
```

**Windows:**

1. 打开文件资源管理器
2. 地址栏输入 `\\服务器IP\share`
3. 输入用户名和密码

**macOS:**

1. Finder 中按 `Cmd+K`
2. 输入 `smb://服务器IP/share`
3. 输入用户名和密码

### FTP 访问

**命令行:**

```bash
# 连接
ftp 服务器IP 21

# 或使用 lftp
lftp -u 用户名,密码 服务器IP
```

**curl:**

```bash
# 列出文件
curl ftp://用户名:密码@服务器IP/

# 上传文件
curl -T 本地文件.txt ftp://用户名:密码@服务器IP/

# 下载文件
curl -O ftp://用户名:密码@服务器IP/文件.txt
```

