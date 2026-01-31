# NAME: Startup Sound During Boot
# DESCRIPTION: Disables the Windows startup sound. Use -Undo to enable it.
# UNDOABLE: Yes
# UNDO_DESC: Enables the Windows startup sound.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$BootAnimationPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation"
$EditionOverridesPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\EditionOverrides"

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

try {
    Ensure-Admin
    if (-not (Test-Path -Path $BootAnimationPath)) {
        New-Item -Path $BootAnimationPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $EditionOverridesPath)) {
        New-Item -Path $EditionOverridesPath -Force | Out-Null
    }

    if ($Undo) {
        Set-ItemProperty -Path $BootAnimationPath -Name "DisableStartupSound" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $EditionOverridesPath -Name "UserSetting_DisableStartupSound" -Value 0 -Type DWord -Force
        Write-Log "Startup sound enabled." "INFO"
    } else {
        Set-ItemProperty -Path $BootAnimationPath -Name "DisableStartupSound" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $EditionOverridesPath -Name "UserSetting_DisableStartupSound" -Value 1 -Type DWord -Force
        Write-Log "Startup sound disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
