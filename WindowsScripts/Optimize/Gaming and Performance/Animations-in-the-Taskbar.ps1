# NAME: Animations in the taskbar
# DESCRIPTION: Disables taskbar animations. Use -Undo to enable them.
# UNDOABLE: Yes
# UNDO_DESC: Enables taskbar animations.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ValueName = "TaskbarAnimations"

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
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 1 -Type DWord -Force
        Write-Log "Taskbar animations enabled." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 0 -Type DWord -Force
        Write-Log "Taskbar animations disabled." "INFO"
    }

    Write-Log "A restart may be required for changes to take effect." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
