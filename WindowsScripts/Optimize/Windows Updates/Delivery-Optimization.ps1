# NAME: Delivery Optimization
# DESCRIPTION: Disables Delivery Optimization. Use -Undo to restore Windows default behavior.
# UNDOABLE: Yes
# UNDO_DESC: Restores Windows default Delivery Optimization behavior.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$UserPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
$MachinePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
$ValueName = "DODownloadMode"

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

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Re-launching with administrator privileges..." "INFO"
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($Undo) { $argList += "-Undo" }
        if ($Verbose) { $argList += "-Verbose" }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

function Set-DeliveryOptimizationValue {
    param (
        [string]$Path,
        [object]$Value
    )
    if ($null -eq $Value) {
        if (Test-Path -Path $Path) {
            Remove-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
        }
        return
    }
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $ValueName -Value $Value -Type DWord -Force
}

try {
    Ensure-Admin
    if ($Undo) {
        Set-DeliveryOptimizationValue -Path $UserPath -Value $null
        Set-DeliveryOptimizationValue -Path $MachinePath -Value $null
        Write-Log "Delivery Optimization restored to Windows defaults." "INFO"
    } else {
        Set-DeliveryOptimizationValue -Path $UserPath -Value 99
        Set-DeliveryOptimizationValue -Path $MachinePath -Value 99
        Write-Log "Delivery Optimization disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
