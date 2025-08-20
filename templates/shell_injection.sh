    #!/bin/sh
    # This script block is injected by create_custom_uv_installer.sh

    # --- Customization Start: Add default PyPI and Python download mirrors ---
    say "正在配置默认的 PyPI 和 Python 下载镜像..."
    local _uv_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/uv"
    ensure mkdir -p "$_uv_config_dir"
    _UV_DOWNLOAD_PROXY_URL_FOR_CONFIG="${UV_DOWNLOAD_PROXY:-__DOWNLOAD_PROXY__}"
    _UV_PYPI_MIRROR_URL="${UV_PYPI_MIRROR:-__PYPI_MIRROR__}"
    _UV_PYTHON_INSTALL_MIRROR_URL="${_UV_DOWNLOAD_PROXY_URL_FOR_CONFIG}/https://github.com/astral-sh/python-build-standalone/releases/download"
    printf "python-install-mirror = \"%s\"\\n\\n[[index]]\\nurl = \"%s\"\\ndefault = true\\n" "$_UV_PYTHON_INSTALL_MIRROR_URL" "$_UV_PYPI_MIRROR_URL" > "$_uv_config_dir/uv.toml"
    say "✅ 配置完成。镜像设置如下:"
    say "   - Python 下载代理: $_UV_DOWNLOAD_PROXY_URL_FOR_CONFIG"
    say "   - PyPI 镜像源: $_UV_PYPI_MIRROR_URL"
    say "   - uv 版本: $APP_VERSION"
    say "   - 配置文件路径: $_uv_config_dir/uv.toml"
    # --- Customization End --- 