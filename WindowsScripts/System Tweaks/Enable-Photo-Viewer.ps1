# NAME: Enable Photo Viewer
# DESCRIPTION: Restores legacy Windows Photo Viewer file associations. Use -Undo to remove the associations.
# UNDOABLE: Yes
# UNDO_DESC: Removes the Photo Viewer associations created by this script.
# LINK: https://github.com/WinTweakers/WindowsToolbox
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$Extensions = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".ico")
$ClassValue = "PhotoViewer.FileAssoc.Tiff"
$BasePath = "HKCU:\Software\Classes"

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
    foreach ($ext in $Extensions) {
        $keyPath = Join-Path $BasePath $ext

        if ($Undo) {
            if (Test-Path -Path $keyPath) {
                $current = (Get-ItemProperty -Path $keyPath -Name "(default)" -ErrorAction SilentlyContinue)."(default)"
                if ($current -eq $ClassValue) {
                    Remove-ItemProperty -Path $keyPath -Name "(default)" -ErrorAction SilentlyContinue
                }
            }
        } else {
            if (-not (Test-Path -Path $keyPath)) {
                New-Item -Path $keyPath -Force | Out-Null
            }
            Set-ItemProperty -Path $keyPath -Name "(default)" -Value $ClassValue -Force
        }
    }

    $action = if ($Undo) { "Removed" } else { "Applied" }
    Write-Log "$action Windows Photo Viewer associations." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
