# NAME: Install GitHub CLI
# DESCRIPTION: Installs GitHub CLI via WinGet. Use -Undo to uninstall.
# UNDOABLE: Yes
# UNDO_DESC: Uninstalls GitHub CLI using WinGet.
# LINK: https://github.com/fleschutz/PowerShell
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$AppName = "GitHub CLI"
$PackageId = "GitHub.cli"
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
    Write-Log "Installing $AppName via WinGet..." "INFO"
    $args = @(
        "install",
        "--id", $PackageId,
        "--source", $Source,
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
}

function Uninstall-App {
    Write-Log "Uninstalling $AppName via WinGet..." "INFO"
    $args = @(
        "uninstall",
        "--id", $PackageId,
        "--source", $Source,
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
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
