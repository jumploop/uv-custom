#!/bin/sh
#
# Stable wrapper for the official uv installer.
# It downloads the installer that matches UV_VERSION, applies the mirror
# settings, and leaves existing uv.toml files untouched.

set -eu

APP_VERSION="${UV_VERSION:-__DEFAULT_VERSION__}"
DOWNLOAD_PROXY="${UV_DOWNLOAD_PROXY:-__DOWNLOAD_PROXY__}"
PYPI_MIRROR="${UV_PYPI_MIRROR:-__PYPI_MIRROR__}"
DOWNLOAD_PROXY="${DOWNLOAD_PROXY%/}"

say() {
    printf '%s\n' "› $*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

case "$APP_VERSION" in
    [0-9]*)
        ;;
    *)
        die "invalid UV_VERSION: $APP_VERSION"
        ;;
esac

case "$APP_VERSION" in
    *[!0-9A-Za-z._-]*)
        die "invalid UV_VERSION: $APP_VERSION"
        ;;
esac

if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    die "curl or wget is required"
fi

TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

INSTALLER_PATH="$TMP_DIR/uv-installer.sh"
INSTALLER_URL="https://github.com/astral-sh/uv/releases/download/$APP_VERSION/uv-installer.sh"
DOWNLOAD_SOURCE=""

download_file() {
    _url="$1"
    _destination="$2"
    _proxied_url="$DOWNLOAD_PROXY/$_url"

    if [ "$DOWNLOADER" = "curl" ]; then
        if curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 20 "$_proxied_url" -o "$_destination"; then
            DOWNLOAD_SOURCE="proxy"
            return 0
        fi
        say "下载代理不可用，改用 GitHub 直连。"
        if curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 20 "$_url" -o "$_destination"; then
            DOWNLOAD_SOURCE="direct"
            return 0
        fi
    else
        if wget -q --tries=3 --timeout=20 "$_proxied_url" -O "$_destination"; then
            DOWNLOAD_SOURCE="proxy"
            return 0
        fi
        say "下载代理不可用，改用 GitHub 直连。"
        if wget -q --tries=3 --timeout=20 "$_url" -O "$_destination"; then
            DOWNLOAD_SOURCE="direct"
            return 0
        fi
    fi

    return 1
}

say "正在下载 uv $APP_VERSION 官方安装器..."
if ! download_file "$INSTALLER_URL" "$INSTALLER_PATH"; then
    die "failed to download official installer: $INSTALLER_URL"
fi

AUTO_BASE_URL=0
if [ -z "${UV_INSTALLER_GITHUB_BASE_URL:-}" ] &&
    [ -z "${UV_INSTALLER_GHE_BASE_URL:-}" ] &&
    [ -z "${INSTALLER_DOWNLOAD_URL:-}" ] &&
    [ -z "${UV_DOWNLOAD_URL:-}" ]; then
    AUTO_BASE_URL=1
    if [ "$DOWNLOAD_SOURCE" = "proxy" ]; then
        UV_INSTALLER_GITHUB_BASE_URL="$DOWNLOAD_PROXY/https://github.com"
    else
        UV_INSTALLER_GITHUB_BASE_URL="https://github.com"
    fi
    export UV_INSTALLER_GITHUB_BASE_URL
fi

say "正在安装 uv $APP_VERSION..."
if ! sh "$INSTALLER_PATH" "$@"; then
    if [ "$AUTO_BASE_URL" = "1" ] && [ "$UV_INSTALLER_GITHUB_BASE_URL" != "https://github.com" ]; then
        say "镜像安装失败，改用 GitHub 直连重试..."
        export UV_INSTALLER_GITHUB_BASE_URL="https://github.com"
        if ! sh "$INSTALLER_PATH" "$@"; then
            die "official uv installer failed"
        fi
    else
        die "official uv installer failed"
    fi
fi

if [ "$AUTO_BASE_URL" = "1" ] && [ "$UV_INSTALLER_GITHUB_BASE_URL" = "https://github.com" ]; then
    CONFIG_PROXY=""
else
    CONFIG_PROXY="$DOWNLOAD_PROXY"
fi

if [ -n "$CONFIG_PROXY" ]; then
    PYTHON_INSTALL_MIRROR="$CONFIG_PROXY/https://github.com/astral-sh/python-build-standalone/releases/download"
else
    PYTHON_INSTALL_MIRROR="https://github.com/astral-sh/python-build-standalone/releases/download"
fi

if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    UV_CONFIG_DIR="$XDG_CONFIG_HOME/uv"
elif [ -n "${HOME:-}" ]; then
    UV_CONFIG_DIR="$HOME/.config/uv"
else
    say "未检测到 HOME，跳过 uv.toml 配置。"
    exit 0
fi

UV_CONFIG_PATH="$UV_CONFIG_DIR/uv.toml"
mkdir -p "$UV_CONFIG_DIR" || die "failed to create configuration directory: $UV_CONFIG_DIR"

if [ -e "$UV_CONFIG_PATH" ]; then
    say "检测到已有配置文件，保留原配置: $UV_CONFIG_PATH"
else
    printf "python-install-mirror = \"%s\"\n\n[[index]]\nurl = \"%s\"\ndefault = true\n" \
        "$PYTHON_INSTALL_MIRROR" "$PYPI_MIRROR" >"$UV_CONFIG_PATH"
    say "✅ 配置完成。镜像设置如下:"
    if [ -n "$CONFIG_PROXY" ]; then
        say "   - Python 下载代理: $CONFIG_PROXY"
    else
        say "   - Python 下载源: GitHub 直连"
    fi
    say "   - PyPI 镜像源: $PYPI_MIRROR"
    say "   - uv 版本: $APP_VERSION"
    say "   - 配置文件路径: $UV_CONFIG_PATH"
fi
