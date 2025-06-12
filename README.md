# uv-custom: uv 国内加速镜像

[![GitHub release](https://img.shields.io/github/v/release/Wangnov/uv-custom?display_name=tag&sort=semver&logo=github)](https://github.com/Wangnov/uv-custom/releases/latest)
[![Sync Status](https://github.com/Wangnov/uv-custom/actions/workflows/sync_release.yml/badge.svg)](https://github.com/Wangnov/uv-custom/actions/workflows/sync_release.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

这是一个与 [astral-sh/uv](https://github.com/astral-sh/uv) 官方版本同步的镜像项目，旨在为国内用户提供更快速、更稳定的 `uv` 安装和使用体验。

## ✨ 项目特点

- **下载加速**：所有 GitHub 下载链接均通过镜像代理，大幅提升下载速度。
- **预设镜像**：自动为您配置清华大学 PyPI 镜像和 Python 构建镜像。
- **自动同步**：通过 GitHub Actions，每 5 分钟检查一次官方版本，并自动发布同步的镜像版本到 GitHub 和 Gitee。
- **一键安装**：提供平台原生的一键安装命令，无需手动下载或授权。

---

## 🚀 快速安装

请根据您的操作系统，在终端中运行以下对应的一键安装命令。

### Gitee (主推)

**通过此方式安装，可确保所有下载资源均来自国内服务器，实现纯净、高速的国内网络安装体验。**

```sh
# macOS / Linux
curl -LsSf https://gitee.com/wangnov/uv-custom/releases/latest/download/uv-installer-custom.sh | sh
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -c "irm https://gitee.com/wangnov/uv-custom/releases/latest/download/uv-installer-custom.ps1 | iex"
```

### GitHub (备用)

```sh
# macOS / Linux
curl -LsSf https://github.com/Wangnov/uv-custom/releases/latest/download/uv-installer-custom.sh | sh
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -c "irm https://github.com/Wangnov/uv-custom/releases/latest/download/uv-installer-custom.ps1 | iex"
```

---

## 🔧 (可选) 配置 Conda/Mamba 环境联动

如果您希望 `uv` 能够自动识别并管理当前激活的 Conda/Mamba 环境，可以运行以下对应的脚本来配置 Shell 钩子。

### Gitee (推荐)

```sh
# macOS / Linux
curl -LsSf https://gitee.com/wangnov/uv-custom/releases/latest/download/setup_hooks.sh | sh
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -c "irm https://gitee.com/wangnov/uv-custom/releases/latest/download/setup_hooks.ps1 | iex"
```

---

## 🙏 致谢

- 本项目的所有核心功能均基于 [astral-sh/uv](https://github.com/astral-sh/uv) 的出色工作。
- 感谢所有提供高速、稳定镜像服务的贡献者。

## 📄 许可证

本项目采用 [MIT](LICENSE) 许可证。