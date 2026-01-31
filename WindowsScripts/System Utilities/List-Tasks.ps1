# NAME: List Scheduled Tasks
# DESCRIPTION: Lists Windows scheduled tasks with path and state.
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
    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        Get-ScheduledTask |
            Select-Object TaskName, TaskPath, State |
            Sort-Object TaskPath, TaskName |
            ForEach-Object { $_ }
    } else {
        Write-Log "Get-ScheduledTask not available; falling back to schtasks." "WARN"
        schtasks /Query /FO LIST /V
    }

    Write-Log "Listed scheduled tasks." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
