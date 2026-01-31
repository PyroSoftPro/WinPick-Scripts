# NAME: Enable Menu Show Delay
# DESCRIPTION: Disables menu show delay for faster navigation. Use -Undo to enable the delay.
# UNDOABLE: Yes
# UNDO_DESC: Enables the menu show delay.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Control Panel\Desktop"
$ValueName = "MenuShowDelay"

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
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value "400" -Type String -Force
        Write-Log "Menu show delay is now enabled (400 ms)." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value "0" -Type String -Force
        Write-Log "Menu show delay is now disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
