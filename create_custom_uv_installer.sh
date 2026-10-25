#!/bin/sh
#
# Smart, Cross-Platform Custom UV Installer Generator (CI/CD Edition)
#
# This script fetches official installers from GitHub releases based on a
# version tag, customizes them using templates, and prepares them for release.
# It reads the download proxy from the UV_DOWNLOAD_PROXY environment variable.
#

set -eu

# --- Global Configuration ---
# Use UV_DOWNLOAD_PROXY and UV_PYPI_MIRROR from environment, with fallback defaults.
DOWNLOAD_PROXY="${UV_DOWNLOAD_PROXY:-https://gh-proxy.com}"
PYPI_MIRROR="${UV_PYPI_MIRROR:-https://pypi.tuna.tsinghua.edu.cn/simple}"
UV_REPO="astral-sh/uv"
TEMPLATES_DIR="templates"

# --- Helper Functions ---
say() {
    echo "› $1"
}

fetch_file() {
    local url="$1"
    local dest="$2"
    local proxied_url="$DOWNLOAD_PROXY/$url"

    say "Fetching $proxied_url..."
    if command -v curl >/dev/null 2>&1; then
        curl -#fL --retry 3 --retry-delay 2 --connect-timeout 20 "$proxied_url" -o "$dest" && return
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 --timeout=20 "$proxied_url" -O "$dest" && return
    else
        echo "Error: curl or wget is required" >&2
        exit 1
    fi

    say "Proxy failed, retrying from GitHub..."
    if command -v curl >/dev/null 2>&1; then
        curl -#fL --retry 3 --retry-delay 2 --connect-timeout 20 "$url" -o "$dest"
    else
        wget -q --tries=3 --timeout=20 "$url" -O "$dest"
    fi
}

inject_before() {
    local file="$1"
    local anchor="$2"
    local template="$3"
    local temp
    temp=$(mktemp)

    if ! awk -v anchor="$anchor" -v template="$template" '
        index($0, anchor) && !inserted {
            while ((getline line < template) > 0) print line
            close(template)
            inserted = 1
        }
        { print }
        END { exit !inserted }
    ' "$file" >"$temp"; then
        rm -f "$temp"
        echo "Error: injection anchor not found: $anchor" >&2
        return 1
    fi
    mv "$temp" "$file"
}

# --- Generator for Linux/macOS (Shell Script) ---
generate_shell_installer() {
    local version="$1"
    say "Generating custom shell installer for version $version..."
    local src_url="https://github.com/$UV_REPO/releases/download/$version/uv-installer.sh"
    local tmp_installer
    tmp_installer=$(mktemp)
    local dest_installer="uv-installer-custom.sh"

    fetch_file "$src_url" "$tmp_installer"

    # 1. Inject the proxy logic using sed
    sed -e "s|APP_VERSION=\"\([0-9\.]\+\)\"|APP_VERSION=\"\${UV_VERSION:-\\1}\"|" -e "s|astral-sh\/uv\/releases\/download\/$version|astral-sh\/uv\/releases\/download\/\$APP_VERSION|g" -e \
        "s|\(\"release_type\":\"github\"\},\)\"version\":\".\+\"\}$|\1\"version\"\:\"\$APP_VERSION\"\}|" -e "
/^APP_VERSION=/a\\
\\
# --- Customization: Define runtime proxy URL ---\\
_UV_DOWNLOAD_PROXY_URL=\"\${UV_DOWNLOAD_PROXY:-$DOWNLOAD_PROXY}\"\\
UV_INSTALLER_GITHUB_BASE_URL=\"\${UV_INSTALLER_GITHUB_BASE_URL:-\${_UV_DOWNLOAD_PROXY_URL}/https://github.com}\"\\
# --- Customization End ---
" "$tmp_installer" >"$dest_installer"

    local template
    template=$(mktemp)
    sed -e "s|__DOWNLOAD_PROXY__|$DOWNLOAD_PROXY|g" \
        -e "s|__PYPI_MIRROR__|$PYPI_MIRROR|g" \
        "$TEMPLATES_DIR/shell_injection.sh" >"$template"
    inject_before "$dest_installer" "say \"everything's installed!\"" "$template"

    local checksum_template
    checksum_template=$(mktemp)
    sed "s|__GENERATED_VERSION__|$version|g" \
        "$TEMPLATES_DIR/shell_checksum.sh" >"$checksum_template"
    inject_before "$dest_installer" 'if [ -n "${_checksum_style:-}" ]; then' "$checksum_template"
    rm -f "$tmp_installer" "$template" "$checksum_template"

    grep -q 'UV_INSTALLER_GITHUB_BASE_URL=' "$dest_installer"
    grep -q 'failed to download checksum' "$dest_installer" || {
        echo "Error: checksum fallback was not injected into $dest_installer" >&2
        exit 1
    }
    grep -q '__DOWNLOAD_PROXY__\|__PYPI_MIRROR__\|__GENERATED_VERSION__' "$dest_installer" && {
        echo "Error: unresolved placeholder in $dest_installer" >&2
        exit 1
    }
    sh -n "$dest_installer"
    chmod +x "$dest_installer"
    say "Successfully created custom installer: $dest_installer"
}

# --- Generator for Windows (PowerShell Script) ---
generate_powershell_installer() {
    local version="$1"
    say "Generating custom PowerShell installer for version $version..."
    local src_url="https://github.com/$UV_REPO/releases/download/$version/uv-installer.ps1"
    local tmp_installer
    tmp_installer=$(mktemp)
    local dest_installer="uv-installer-custom.ps1"

    fetch_file "$src_url" "$tmp_installer"

    # 1. Inject the proxy logic using sed
    sed -e "
/^\$app_version/a\\
\\
# --- Customization: Define runtime proxy URL ---\\
if (\$env:UV_DOWNLOAD_PROXY) { \$uv_download_proxy_url = \$env:UV_DOWNLOAD_PROXY } else { \$uv_download_proxy_url = \"$DOWNLOAD_PROXY\" }\\
if (-not \$env:UV_INSTALLER_GITHUB_BASE_URL) { \$env:UV_INSTALLER_GITHUB_BASE_URL = \"\$uv_download_proxy_url/https://github.com\" }\\
# --- Customization End ---
" -e "s|$(grep "\$app_version = " "$tmp_installer")|if \(\$env:UV_VERSION\) \{ \$app_version = \$env:UV_VERSION \} else \{ \$app_version = \"$version\" \}|" -e "s|astral-sh/uv/releases/download/$version|astral-sh/uv/releases/download/\$app_version|g" -e "s|\(\"release_type\":\"github\"\},\)\"version\":\".\+\"\}$|\1\"version\"\:\"\$app_version\"\}|" "$tmp_installer" >"$dest_installer"

    local template
    template=$(mktemp)
    sed -e "s|__PYPI_MIRROR__|$PYPI_MIRROR|g" \
        "$TEMPLATES_DIR/powershell_injection.ps1" >"$template"
    inject_before "$dest_installer" "Write-Information \"everything's installed!\"" "$template"
    rm -f "$tmp_installer" "$template"

    grep -q 'UV_INSTALLER_GITHUB_BASE_URL' "$dest_installer"
    grep -q '__DOWNLOAD_PROXY__\|__PYPI_MIRROR__' "$dest_installer" && {
        echo "Error: unresolved placeholder in $dest_installer" >&2
        exit 1
    }
    say "Successfully created custom installer: $dest_installer"
}

# --- Main Execution ---
# Determine version from UV_VERSION env var, with fallback to the first argument
VERSION_TAG="${UV_VERSION:-${1:-}}"

if [ -z "$VERSION_TAG" ]; then
    echo "Error: A version tag must be provided via the UV_VERSION environment variable or as the first argument." >&2
    echo "Usage: UV_VERSION=<version_tag> $0" >&2
    echo "   or: $0 <version_tag>" >&2
    exit 1
fi

say "Starting custom installer generation for uv version: $VERSION_TAG"
generate_shell_installer "$VERSION_TAG"
generate_powershell_installer "$VERSION_TAG"
say "All installers generated successfully."
