#!/bin/sh
#
# Render the stable uv installer wrappers for the requested upstream version.
# The generated scripts download the matching official installer at runtime.

set -eu

DOWNLOAD_PROXY="${UV_DOWNLOAD_PROXY:-https://gh-proxy.com}"
PYPI_MIRROR="${UV_PYPI_MIRROR:-https://pypi.tuna.tsinghua.edu.cn/simple}"
TEMPLATES_DIR="templates"

say() {
    printf '› %s\n' "$1"
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

render_template() {
    _template="$1"
    _destination="$2"

    [ -f "$_template" ] || die "template not found: $_template"

    sed \
        -e "s|__DEFAULT_VERSION__|$VERSION_TAG|g" \
        -e "s|__DOWNLOAD_PROXY__|$DOWNLOAD_PROXY_ESCAPED|g" \
        -e "s|__PYPI_MIRROR__|$PYPI_MIRROR_ESCAPED|g" \
        "$_template" >"$_destination"

    if grep -Eq '__DEFAULT_VERSION__|__DOWNLOAD_PROXY__|__PYPI_MIRROR__' "$_destination"; then
        die "unresolved placeholder in $_destination"
    fi
}

generate_shell_installer() {
    _destination="uv-installer-custom.sh"
    say "Generating stable shell wrapper for uv $VERSION_TAG..."
    render_template "$TEMPLATES_DIR/uv_installer_wrapper.sh" "$_destination"
    sh -n "$_destination"
    chmod +x "$_destination"
    say "Successfully created custom installer: $_destination"
}

generate_powershell_installer() {
    _destination="uv-installer-custom.ps1"
    say "Generating stable PowerShell wrapper for uv $VERSION_TAG..."
    render_template "$TEMPLATES_DIR/uv_installer_wrapper.ps1" "$_destination"
    if LC_ALL=C grep -q '[^ -~]' "$_destination"; then
        die "PowerShell wrapper must remain ASCII-only for Windows PowerShell 5.1"
    fi
    say "Successfully created custom installer: $_destination"
}

VERSION_TAG="${UV_VERSION:-${1:-}}"
[ -n "$VERSION_TAG" ] ||
    die "A version tag is required via UV_VERSION or the first argument."

case "$VERSION_TAG" in
    [0-9]*)
        ;;
    *)
        die "invalid version tag: $VERSION_TAG"
        ;;
esac

case "$VERSION_TAG" in
    *[!0-9A-Za-z._-]*)
        die "invalid version tag: $VERSION_TAG"
        ;;
esac

DOWNLOAD_PROXY_ESCAPED=$(escape_sed_replacement "$DOWNLOAD_PROXY")
PYPI_MIRROR_ESCAPED=$(escape_sed_replacement "$PYPI_MIRROR")

say "Starting custom installer generation for uv version: $VERSION_TAG"
generate_shell_installer
generate_powershell_installer
say "All installers generated successfully."
