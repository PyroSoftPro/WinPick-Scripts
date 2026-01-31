# NAME: Open Windows Terminal
# DESCRIPTION: Launches Windows Terminal (wt.exe).
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/fleschutz/PowerShell
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
    $wt = Get-Command "wt.exe" -ErrorAction SilentlyContinue
    if (-not $wt) {
        throw "Windows Terminal (wt.exe) not found. Install Windows Terminal and retry."
    }

    Start-Process -FilePath $wt.Source
    Write-Log "Windows Terminal launched." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
