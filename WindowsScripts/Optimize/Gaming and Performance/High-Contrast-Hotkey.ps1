# NAME: High Contrast Hotkey (Alt+Shift+PrtScn)
# DESCRIPTION: Disables the High Contrast hotkey. Use -Undo to enable it.
# UNDOABLE: Yes
# UNDO_DESC: Enables the High Contrast hotkey.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Control Panel\Accessibility\HighContrast"
$ValueName = "Flags"

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
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value "126" -Type String -Force
        Write-Log "High Contrast hotkey enabled." "INFO"
    } else {
        Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value "4194" -Type String -Force
        Write-Log "High Contrast hotkey disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
