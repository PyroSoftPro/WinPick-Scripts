# NAME: Apply Regfile to Default Profile
# DESCRIPTION: Loads the Default user hive and applies a .reg file for new user profiles.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [Parameter(Mandatory = $true)]
    [string]$RegFilePath,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$LogFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).log"
$TempHive = "WinPickDefaultHive"

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
        try {
            $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"",
                "-RegFilePath", "`"$RegFilePath`"")
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Import-RegFileToHive {
    param (
        [string]$HiveRoot,
        [string]$RegPath
    )
    if (-not (Test-Path $RegPath)) {
        throw "Reg file not found: $RegPath"
    }
    $content = Get-Content -Path $RegPath -Raw
    $content = $content -replace 'HKEY_CURRENT_USER', "HKEY_USERS\\$HiveRoot"
    $content = $content -replace '\bHKCU\b', "HKEY_USERS\\$HiveRoot"

    $tempFile = Join-Path $env:TEMP "WinPick_$([Guid]::NewGuid().ToString()).reg"
    Set-Content -Path $tempFile -Value $content -Encoding Unicode
    try {
        $proc = Start-Process -FilePath "reg.exe" -ArgumentList @("import", "`"$tempFile`"") -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -ne 0) {
            throw "reg import failed with exit code $($proc.ExitCode)"
        }
    } finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

try {
    Ensure-Admin
    $defaultHivePath = "C:\Users\Default\NTUSER.DAT"
    if (-not (Test-Path $defaultHivePath)) {
        throw "Default profile NTUSER.DAT not found at $defaultHivePath"
    }

    Write-Log "Loading Default profile hive..." "INFO"
    $loadProc = Start-Process -FilePath "reg.exe" -ArgumentList @("load", "HKU\\$TempHive", "`"$defaultHivePath`"") -Wait -PassThru -WindowStyle Hidden
    if ($loadProc.ExitCode -ne 0) {
        throw "Failed to load Default hive (exit code $($loadProc.ExitCode))"
    }

    Write-Log "Importing reg file into Default profile hive..." "INFO"
    Import-RegFileToHive -HiveRoot $TempHive -RegPath $RegFilePath

    Write-Log "Unloading Default profile hive..." "INFO"
    Start-Process -FilePath "reg.exe" -ArgumentList @("unload", "HKU\\$TempHive") -Wait -PassThru -WindowStyle Hidden | Out-Null

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    try {
        Start-Process -FilePath "reg.exe" -ArgumentList @("unload", "HKU\\$TempHive") -Wait -PassThru -WindowStyle Hidden | Out-Null
    } catch { }
    exit 1
}
