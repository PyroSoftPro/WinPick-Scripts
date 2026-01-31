# NAME: Show Hidden Files
# DESCRIPTION: Shows hidden files and folders in File Explorer. Use -Undo to hide them.
# UNDOABLE: Yes
# UNDO_DESC: Hides hidden files and folders in File Explorer.
# LINK: https://github.com/WinTweakers/WindowsToolbox
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

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
    if (-not (Test-Path -Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $RegistryPath -Name "Hidden" -Value 2 -Type DWord -Force
        Write-Log "Hidden files are now hidden." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name "Hidden" -Value 1 -Type DWord -Force
        Write-Log "Hidden files are now visible." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
