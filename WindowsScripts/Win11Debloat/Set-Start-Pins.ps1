# NAME: Set Start Menu Pins
# DESCRIPTION: Clears or applies Start menu pinned layout for current user or all users.
# UNDOABLE: Yes
# UNDO_DESC: Removes the ConfigureStartPins policy to restore defaults.
#

param (
    [ValidateSet("Clear", "Apply")]
    [string]$Mode = "Clear",
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser",
    [string]$LayoutJsonPath,
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

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
    if (-not $isAdmin -and $Scope -eq "AllUsers") {
        Write-Log "Re-launching with administrator privileges..." "INFO"
        try {
            $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"",
                "-Mode", $Mode, "-Scope", $Scope)
            if ($LayoutJsonPath) { $argList += @("-LayoutJsonPath", "`"$LayoutJsonPath`"") }
            if ($Undo) { $argList += "-Undo" }
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Get-PolicyPath {
    if ($Scope -eq "AllUsers") {
        return "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    }
    return "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
}

function Set-StartPinsPolicy {
    param (
        [string]$JsonValue
    )
    $path = Get-PolicyPath
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    New-ItemProperty -Path $path -Name "ConfigureStartPins" -Value $JsonValue -PropertyType String -Force | Out-Null
}

function Clear-StartPins {
    $json = '{"pinnedList":[]}'
    Set-StartPinsPolicy -JsonValue $json
}

function Apply-StartPins {
    if (-not $LayoutJsonPath) {
        throw "LayoutJsonPath is required when Mode is Apply."
    }
    if (-not (Test-Path $LayoutJsonPath)) {
        throw "Layout JSON file not found: $LayoutJsonPath"
    }
    $json = Get-Content -Path $LayoutJsonPath -Raw
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "Layout JSON file is empty."
    }
    Set-StartPinsPolicy -JsonValue $json
}

function Remove-StartPinsPolicy {
    $path = Get-PolicyPath
    if (Test-Path $path) {
        Remove-ItemProperty -Path $path -Name "ConfigureStartPins" -ErrorAction SilentlyContinue
    }
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Removing Start pins policy..." "INFO"
        Remove-StartPinsPolicy
        Write-Log "Policy removed. A sign-out may be required to restore defaults." "INFO"
        exit 0
    }

    if ($Mode -eq "Clear") {
        Write-Log "Clearing Start pins ($Scope)..." "INFO"
        Clear-StartPins
    } else {
        Write-Log "Applying Start pins layout ($Scope)..." "INFO"
        Apply-StartPins
    }

    Write-Log "Script completed successfully. Sign out or restart Explorer if changes do not appear." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
