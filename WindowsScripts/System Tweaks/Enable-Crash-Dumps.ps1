# NAME: Enable Crash Dumps
# DESCRIPTION: Enables automatic Windows crash dumps and sets default dump paths. Use -Undo to disable crash dumps.
# UNDOABLE: Yes
# UNDO_DESC: Disables crash dumps and removes values set by this script.
# LINK: https://github.com/fleschutz/PowerShell
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
$DesiredValues = @{
    CrashDumpEnabled     = 7
    LogEvent             = 1
    AlwaysKeepMemoryDump = 1
    MinidumpDir          = "%SystemRoot%\Minidump"
    DumpFile             = "%SystemRoot%\MEMORY.DMP"
}

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

function Ensure-RegistryPath {
    if (-not (Test-Path -Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
}

function Set-CrashDumpValues {
    foreach ($name in $DesiredValues.Keys) {
        Set-ItemProperty -Path $RegistryPath -Name $name -Value $DesiredValues[$name] -Force
    }
}

function Disable-CrashDumps {
    Set-ItemProperty -Path $RegistryPath -Name "CrashDumpEnabled" -Value 0 -Force
    foreach ($name in @("LogEvent", "AlwaysKeepMemoryDump", "MinidumpDir", "DumpFile")) {
        if (Get-ItemProperty -Path $RegistryPath -Name $name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $RegistryPath -Name $name -ErrorAction SilentlyContinue
        }
    }
}

try {
    Ensure-Admin
    Ensure-RegistryPath

    if ($Undo) {
        Disable-CrashDumps
        Write-Log "Crash dump settings disabled." "INFO"
    } else {
        Set-CrashDumpValues
        $minidumpPath = [Environment]::ExpandEnvironmentVariables($DesiredValues.MinidumpDir)
        if (-not (Test-Path -Path $minidumpPath)) {
            New-Item -Path $minidumpPath -ItemType Directory -Force | Out-Null
        }
        Write-Log "Crash dump settings enabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
