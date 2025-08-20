  # This script block is injected by create_custom_uv_installer.sh
  # --- Customization: Define runtime proxy URL and override ArtifactDownloadUrl ---
  if ($env:UV_DOWNLOAD_PROXY) { $uv_download_proxy_url = $env:UV_DOWNLOAD_PROXY } else { $uv_download_proxy_url = "__DOWNLOAD_PROXY__" }
  $ArtifactDownloadUrl = "$uv_download_proxy_url/https://github.com/astral-sh/uv/releases/download/$app_version"


  # --- Customization: Add default PyPI and Python download mirrors ---
  Write-Information "正在配置默认的 PyPI 和 Python 下载镜像..."

  if ($env:UV_PYPI_MIRROR) { $uv_pypi_mirror_url = $env:UV_PYPI_MIRROR } else { $uv_pypi_mirror_url = "__PYPI_MIRROR__" }
  $python_install_mirror_url = "$uv_download_proxy_url/https://github.com/astral-sh/python-build-standalone/releases/download"

  $uv_config_dir = Join-Path $env:APPDATA "uv"
  if (-not (Test-Path $uv_config_dir)) {
    New-Item -Path $uv_config_dir -ItemType Directory -Force | Out-Null
  }
  $toml_content = @"
python-install-mirror = "$python_install_mirror_url"

[[index]]
url = "$uv_pypi_mirror_url"
default = true
"@
  $uv_config_path = Join-Path $uv_config_dir "uv.toml"
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [IO.File]::WriteAllText($uv_config_path, $toml_content, $Utf8NoBomEncoding)
  Write-Information "✅ 配置完成。镜像设置如下:"
  Write-Information "   - Python 下载代理: $uv_download_proxy_url"
  Write-Information "   - PyPI 镜像源: $uv_pypi_mirror_url"
  Write-Information "   - uv 版本: $app_version"
  Write-Information "   - 配置文件路径: $uv_config_path"
  # --- Customization End --- 