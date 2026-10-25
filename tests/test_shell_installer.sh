#!/bin/sh

set -eu

INSTALLER_PATH="${1:?installer path is required}"
EXPECTED_VERSION="${2:?expected version is required}"
OLD_VERSION="${OLD_VERSION:-0.7.19}"

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

assert_uv_version() {
    _uv_path="$1"
    _expected="$2"
    _output=$("$_uv_path" --version) || die "failed to run $_uv_path"
    set -- $_output
    [ "$1" = "uv" ] && [ "$2" = "$_expected" ] ||
        die "expected uv $_expected, got: $_output"
}

TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

export HOME="$TMP_DIR/home"
export XDG_CONFIG_HOME="$TMP_DIR/config"
export UV_DISABLE_UPDATE=1
export UV_NO_MODIFY_PATH=1
export INSTALLER_PRINT_QUIET=1
mkdir -p "$HOME"

unset UV_VERSION
unset UV_DOWNLOAD_PROXY
UV_UNMANAGED_INSTALL="$TMP_DIR/current" sh "$INSTALLER_PATH" --quiet
assert_uv_version "$TMP_DIR/current/uv" "$EXPECTED_VERSION"

CONFIG_PATH="$XDG_CONFIG_HOME/uv/uv.toml"
[ -f "$CONFIG_PATH" ] || die "uv.toml was not created"
grep -F 'python-install-mirror = ' "$CONFIG_PATH" >/dev/null ||
    die "python mirror is missing from uv.toml"
grep -F '[[index]]' "$CONFIG_PATH" >/dev/null ||
    die "PyPI index is missing from uv.toml"

printf 'sentinel\n' >"$CONFIG_PATH"
export UV_VERSION="$OLD_VERSION"
if [ "${TEST_DIRECT_FALLBACK:-1}" = "1" ]; then
    export UV_DOWNLOAD_PROXY="http://127.0.0.1:9"
else
    unset UV_DOWNLOAD_PROXY
fi
UV_UNMANAGED_INSTALL="$TMP_DIR/old" sh "$INSTALLER_PATH" --quiet
assert_uv_version "$TMP_DIR/old/uv" "$OLD_VERSION"

[ "$(cat "$CONFIG_PATH")" = "sentinel" ] ||
    die "existing uv.toml was overwritten"

printf 'shell installer tests passed: %s\n' "$EXPECTED_VERSION and $OLD_VERSION"
