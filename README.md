# SMB + FTP + WebDAV Docker 镜像

基于 Alpine Linux 的轻量级文件服务器，集成 Samba、vsftpd 和 Nginx WebDAV。

## 项目结构

```
├── Dockerfile          # Docker 镜像构建文件
├── smb.conf            # Samba 配置模板
├── vsftpd.conf         # FTP 配置
├── vsftpd.pam          # FTP PAM 认证配置
├── webdav.conf         # Nginx WebDAV 配置模板
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
| WebDAV 端口 | `20836` |

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
| `WEBDAV_PORT` | `20836` | WebDAV 监听端口 |

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

macOS 兼容性说明：

- 已启用 `vfs_fruit` 与 `vfs_streams_xattr`，FinderInfo 等元数据写入 xattr，普通文件不会再生成 `._` 伴生文件；资源分支仍以 AppleDouble 文件保存。
- `/share_data` 所在文件系统必须支持 xattr。ext4、XFS、Btrfs 通常可用；exFAT/NTFS 等不支持 xattr 的宿主机目录会导致 macOS 写入元数据失败。
- `deadtime = 0`，避免 Finder 的空闲连接被主动断开。
- `strict allocate = no`，保留稀疏文件语义，避免 macOS 磁盘映像或 sparsebundle 被强制分配满。
- 当前 `server signing = disabled`。普通 Finder 文件访问可用，但 macOS 26.4+ 的 Time Machine 要求 SMB 签名；如需 Time Machine，请把 `smb.conf` 改为 `server signing = auto`（或 `mandatory`），并单独创建启用 `fruit:time machine = yes` 的共享，不建议与日常文件共享混用。

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

### WebDAV 访问

SMB、FTP 和 WebDAV 共用同一个用户名、密码及 `/share_data` 目录。WebDAV 默认地址为：

```text
http://服务器IP:20836/
```

**curl:**

```bash
# 查看目录
curl -u 用户名:密码 -X PROPFIND -H "Depth: 1" http://服务器IP:20836/

# 上传文件
curl -u 用户名:密码 -T 本地文件.txt http://服务器IP:20836/文件.txt

# 下载文件
curl -u 用户名:密码 -O http://服务器IP:20836/文件.txt
```

**Windows / macOS:**

- Windows 文件资源管理器可映射网络驱动器 `http://服务器IP:20836/`。
- macOS Finder 中选择“连接服务器”，输入 `http://服务器IP:20836/`。

WebDAV 当前使用 HTTP Basic Auth，账号和密码会以明文链路传输。仅应在可信内网使用；如需公网访问，请在前方配置 HTTPS 反向代理。

