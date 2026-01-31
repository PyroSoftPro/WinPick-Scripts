# NAME: Windows Update Policy
# DESCRIPTION: Sets Windows Update to "Security Updates Only". Use -Undo to restore normal defaults.
# UNDOABLE: Yes
# UNDO_DESC: Restores normal Windows Update defaults.
# LINK: https://github.com/memstechtips/Winhance
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

function Set-PolicyValue {
    param (
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type
    )
    if ($null -eq $Value) {
        if (Test-Path -Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        }
        return
    }
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

try {
    Ensure-Admin
    if ($Undo) {
        $settings = @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "BranchReadinessLevel"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferFeatureUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferFeatureUpdatesPeriodInDays"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferQualityUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferQualityUpdatesPeriodInDays"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseFeatureUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseFeatureUpdatesEndTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseQualityUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseQualityUpdatesEndTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseUpdatesExpiryTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedQualityDate"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedFeatureDate"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "FlightSettingsMaxPauseDays"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAUShutdownOption"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAUShutdownOption"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AutoInstallMinorUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AutoInstallMinorUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "UseWUServer"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "UseWUServer"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedFeatureStatus"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedQualityStatus"; Value = $null; Type = "DWord" }
        )
        foreach ($setting in $settings) {
            Set-PolicyValue @setting
        }
        Write-Log "Windows Update policy restored to normal defaults." "INFO"
    } else {
        $settings = @(
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Value = 2; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AUOptions"; Value = 2; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "BranchReadinessLevel"; Value = 20; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferFeatureUpdates"; Value = 1; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferFeatureUpdatesPeriodInDays"; Value = 365; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferQualityUpdates"; Value = 1; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "DeferQualityUpdatesPeriodInDays"; Value = 7; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseFeatureUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseFeatureUpdatesEndTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseQualityUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseQualityUpdatesEndTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseUpdatesStartTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PauseUpdatesExpiryTime"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedQualityDate"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedFeatureDate"; Value = $null; Type = "String" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "FlightSettingsMaxPauseDays"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAUShutdownOption"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAUShutdownOption"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AlwaysAutoRebootAtScheduledTime"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AutoInstallMinorUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "AutoInstallMinorUpdates"; Value = $null; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "UseWUServer"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "UseWUServer"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedFeatureStatus"; Value = $null; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; Name = "PausedQualityStatus"; Value = $null; Type = "DWord" }
        )
        foreach ($setting in $settings) {
            Set-PolicyValue @setting
        }
        Write-Log "Windows Update policy set to Security Updates Only." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
