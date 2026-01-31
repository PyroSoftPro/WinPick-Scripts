# NAME: Fullscreen Optimizations
# DESCRIPTION: Disables fullscreen optimizations for compatibility. Use -Undo to enable them.
# UNDOABLE: Yes
# UNDO_DESC: Enables fullscreen optimizations.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\System\GameConfigStore"
$ValueName = "GameDVR_FSEBehaviorMode"

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
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 0 -Type DWord -Force
        Write-Log "Fullscreen optimizations are now enabled." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value 2 -Type DWord -Force
        Write-Log "Fullscreen optimizations are now disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
