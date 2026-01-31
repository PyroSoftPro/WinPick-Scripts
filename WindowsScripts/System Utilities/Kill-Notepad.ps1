# NAME: Kill Notepad
# DESCRIPTION: Closes all running Notepad processes.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/davidbombal/Powershell
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
    $processes = Get-Process -Name "notepad" -ErrorAction SilentlyContinue
    if (-not $processes) {
        Write-Log "Notepad is not running." "INFO"
    } else {
        $processes | Stop-Process -Force
        Write-Log "Notepad processes terminated." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
