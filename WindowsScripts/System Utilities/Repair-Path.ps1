# NAME: Repair PATH
# DESCRIPTION: Cleans and de-duplicates PATH entries, optionally removing invalid paths.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [ValidateSet("User", "Machine", "Both")]
    [string]$Scope = "Both",
    [switch]$RemoveInvalid,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$UserPathKey = "HKCU:\Environment"
$MachinePathKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

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
        $argList += @("-Scope", $Scope)
        if ($RemoveInvalid) { $argList += "-RemoveInvalid" }
        if ($Verbose) { $argList += "-Verbose" }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

function Get-PathValue {
    param ([string]$KeyPath)
    try {
        (Get-ItemProperty -Path $KeyPath -Name "Path" -ErrorAction Stop).Path
    } catch {
        ""
    }
}

function Set-PathValue {
    param (
        [string]$KeyPath,
        [string]$Value
    )
    if (-not (Test-Path -Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $KeyPath -Name "Path" -Value $Value -Type ExpandString -Force
}

function Clean-PathString {
    param (
        [string]$PathValue,
        [switch]$DropInvalid
    )

    $entries = $PathValue -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $seen = @{}
    $cleaned = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $entries) {
        $normalized = $entry.TrimEnd("\")
        $key = $normalized.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }

        if ($DropInvalid) {
            $expanded = [Environment]::ExpandEnvironmentVariables($normalized)
            if (-not (Test-Path -Path $expanded)) {
                Write-Log "Skipping invalid PATH entry: $entry" "WARN"
                continue
            }
        }

        $seen[$key] = $true
        $cleaned.Add($normalized)
    }

    $cleaned -join ";"
}

try {
    if ($Scope -in @("Machine", "Both")) {
        Ensure-Admin
    }

    if ($Scope -in @("User", "Both")) {
        $userPath = Get-PathValue -KeyPath $UserPathKey
        $cleanUserPath = Clean-PathString -PathValue $userPath -DropInvalid:$RemoveInvalid
        Set-PathValue -KeyPath $UserPathKey -Value $cleanUserPath
        Write-Log "User PATH cleaned." "INFO"
    }

    if ($Scope -in @("Machine", "Both")) {
        $machinePath = Get-PathValue -KeyPath $MachinePathKey
        $cleanMachinePath = Clean-PathString -PathValue $machinePath -DropInvalid:$RemoveInvalid
        Set-PathValue -KeyPath $MachinePathKey -Value $cleanMachinePath
        Write-Log "Machine PATH cleaned." "INFO"
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")

    Write-Log "Process PATH refreshed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
