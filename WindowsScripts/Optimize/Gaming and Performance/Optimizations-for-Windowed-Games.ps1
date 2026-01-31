# NAME: Optimizations for windowed games
# DESCRIPTION: Enables DirectX flip model optimizations for windowed games. Use -Undo to disable.
# UNDOABLE: Yes
# UNDO_DESC: Disables optimizations for windowed games.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
$ValueName = "DirectXUserGlobalSettings"
$EnabledValue = "SwapEffectUpgradeEnable=1;"

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
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value "" -Type String -Force
        Write-Log "Windowed game optimizations are now disabled." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $EnabledValue -Type String -Force
        Write-Log "Windowed game optimizations are now enabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
