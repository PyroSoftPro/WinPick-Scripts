# NAME: Enable God Mode
# DESCRIPTION: Creates the God Mode folder on the current user's desktop. Use -Undo to remove it.
# UNDOABLE: Yes
# UNDO_DESC: Removes the God Mode folder from the desktop.
# LINK: https://github.com/fleschutz/PowerShell
#

param (
    [switch]$Undo,
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
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $folderName = "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    $targetPath = Join-Path $desktopPath $folderName

    if ($Undo) {
        if (Test-Path -Path $targetPath) {
            Remove-Item -Path $targetPath -Force -ErrorAction Stop
            Write-Log "God Mode folder removed from the desktop." "INFO"
        } else {
            Write-Log "God Mode folder not found; nothing to remove." "INFO"
        }
    } else {
        if (-not (Test-Path -Path $targetPath)) {
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
            Write-Log "God Mode folder created on the desktop." "INFO"
        } else {
            Write-Log "God Mode folder already exists on the desktop." "INFO"
        }
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
