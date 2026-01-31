# NAME: Apply Regfile to User Profile
# DESCRIPTION: Loads a user profile hive and applies a .reg file to that user's HKCU.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [Parameter(Mandatory = $true)]
    [string]$RegFilePath,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$LogFile = Join-Path $PSScriptRoot "$(Split-Path -Leaf $PSCommandPath).log"
$TempHive = "WinPickTempHive"

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
                "-UserName", "`"$UserName`"", "-RegFilePath", "`"$RegFilePath`"")
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Get-UserHivePath {
    $primaryPath = Join-Path "C:\Users" $UserName
    $ntUser = Join-Path $primaryPath "NTUSER.DAT"
    if (Test-Path $ntUser) {
        return $ntUser
    }
    throw "NTUSER.DAT not found for user $UserName"
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
    $hivePath = Get-UserHivePath

    Write-Log "Loading user hive for $UserName..." "INFO"
    $loadProc = Start-Process -FilePath "reg.exe" -ArgumentList @("load", "HKU\\$TempHive", "`"$hivePath`"") -Wait -PassThru -WindowStyle Hidden
    if ($loadProc.ExitCode -ne 0) {
        throw "Failed to load user hive (exit code $($loadProc.ExitCode))"
    }

    Write-Log "Importing reg file into user hive..." "INFO"
    Import-RegFileToHive -HiveRoot $TempHive -RegPath $RegFilePath

    Write-Log "Unloading user hive..." "INFO"
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
