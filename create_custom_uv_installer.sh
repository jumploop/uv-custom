#!/bin/sh
#
# Smart, Cross-Platform Custom UV Installer Generator (CI/CD Edition)
#
# This script fetches official installers from GitHub releases based on a
# version tag, customizes them using templates, and prepares them for release.
# It reads the download proxy from the UV_DOWNLOAD_PROXY environment variable.
#

set -e

# --- Global Configuration ---
# Use UV_DOWNLOAD_PROXY and UV_PYPI_MIRROR from environment, with fallback defaults.
DOWNLOAD_PROXY="${UV_DOWNLOAD_PROXY:-https://ghfast.top}"
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
    # Use the proxy for downloads within this script as well
    local proxied_url
    proxied_url=$(echo "$url" | sed "s|https://github.com|$DOWNLOAD_PROXY/https://github.com|")
    say "Fetching $proxied_url..."
    if ! curl -#fL "$proxied_url" -o "$dest"; then
        echo "Error: Failed to fetch $proxied_url" >&2
        exit 1
    fi
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
    local tmp_proxied
    tmp_proxied=$(mktemp)
    sed -e "s|APP_VERSION=\"\([0-9\.]\+\)\"|APP_VERSION=\"\${UV_VERSION:-\\1}\"|" -e "s|astral-sh\/uv\/releases\/download\/.\+\"|astral-sh\/uv\/releases\/download\/\$APP_VERSION\"|" -e \
        "s|\(\"release_type\":\"github\"\},\)\"version\":\".\+\"\}$|\1\"version\"\:\"\$APP_VERSION\"\}|" -e "
/^# Look for GitHub Enterprise-style base URL first/a\\
\\
# --- Customization: Define runtime proxy URL ---\\
_UV_DOWNLOAD_PROXY_URL=\"\${UV_DOWNLOAD_PROXY:-$DOWNLOAD_PROXY}\"\\
# --- Customization End ---
" -e "
s|INSTALLER_BASE_URL=\"\${UV_INSTALLER_GITHUB_BASE_URL:-https://github.com}\"|INSTALLER_BASE_URL=\"\${UV_INSTALLER_GITHUB_BASE_URL:-\${_UV_DOWNLOAD_PROXY_URL}/https://github.com}\"|
" "$tmp_installer" >"$tmp_proxied"

    # 2. Rebuild the script with the mirror injection from template
    # Get the line number of the injection point
    local injection_line
    injection_line=$(grep -n "say \"everything's installed!\"" "$tmp_proxied" | cut -d: -f1)

    # Write content before the injection point
    head -n "$((injection_line - 1))" "$tmp_proxied" >"$dest_installer"

    # Inject the template content, replacing placeholders
    sed -e "s|__DOWNLOAD_PROXY__|$DOWNLOAD_PROXY|g" \
        -e "s|__PYPI_MIRROR__|$PYPI_MIRROR|g" \
        "$TEMPLATES_DIR/shell_injection.sh" >>"$dest_installer"

    # Write the injection point line itself
    echo "" >>"$dest_installer" # Add a newline for separation
    echo "    say \"everything's installed!\"" >>"$dest_installer"

    # Get the total lines of the file and write the rest of the original script
    local total_lines
    total_lines=$(wc -l <"$tmp_proxied")
    if [ "$injection_line" -lt "$total_lines" ]; then
        tail -n "+$((injection_line + 1))" "$tmp_proxied" >>"$dest_installer"
    fi

    rm "$tmp_installer" "$tmp_proxied"
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
    local tmp_proxied
    tmp_proxied=$(mktemp)
    sed -e "
/^\$app_version/a\\
\\
# --- Customization: Define runtime proxy URL ---\\
if (\$env:UV_DOWNLOAD_PROXY) { \$uv_download_proxy_url = \$env:UV_DOWNLOAD_PROXY } else { \$uv_download_proxy_url = \"https://ghfast.top\" }\\
# --- Customization End ---
" -e "
s|\$installer_base_url = \"https://github.com\"|\$installer_base_url = \"\$uv_download_proxy_url/https://github.com\"|
" -e "s|$(grep "\$app_version = " "$tmp_installer")|if \(\$env:UV_VERSION\) \{ \$app_version = \$env:UV_VERSION \} else \{ \$app_version = \"$version\" \}|" -e "s|\(\$installer_base_url\/astral-sh\/uv\/releases\/download\/\).\+\"|\1\$app_version\"|" -e "s|\(\"release_type\":\"github\"\},\)\"version\":\".\+\"\}$|\1\"version\"\:\"\$app_version\"\}|" "$tmp_installer" >"$tmp_proxied"

    # 2. Rebuild the script with all custom logic injected from the template
    local injection_line
    injection_line=$(grep -n "Write-Information \"everything's installed!\"" "$tmp_proxied" | head -n 1 | cut -d: -f1)

    # Write content before the injection point
    head -n "$((injection_line - 1))" "$tmp_proxied" >"$dest_installer"

    # Inject the template content, replacing placeholders
    sed -e "s|__PYPI_MIRROR__|$PYPI_MIRROR|g" \
        "$TEMPLATES_DIR/powershell_injection.ps1" >>"$dest_installer"

    # Add a newline for separation before appending the rest of the script
    echo "" >>"$dest_installer"
    # Write the rest of the original script
    tail -n "+$injection_line" "$tmp_proxied" >>"$dest_installer"

    rm "$tmp_installer" "$tmp_proxied"
    say "Successfully created custom installer: $dest_installer"
}

# --- Main Execution ---
# Determine version from UV_VERSION env var, with fallback to the first argument
VERSION_TAG="${UV_VERSION:-$1}"

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
