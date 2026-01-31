# NAME: Slide open combo boxes
# DESCRIPTION: Disables combo box animations. Use -Undo to enable them.
# UNDOABLE: Yes
# UNDO_DESC: Enables combo box animations.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKCU:\Control Panel\Desktop"
$ValueName = "UserPreferencesMask"
$ByteIndex = 0
$BitMask = 0x04

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

function Get-UserPreferencesMask {
    $current = (Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
    if (-not $current) {
        return [byte[]](0, 0, 0, 0, 0, 0, 0, 0)
    }
    return [byte[]]$current
}

function Set-UserPreferencesMaskBit {
    param (
        [bool]$Enable
    )
    $bytes = Get-UserPreferencesMask
    if ($bytes.Length -lt ($ByteIndex + 1)) {
        $expanded = New-Object byte[] ($ByteIndex + 1)
        $bytes.CopyTo($expanded, 0)
        $bytes = $expanded
    }
    $mask = [byte]$BitMask
    if ($Enable) {
        $bytes[$ByteIndex] = [byte]($bytes[$ByteIndex] -bor $mask)
    } else {
        $bytes[$ByteIndex] = [byte]($bytes[$ByteIndex] -band (-bnot $mask))
    }
    Set-ItemProperty -Path $RegistryPath -Name $ValueName -Value $bytes -Type Binary -Force
}

try {
    if (-not (Test-Path -Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    if ($Undo) {
        Set-UserPreferencesMaskBit -Enable $true
        Write-Log "Combo box animations enabled." "INFO"
    } else {
        Set-UserPreferencesMaskBit -Enable $false
        Write-Log "Combo box animations disabled." "INFO"
    }

    Write-Log "A restart may be required for changes to take effect." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
