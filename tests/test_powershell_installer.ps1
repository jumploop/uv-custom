param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,
    [string]$OldVersion = '0.7.19',
    [switch]$SkipDirectFallback
)

$ErrorActionPreference = 'Stop'
$savedEnvironment = @{}
$environmentNames = @(
    'APPDATA',
    'XDG_CONFIG_HOME',
    'UV_VERSION',
    'UV_DOWNLOAD_PROXY',
    'UV_PYPI_MIRROR',
    'UV_UNMANAGED_INSTALL',
    'UV_DISABLE_UPDATE',
    'UV_NO_MODIFY_PATH',
    'INSTALLER_PRINT_QUIET'
)

foreach ($name in $environmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('uv-custom-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    $env:APPDATA = Join-Path $tempDir 'appdata'
    Remove-Item Env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue
    Remove-Item Env:UV_VERSION -ErrorAction SilentlyContinue
    Remove-Item Env:UV_DOWNLOAD_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:UV_PYPI_MIRROR -ErrorAction SilentlyContinue
    $env:UV_DISABLE_UPDATE = '1'
    $env:UV_NO_MODIFY_PATH = '1'
    $env:INSTALLER_PRINT_QUIET = '1'

    $env:UV_UNMANAGED_INSTALL = Join-Path $tempDir 'current'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallerPath
    if ($LASTEXITCODE -ne 0) {
        throw "default installer exited with code $LASTEXITCODE"
    }

    $currentUv = Join-Path $env:UV_UNMANAGED_INSTALL 'uv.exe'
    $currentVersion = & $currentUv --version
    if ($LASTEXITCODE -ne 0 -or $currentVersion -notmatch "uv $([regex]::Escape($ExpectedVersion)) ") {
        throw "default install did not produce uv $ExpectedVersion"
    }

    $configPath = Join-Path $env:APPDATA 'uv/uv.toml'
    if (-not (Test-Path $configPath)) {
        throw 'uv.toml was not created'
    }
    $config = Get-Content -LiteralPath $configPath -Raw
    if ($config -notmatch 'python-install-mirror = ' -or $config -notmatch '\[\[index\]\]') {
        throw 'uv.toml does not contain the expected mirror configuration'
    }

    Set-Content -LiteralPath $configPath -Value 'sentinel' -NoNewline
    $env:UV_VERSION = $OldVersion
    if ($SkipDirectFallback) {
        Remove-Item Env:UV_DOWNLOAD_PROXY -ErrorAction SilentlyContinue
    } else {
        $env:UV_DOWNLOAD_PROXY = 'http://127.0.0.1:9'
    }
    $env:UV_UNMANAGED_INSTALL = Join-Path $tempDir 'old'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallerPath
    if ($LASTEXITCODE -ne 0) {
        throw "version override installer exited with code $LASTEXITCODE"
    }

    $oldUv = Join-Path $env:UV_UNMANAGED_INSTALL 'uv.exe'
    $oldVersionOutput = & $oldUv --version
    if ($LASTEXITCODE -ne 0 -or $oldVersionOutput -notmatch "uv $([regex]::Escape($OldVersion)) ") {
        throw 'version override or direct-download fallback failed'
    }

    if ((Get-Content -LiteralPath $configPath -Raw) -ne 'sentinel') {
        throw 'existing uv.toml was overwritten'
    }

    Write-Host "PowerShell installer tests passed: $ExpectedVersion and $OldVersion"
} finally {
    foreach ($name in $environmentNames) {
        $value = $savedEnvironment[$name]
        if ($null -eq $value) {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        } else {
            Set-Item "Env:$name" $value
        }
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
