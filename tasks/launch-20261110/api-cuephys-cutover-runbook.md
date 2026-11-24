# CuePhys API 域名切换手册（已部署，生产凭据仍待配置）

更新时间：2026-11-23（北京时间）

## 当前边界

- App Release 只接受 `https://cuephys.com` 或其子域名。
- 当前 `http://106.54.3.210:3000/health` 返回 200；这只是现网旧入口，不能用于正式登录。
- `api.cuephys.com` 已在 DNSPod 创建 A 记录指向 `106.54.3.210`（TTL 600）；服务器已部署独立 443 虚拟主机和证书，生产 `.env` 尚未修改。
- `youbilliards.com` 继续作为公司官网和法律页入口，不能把它的备案号或证书当作 API 主机的配置证明。

2026-11-23 17:27（北京时间）已在 DNSPod 保存 `api` A 记录。两台权威服务器均返回 `api.cuephys.com. 600 IN A 106.54.3.210`；随后通过 Cloudflare 和 Google 公共 DNS over HTTPS 均查到 `106.54.3.210`，公网解析已可见。系统本地递归仍可能短暂缓存此前的 NXDOMAIN。

服务器前置复核：`certbot 1.21.0`、`nginx 1.18.0` 已安装，80/443/3000 端口均在监听。2026-11-23 17:40（北京时间）已签发 API 证书并部署 Nginx 反代；官网配置未改，旧官网配置已在服务器保留备份。

## 执行顺序

### 1. 腾讯云 DNS

在 `cuephys.com` 的 DNS 控制台新增：

| 主机记录 | 类型 | 记录值 | TTL |
|---|---|---|---|
| `api` | A | `106.54.3.210` | 600 |

等待公共解析可见后，分别核对本地和外部递归解析：

```sh
dig +short api.cuephys.com A
dig @1.1.1.1 +short api.cuephys.com A
dig @8.8.8.8 +short api.cuephys.com A
```

三处都返回 `106.54.3.210` 后才能继续申请证书。当前权威解析已生效，公共递归尚未全部刷新。若服务器公网 IP 已变化，先以腾讯云实例实际公网 IP 为准，不能照抄旧值。

### 2. 证书与 Nginx（已完成）

在 DNS 生效后，在服务器上申请只覆盖 API 主机的证书：

```sh
sudo certbot certonly --nginx -d api.cuephys.com
sudo nginx -t
```

已将 `nginx-api-cuephys.conf.example` 的候选块部署为独立 `/etc/nginx/sites-enabled/cuephys-api`，确认 `proxy_pass` 指向 `127.0.0.1:3000`，并执行：

```sh
sudo nginx -t
sudo systemctl reload nginx
```

验证结果：`nginx -t` 通过；`https://api.cuephys.com/health` 返回 HTTP 200 和 `{"status":"ok"}`；证书主题为 `CN = api.cuephys.com`，签发方为 Let’s Encrypt，有效期至 2027-02-21。

不得在证书申请前把 443 配置指向不存在的证书路径，也不得删除现有 `youbilliards.com` 站点。

### 3. 健康检查与安全边界（API 基础链路已完成）

```sh
curl --fail-with-body --proto '=https' --tlsv1.2 https://api.cuephys.com/health
```

已验证 API `/health` 返回 200。法律页面使用公司官网的独立路径，不应假设 API 提供 `/legal/privacy`；需另行核验 `https://youbilliards.com/legal/cuephys-privacy/`、`https://youbilliards.com/legal/cuephys-terms/` 和 `https://youbilliards.com/support/`。记录：HTTP 状态、证书主机名、证书到期日、Nginx 配置版本和后端进程版本。HTTP 3000 只保留本机反代来源；外部 3000 访问应在云防火墙/安全组关闭或限制。

### 4. 生产环境变量与受控部署

在备份现有 `/opt/qiuji-backend/.env` 后，按 `backend/.env.example` 补齐并通过不回显方式核对：

- `APPLE_BUNDLE_ID=com.youbilliards.cuephys`
- `APPLE_TEAM_ID`、`APPLE_KEY_ID`、`APPLE_SIGNIN_KEY_PATH`
- `APPLE_TOKEN_ENCRYPTION_KEY`
- 微信 `WECHAT_APP_ID`、`WECHAT_APP_SECRET`（若首发启用微信登录）
- 法律页实际信息和 `LEGAL_DOCUMENTS_PUBLISHED` 发布门槛

`.p8`、JWT 密钥、微信 Secret 和完整 `.env` 不进入仓库、聊天或截图。部署后先做后端测试和健康检查，再安装写入正式 API 地址的候选包。

## 回滚

若证书、反代或应用健康检查失败：

1. 保留失败命令、Nginx `-t` 输出和服务日志；
2. 只回滚本次新增的 API 虚拟主机并 reload；
3. 恢复本次部署前的后端版本和 `.env` 备份；
4. 不把旧 HTTP 入口重新写入 Release 配置；真机登录仍保持阻断。

## 完成判定

DNS、证书链、Nginx 反代和 HTTPS 健康检查已完成；生产凭据自检、真机 Apple 登录和微信（若启用）登录仍未完成，因此“API 正式可用”仍不能作为整项上线完成。当前 API 基础链路已可供后续受控配置与联调使用。
