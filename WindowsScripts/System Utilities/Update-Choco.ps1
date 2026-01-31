# NAME: Update Chocolatey Packages
# DESCRIPTION: Upgrades all outdated Chocolatey packages.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/stevencohn/WindowsPowerShell
#

param (
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

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

try {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "Chocolatey is not installed. Install it and retry."
    }

    Write-Log "Upgrading all Chocolatey packages..." "INFO"
    choco upgrade all -y | Out-Null
    Write-Log "Chocolatey package upgrade completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
