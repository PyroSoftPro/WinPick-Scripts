# NAME: Clear Temp Files
# DESCRIPTION: Clears temp files from user and system temp folders.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$TempPaths = @(
    $env:TEMP,
    "$env:WINDIR\Temp",
    "$env:LOCALAPPDATA\Temp"
) | Where-Object { $_ }

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
    foreach ($path in $TempPaths) {
        if (-not (Test-Path -Path $path)) {
            continue
        }

        Write-Log "Clearing temp folder: $path" "INFO"
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Temp folders cleared." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
