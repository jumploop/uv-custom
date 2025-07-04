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
DOWNLOAD_PROXY="${DOWNLOAD_PROXY:-https://ghfast.top}"
PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
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
    /INSTALLER_BASE_URL=.*github\.com/ {
        sub("https://github.com", proxy_url "/https://github.com")
    }
    {
        gsub("curl -sSfL", "curl -#SfL")
    }
    /say "everything['"'"']s installed!"/ {
        print ""
        print "    # --- Customization Start: Add default PyPI and Python download mirrors ---"
        print "    say \"Configuring default PyPI and Python download mirrors...\""
        print "    local _uv_config_dir=\"${XDG_CONFIG_HOME:-$HOME/.config}/uv\""
        print "    ensure mkdir -p \"$_uv_config_dir\""
        print "    printf \"python-install-mirror = \\\"" proxy_url "/https://github.com/astral-sh/python-build-standalone/releases/download\\\"\\n\\n[[index]]\\nurl = \\\"" pypi_mirror "\\\"\\ndefault = true\\n\" > \"$_uv_config_dir/uv.toml\""
        print "    say \"Default mirrors configured.\""
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
    /^\s*\$installer_base_url = "https:\/\/github\.com"/ {
        sub("https://github.com", proxy_url "/https://github.com")
    }
    /^\s*Write-Information "everything\x27s installed!"/ {
        print "  # --- Customization Start: Add default PyPI and Python download mirrors ---"
        print "  Write-Information \"Configuring default PyPI and Python download mirrors...\""
        print "  $uv_config_dir = Join-Path $env:APPDATA \"uv\""
        print "  if (-not (Test-Path $uv_config_dir)) {"
        print "    New-Item -Path $uv_config_dir -ItemType Directory -Force | Out-Null"
        print "  }"
        print "  $toml_content = @\""
        print "python-install-mirror = \"" proxy_url "/https://github.com/astral-sh/python-build-standalone/releases/download\""
        print ""
        print "[[index]]"
        print "url = \"" pypi_mirror "\""
        print "default = true"
        print "\"@"
        print "  $uv_config_path = Join-Path $uv_config_dir \"uv.toml\""
        print "  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False"
        print "  [IO.File]::WriteAllLines($uv_config_path, $toml_content, $Utf8NoBomEncoding)"
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