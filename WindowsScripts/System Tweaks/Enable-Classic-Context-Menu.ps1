# NAME: Enable Classic Context Menu
# DESCRIPTION: Restores the classic Windows context menu on Windows 11. Use -Undo to restore the modern menu.
# UNDOABLE: Yes
# UNDO_DESC: Removes the classic context menu registry override.
# LINK: https://github.com/WinTweakers/WindowsToolbox
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"

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
    if ($Undo) {
        if (Test-Path -Path $RegistryPath) {
            Remove-Item -Path $RegistryPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Classic context menu override removed." "INFO"
        } else {
            Write-Log "Classic context menu override not found; nothing to remove." "INFO"
        }
    } else {
        if (-not (Test-Path -Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $RegistryPath -Name "(default)" -Value "" -Force
        Write-Log "Classic context menu enabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
