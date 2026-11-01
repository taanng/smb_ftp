# AGENTS.md

本文件适用于仓库根目录 `/home/tang/smb_ftp` 及其全部子目录。修改前先阅读本文件和 `README.md`；若未来出现更深层的 `AGENTS.md`，以更靠近目标文件的规则为准。

## 项目定位

这是一个把 Samba、vsftpd 与 Nginx WebDAV 打包到同一个 Alpine Linux 容器中的轻量文件服务器项目。三种协议共用同一个系统账号、UID/GID 和数据目录：

- SMB 共享名固定为 `share`，路径为 `/share_data`。
- FTP 根目录为 `/share_data`。
- WebDAV 根目录为 `/share_data`，默认监听 `20836`。
- 容器启动时从 `USERNAME`、`PASSWORD`、`USER_UID`、`USER_GID` 创建运行账号。
- 对外端口为 `21`、`139`、`445`、`20836`，FTP passive 端口范围为 `40000-40100`。

仓库没有应用源代码、依赖锁文件或自动化测试套件。核心变更通常涉及 Dockerfile、启动脚本和三个服务的配置。

## 文件职责

| 路径 | 职责 |
| --- | --- |
| `Dockerfile` | 定义 Alpine 基础镜像、软件包、配置文件位置、暴露端口和入口命令。 |
| `start.sh` | 容器 PID 1 启动脚本；创建用户、生成运行期配置、启动 Samba/vsftpd，并保持容器存活。 |
| `smb.conf` | Samba 配置模板；构建时复制到 `/etc/samba/smb.conf.template`。 |
| `vsftpd.conf` | vsftpd 配置；启动脚本会在运行时改写 `local_root`。 |
| `vsftpd.pam` | FTP PAM 配置；认证由 `/etc/vsftpd.userlist` 允许列表控制。 |
| `webdav.conf` | Nginx WebDAV 配置模板；启动时替换用户与端口并生成 htpasswd。 |
| `README.md` | 面向使用者的构建、启动、环境变量和客户端连接说明。 |
| `.github/workflows/build.yaml` | 每次 push 构建镜像并推送 Docker Hub 的 `latest` 标签。 |

## 必须保持的运行契约

- 保持 SMB、FTP 与 WebDAV 使用同一账号和同一 `/share_data` 数据目录。不要只为一个协议引入独立账号或独立存储，除非需求明确要求。
- `smb.conf` 中的 `__USERNAME__` 是启动占位符，必须保留，并由 `start.sh` 在运行期替换；不要把固定账号写死到模板中。
- `start.sh` 会生成 `/etc/vsftpd.userlist`，并改写 `/etc/vsftpd/vsftpd.conf` 的 `local_root`。修改认证或目录逻辑时必须同时验证 SMB、FTP 和 WebDAV。
- `webdav.conf` 中的 `__USERNAME__` 和 `__WEBDAV_PORT__` 是启动占位符，必须由 `start.sh` 替换。WebDAV 密码文件、临时目录和 worker 用户必须在启动时与运行账号保持一致。
- 环境变量名 `USERNAME`、`PASSWORD`、`USER_UID`、`USER_GID`、`WEBDAV_PORT` 是公开运行接口。修改名称、默认值或语义时，同步更新 `README.md`。
- 所有服务都在一个容器内运行，`start.sh` 是 PID 1。不要无意中改变前台保活逻辑，否则容器会立即退出。
- 端口、FTP passive 范围和共享路径必须与 `Dockerfile`、配置及 `README.md` 保持一致。
- 用户数据可能通过宿主机卷挂载到 `/share_data`。调整 UID/GID、权限或 `chown` 逻辑时，要考虑宿主机文件所有权和已有数据。

## 配置语义与安全边界

- Samba 面向受信任内网：当前最低协议为 SMB2，并显式关闭了服务端签名以降低 CPU 开销。这是有意的安全取舍。除非需求明确要求，不要自行恢复签名或改变协议范围；若必须修改，同步更新注释和 `README.md`。
- FTP 是明文协议，当前禁用匿名登录，启用 chroot，并通过 PAM 用户白名单限制账号。不要把该镜像直接暴露到不可信公网。
- WebDAV 使用 HTTP Basic Auth，当前没有内置 TLS。仅面向可信内网；若增加公网入口，必须通过 HTTPS 反向代理并说明部署要求。
- WebDAV 使用 Nginx `dav-ext` 模块提供 `PROPFIND`、`OPTIONS`、`LOCK` 和 `UNLOCK`。修改 WebDAV 配置时必须保留模块加载、锁区及 `dav_ext_methods`，并通过真实 WebDAV 请求验证。
- 示例账号仅用于演示。不要在脚本、日志、提交记录或新增文档中引入真实密码、密钥或其他生产凭据。
- 启动日志不应打印密码。新增调试输出时，只记录用户名、路径、UID/GID 等非敏感信息。
- 不要依赖 `latest` 提供可复现构建。需要变更基础软件版本时，评估固定 Alpine 或软件包版本的影响，并在说明中明确取舍。

## 权限与敏感信息

- 遵循全局权限规则：如需 root 权限，必须先说明用途并请求用户确认；未经明确确认，不得执行 `sudo`、`su` 或其他提权方式。
- root/sudo 密码按全局规则从 `/home/tang/software/mypass` 读取，只能在用户确认提权后按需使用。禁止把密码明文写入仓库、回复、命令输出或日志。
- 远程主机 `home_dt_vps` 的登录用户为 `tang`，并遵循同样的提权确认和凭据保护规则。

## 修改约定

- 进行最小、聚焦的修改，不要顺带重排无关配置或格式化整个文件。
- 保持 `start.sh` 的 Bash shebang；Alpine 默认工具可能来自 BusyBox，避免未经安装就使用 GNU 专属参数。
- 对运行期变量加引号，避免用户名、密码或路径中的空格导致拆词和命令注入。修改用户输入相关代码时必须进行 shell 安全检查。
- 保持启动流程可重复执行：容器重启时，用户、配置、目录和白名单应能重新生成。
- 保持配置文件使用 LF 换行。`start.sh` 的可执行权限由 Dockerfile 中的 `chmod +x /start.sh` 保证。
- 新增软件包前确认确有必要；该镜像的核心目标是轻量和快速启动。
- 修改用户可见行为、环境变量、端口、默认目录、认证方式或安全限制时，同步更新 `README.md`。
- 任何功能或行为改动完成后，必须在交付前进行自我测试；不能只检查代码或声称逻辑正确。

## 验证流程

功能改动的强制自测要求：

- 至少执行静态检查和镜像构建，并在隔离环境中启动新镜像。
- 针对实际改动执行对应场景，例如 SMB/FTP/WebDAV 登录与读写、WebDAV `PROPFIND`、环境变量生效、UID/GID 与目录权限、FTP passive 模式、配置生成或容器重启恢复。
- 检查启动日志和服务状态，确认修改没有引入错误，也不只是验证“容器仍在运行”。
- 如果受环境限制无法自测，不得宣称测试通过；必须明确说明未执行的测试、原因、已完成的替代检查及残余风险。

### 静态检查

先运行以下命令：

```bash
bash -n start.sh
docker build -t smb-ftp:local .
```

若本机缺少 Docker，说明未完成的验证，不要通过提权自行安装。根据全局规则，执行任何 `sudo`、`su` 或其他提权操作前必须先说明原因并获得用户确认。

### 容器 smoke test

需要在空闲主机上做端到端测试时，使用临时账号和临时 volume。以下测试使用宿主机网络，因为配置和 README 以 host network 为主要运行方式；先确认 `21`、`139`、`445` 和 `40000-40100` 未被占用：

```bash
docker volume create smb-ftp-agent-test
docker run --rm -d \
  --name smb-ftp-agent-test \
  --network host \
  -e USERNAME=agent-test \
  -e PASSWORD='<test-password>' \
  -e USER_UID="$(id -u)" \
  -e USER_GID="$(id -g)" \
  -v smb-ftp-agent-test:/share_data \
  smb-ftp:local

docker logs smb-ftp-agent-test
docker exec smb-ftp-agent-test testparm -s
docker exec smb-ftp-agent-test nginx -t
```

随后验证两个协议都能使用同一账号访问 `/share_data`：

```bash
smbclient //127.0.0.1/share -U 'agent-test%<test-password>' -c 'ls'
curl --fail --user 'agent-test:<test-password>' ftp://127.0.0.1/
curl --fail --user 'agent-test:<test-password>' -X PROPFIND -H 'Depth: 1' http://127.0.0.1:20836/
```

清理测试资源：

```bash
docker rm -f smb-ftp-agent-test
docker volume rm smb-ftp-agent-test
```

只有在确有运行需要时再使用 `--privileged`；不要仅为日常构建或基础 smoke test 添加该参数。

## Git 与发布风险

- `.github/workflows/build.yaml` 对任意 `push` 都会构建并推送 `taanng/smb_ftp:latest`，并清理旧 workflow runs。**除非用户明确要求发布，否则不要执行 `git push`，也不要推送测试分支或标签。**
- 不要擅自修改 Docker Hub 发布工作流、仓库名、标签策略或 Secrets 引用。
- 除非用户明确要求，不要提交、创建 tag、改写历史或执行破坏性的 Git 操作。
- 提交前检查 `git diff`，确保没有测试密码、临时配置或无关文件混入。
