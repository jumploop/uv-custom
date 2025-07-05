#!/bin/sh
#
# Smart, Cross-Platform Custom UV Installer Generator (CI/CD Edition)
#
# This script fetches official installers from GitHub releases based on a
# version tag, customizes them, and prepares them for release.
# It reads the download proxy from the DOWNLOAD_PROXY environment variable.
#

set -e

# --- Global Configuration ---
# Use DOWNLOAD_PROXY from environment, with a fallback default.
DOWNLOAD_PROXY="${UV_DOWNLOAD_PROXY:-https://ghfast.top}"
PYPI_MIRROR="${UV_PYPI_MIRROR:-https://pypi.tuna.tsinghua.edu.cn/simple}"
UV_REPO="astral-sh/uv"

# --- Helper Functions ---
say() {
    echo "› $1"
}

fetch_file() {
    local url="$1"
    local dest="$2"
    say "Fetching $url..."
    if ! curl -#fL "$url" -o "$dest"; then
        echo "Error: Failed to fetch $url" >&2
        exit 1
    fi
}

# --- Generator for Linux/macOS (Shell Script) ---
generate_shell_installer() {
    local version="$1"
    say "Generating custom shell installer for version $version..."
    local src_url="https://github.com/$UV_REPO/releases/download/$version/uv-installer.sh"
    local tmp_installer=$(mktemp)
    local dest_installer="uv-installer-custom.sh"

    fetch_file "$src_url" "$tmp_installer"

    awk -v proxy_url="$DOWNLOAD_PROXY" -v pypi_mirror="$PYPI_MIRROR" '
    /^(INSTALLER_BASE_URL=)/ {
        print "# --- Customization: Allow overriding download proxy via UV_DOWNLOAD_PROXY env var ---"
        print "_UV_DOWNLOAD_PROXY_URL=\"${UV_DOWNLOAD_PROXY:-" proxy_url "}\""
        print "INSTALLER_BASE_URL=\"${_UV_DOWNLOAD_PROXY_URL}/https://github.com/astral-sh/uv/releases/download\""
        print "# --- Customization End ---"
        next
    }
    /say "everything\x27s installed!"/ {
        print ""
        print "    # --- Customization Start: Add default PyPI and Python download mirrors ---"
        print "    say \"Configuring default PyPI and Python download mirrors...\""
        print "    local _uv_config_dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/uv\""
        print "    ensure mkdir -p \"$_uv_config_dir\""
        print "    _UV_DOWNLOAD_PROXY_URL_FOR_CONFIG=\"${UV_DOWNLOAD_PROXY:-" proxy_url "}\""
        print "    _UV_PYPI_MIRROR_URL=\"${UV_PYPI_MIRROR:-" pypi_mirror "}\""
        print "    _UV_PYTHON_INSTALL_MIRROR_URL=\"${_UV_DOWNLOAD_PROXY_URL_FOR_CONFIG}/https://github.com/astral-sh/python-build-standalone/releases/download\""
        print "    printf \"python-install-mirror = \\\"%s\\\"\\n\\n[[index]]\\nurl = \\\"%s\\\"\\ndefault = true\\n\" \"$_UV_PYTHON_INSTALL_MIRROR_URL\" \"$_UV_PYPI_MIRROR_URL\" > \"$_uv_config_dir/uv.toml\""
        print "    say \"Default mirrors configured at: $_uv_config_dir/uv.toml\""
        print "    # --- Customization End ---"
        print ""
    }
    { print }
    ' "$tmp_installer" > "$dest_installer"

    rm "$tmp_installer"
    chmod +x "$dest_installer"
    say "Successfully created custom installer: $dest_installer"
}

# --- Generator for Windows (PowerShell Script) ---
generate_powershell_installer() {
    local version="$1"
    say "Generating custom PowerShell installer for version $version..."
    local src_url="https://github.com/$UV_REPO/releases/download/$version/uv-installer.ps1"
    local tmp_installer=$(mktemp)
    local dest_installer="uv-installer-custom.ps1"

    fetch_file "$src_url" "$tmp_installer"

    awk -v proxy_url="$DOWNLOAD_PROXY" -v pypi_mirror="$PYPI_MIRROR" '
    /^\s*\$installer_base_url\s*=\s*".*github\.com"/ {
        print "  # --- Customization: Allow overriding download proxy via $env:UV_DOWNLOAD_PROXY ---"
        print "  if ($env:UV_DOWNLOAD_PROXY) { $uv_download_proxy_url = $env:UV_DOWNLOAD_PROXY } else { $uv_download_proxy_url = \"" proxy_url "\" }"
        print "  $installer_base_url = \"$uv_download_proxy_url/https://github.com/astral-sh/uv/releases/download\""
        print "  # --- Customization End ---"
        next
    }
    /^\s*Write-Information "everything\x27s installed!"/ {
        print "  # --- Customization Start: Add default PyPI and Python download mirrors ---"
        print "  Write-Information \"Configuring default PyPI and Python download mirrors...\""
        print ""
        print "  if ($env:UV_PYPI_MIRROR) { $uv_pypi_mirror_url = $env:UV_PYPI_MIRROR } else { $uv_pypi_mirror_url = \"" pypi_mirror "\" }"
        print "  $python_install_mirror_url = \"$uv_download_proxy_url/https://github.com/astral-sh/python-build-standalone/releases/download\""
        print ""
        print "  $uv_config_dir = Join-Path $env:APPDATA \"uv\""
        print "  if (-not (Test-Path $uv_config_dir)) {"
        print "    New-Item -Path $uv_config_dir -ItemType Directory -Force | Out-Null"
        print "  }"
        print "  $toml_content = @\""
        print "python-install-mirror = \"$python_install_mirror_url\""
        print ""
        print "[[index]]"
        print "url = \"$uv_pypi_mirror_url\""
        print "default = true"
        print "\"@"
        print "  $uv_config_path = Join-Path $uv_config_dir \"uv.toml\""
        print "  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False"
        print "  [IO.File]::WriteAllText($uv_config_path, $toml_content, $Utf8NoBomEncoding)"
        print "  Write-Information \"Default mirrors configured at: $uv_config_path\""
        print "  # --- Customization End ---"
        print ""
    }
    { print }
    ' "$tmp_installer" > "$dest_installer"

    rm "$tmp_installer"
    say "Successfully created custom installer: $dest_installer"
}

# --- Main Execution ---
if [ -z "$1" ]; then
    echo "Error: A version tag must be provided as the first argument." >&2
    echo "Usage: $0 <version_tag>" >&2
    exit 1
fi

VERSION_TAG="$1"

say "Starting custom installer generation for uv version: $VERSION_TAG"
generate_shell_installer "$VERSION_TAG"
generate_powershell_installer "$VERSION_TAG"
say "All installers generated successfully." 