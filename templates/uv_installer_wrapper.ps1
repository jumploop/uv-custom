# Stable wrapper for the official uv installer.
# It downloads the installer that matches UV_VERSION, applies the mirror
# settings, and leaves existing uv.toml files untouched.

$previousErrorActionPreference = $ErrorActionPreference
$previousGithubBaseUrl = $env:UV_INSTALLER_GITHUB_BASE_URL
$ErrorActionPreference = 'Stop'

$appVersion = if ($env:UV_VERSION) { $env:UV_VERSION } else { '__DEFAULT_VERSION__' }
$downloadProxy = if ($env:UV_DOWNLOAD_PROXY) { $env:UV_DOWNLOAD_PROXY } else { '__DOWNLOAD_PROXY__' }
$pypiMirror = if ($env:UV_PYPI_MIRROR) { $env:UV_PYPI_MIRROR } else { '__PYPI_MIRROR__' }
$downloadProxy = $downloadProxy.TrimEnd('/')

if ($appVersion -notmatch '^[0-9][0-9A-Za-z._-]*$') {
    throw "invalid UV_VERSION: $appVersion"
}

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("uv-custom-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$installerPath = Join-Path $tempDir 'uv-installer.ps1'
$installerUrl = "https://github.com/astral-sh/uv/releases/download/$appVersion/uv-installer.ps1"

function Get-RemoteFile([string]$Url, [string]$Destination) {
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri "$downloadProxy/$Url" -OutFile $Destination
        return 'proxy'
    } catch {
        Write-Host '> Download proxy failed; falling back to GitHub.'
    }

    Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri $Url -OutFile $Destination
    return 'direct'
}

function Invoke-OfficialInstaller([string[]]$InstallerArgs) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerPath @InstallerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "official uv installer exited with code $LASTEXITCODE"
    }
}

try {
    Write-Host "> Downloading the official installer for uv $appVersion..."
    $downloadSource = Get-RemoteFile $installerUrl $installerPath

    $autoBaseUrl =
        [string]::IsNullOrEmpty($env:UV_INSTALLER_GITHUB_BASE_URL) -and
        [string]::IsNullOrEmpty($env:UV_INSTALLER_GHE_BASE_URL) -and
        [string]::IsNullOrEmpty($env:INSTALLER_DOWNLOAD_URL) -and
        [string]::IsNullOrEmpty($env:UV_DOWNLOAD_URL)

    if ($autoBaseUrl) {
        if ($downloadSource -eq 'proxy') {
            $env:UV_INSTALLER_GITHUB_BASE_URL = "$downloadProxy/https://github.com"
        } else {
            $env:UV_INSTALLER_GITHUB_BASE_URL = 'https://github.com'
        }
    }

    Write-Host "> Installing uv $appVersion..."
    try {
        Invoke-OfficialInstaller -InstallerArgs $args
    } catch {
        if ($autoBaseUrl -and $env:UV_INSTALLER_GITHUB_BASE_URL -ne 'https://github.com') {
            Write-Host '> Mirror installation failed; retrying with GitHub...'
            $env:UV_INSTALLER_GITHUB_BASE_URL = 'https://github.com'
            Invoke-OfficialInstaller -InstallerArgs $args
        } else {
            throw
        }
    }

    $configProxy = if ($autoBaseUrl -and $env:UV_INSTALLER_GITHUB_BASE_URL -eq 'https://github.com') {
        ''
    } else {
        $downloadProxy
    }

    if ($configProxy) {
        $pythonInstallMirror = "$configProxy/https://github.com/astral-sh/python-build-standalone/releases/download"
    } else {
        $pythonInstallMirror = 'https://github.com/astral-sh/python-build-standalone/releases/download'
    }

    if ($env:XDG_CONFIG_HOME) {
        $uvConfigDir = Join-Path $env:XDG_CONFIG_HOME 'uv'
    } elseif ($env:APPDATA) {
        $uvConfigDir = Join-Path $env:APPDATA 'uv'
    } else {
        Write-Host '> APPDATA is not set; skipping uv.toml configuration.'
        return
    }

    New-Item -ItemType Directory -Path $uvConfigDir -Force | Out-Null
    $uvConfigPath = Join-Path $uvConfigDir 'uv.toml'
    if (Test-Path $uvConfigPath) {
        Write-Host "> Existing configuration preserved: $uvConfigPath"
    } else {
        $tomlContent = @"
python-install-mirror = "$pythonInstallMirror"

[[index]]
url = "$pypiMirror"
default = true
"@
        [IO.File]::WriteAllText($uvConfigPath, $tomlContent, [Text.UTF8Encoding]::new($false))
        Write-Host '> Configuration complete. Mirror settings:'
        if ($configProxy) {
            Write-Host ">    - Python download proxy: $configProxy"
        } else {
            Write-Host '>    - Python download source: GitHub direct'
        }
        Write-Host ">    - PyPI mirror: $pypiMirror"
        Write-Host ">    - uv version: $appVersion"
        Write-Host ">    - Configuration path: $uvConfigPath"
    }
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
    $env:UV_INSTALLER_GITHUB_BASE_URL = $previousGithubBaseUrl
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
