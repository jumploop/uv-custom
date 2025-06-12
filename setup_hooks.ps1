#Requires -Version 5.1
<#
.SYNOPSIS
    UV + Conda/Mamba Environment Hook Injector for Windows PowerShell.
.DESCRIPTION
    This script injects a hook into the PowerShell profile to automatically
    sync the UV_PROJECT_ENVIRONMENT variable with the active Conda/Mamba
    environment. It is idempotent and safe to run multiple times.
.NOTES
    Author: Wangnov
#>

function Inject-UvCondaHook {
    [CmdletBinding()]
    param()

    Write-Host "› Setting up UV + Conda/Mamba Hook for PowerShell..."

    # Determine the correct profile path. $PROFILE is the simplest way.
    $configFile = $PROFILE
    $marker = "# UV-CONDA-HOOK-POWERSHELL-START"

    # Ensure the directory for the profile exists.
    $configDir = Split-Path -Path $configFile -Parent
    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    # Ensure the profile file itself exists.
    if (-not (Test-Path -Path $configFile)) {
        New-Item -ItemType File -Path $configFile -Force | Out-Null
    }

    # Check if the hook is already present.
    if (Select-String -Path $configFile -Pattern $marker -Quiet) {
        Write-Host "› PowerShell hook already exists in $configFile. Skipping."
    } else {
        Write-Host "› Injecting PowerShell hook into $configFile..."
        # Define the code block to be injected.
        $codeBlock = @"

$marker
# Auto-sync UV_PROJECT_ENVIRONMENT with Conda/Mamba environment (PowerShell).
# This function is registered to run before each prompt is displayed.
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -Action {
    if (Test-Path Env:CONDA_PREFIX) {
        if (-not (Test-Path Env:UV_PROJECT_ENVIRONMENT) -or (`$env:UV_PROJECT_ENVIRONMENT -ne `$env:CONDA_PREFIX)) {
            `$env:UV_PROJECT_ENVIRONMENT = `$env:CONDA_PREFIX
        }
    } else {
        if (Test-Path Env:UV_PROJECT_ENVIRONMENT) {
            Remove-Item -ErrorAction SilentlyContinue Env:UV_PROJECT_ENVIRONMENT
        }
    }
}
# UV-CONDA-HOOK-POWERSHELL-END
"@
        # Append the code block to the profile file.
        Add-Content -Path $configFile -Value $codeBlock
        Write-Host "› Successfully injected hook for PowerShell."
    }
}

# --- Main Execution ---
Write-Host "--- Setting up UV + Conda/Mamba Hooks for Windows ---"
Inject-UvCondaHook
Write-Host "---------------------------------------------------"
Write-Host "Setup complete. Please restart your PowerShell session to apply changes."