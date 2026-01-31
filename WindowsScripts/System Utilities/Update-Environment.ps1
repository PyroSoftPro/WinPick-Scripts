# NAME: Update Environment Variables
# DESCRIPTION: Reloads environment variables from registry into the current session.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
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
    $machineVars = [Environment]::GetEnvironmentVariables("Machine")
    $userVars = [Environment]::GetEnvironmentVariables("User")

    foreach ($key in $machineVars.Keys) {
        [Environment]::SetEnvironmentVariable($key, $machineVars[$key], "Process")
    }

    foreach ($key in $userVars.Keys) {
        [Environment]::SetEnvironmentVariable($key, $userVars[$key], "Process")
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")

    Write-Log "Environment variables refreshed for current session." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
