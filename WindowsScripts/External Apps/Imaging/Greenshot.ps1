# NAME: Greenshot
# DESCRIPTION: Installs Greenshot via WinGet. Use -Undo to uninstall.
# UNDOABLE: Yes
# UNDO_DESC: Uninstalls Greenshot using WinGet.
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$AppName = "Greenshot"
$PackageIds = @("Greenshot.Greenshot")
$Source = "winget"

# Set up logging
$LogFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Level - $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

function Ensure-WinGet {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet and retry."
    }
}

function Install-App {
    foreach ($id in $PackageIds) {
        Write-Log "Installing $AppName ($id) via WinGet..." "INFO"
        $args = @(
            "install",
            "--id", $id,
            "--source", $Source,
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "$AppName installed successfully." "INFO"
            return
        }
        Write-Log "WinGet failed with exit code $($process.ExitCode) for $id." "WARN"
    }
    throw "Failed to install $AppName with all configured package IDs."
}

function Uninstall-App {
    foreach ($id in $PackageIds) {
        Write-Log "Uninstalling $AppName ($id) via WinGet..." "INFO"
        $args = @(
            "uninstall",
            "--id", $id,
            "--source", $Source,
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "$AppName uninstalled successfully." "INFO"
            return
        }
        Write-Log "WinGet failed with exit code $($process.ExitCode) for $id." "WARN"
    }
    throw "Failed to uninstall $AppName with all configured package IDs."
}

try {
    Ensure-WinGet
    if ($Undo) {
        Uninstall-App
    } else {
        Install-App
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
