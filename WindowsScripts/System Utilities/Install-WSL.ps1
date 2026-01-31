# NAME: Install WSL
# DESCRIPTION: Installs Windows Subsystem for Linux (WSL) using wsl.exe and required features.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/fleschutz/PowerShell
#

param (
    [string]$Distro,
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
        if ($Verbose) { $argList += "-Verbose" }
        if ($Distro) { $argList += @("-Distro", $Distro) }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

function Enable-WslFeatures {
    Write-Log "Enabling Windows Optional Features for WSL..." "INFO"
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction Stop | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction Stop | Out-Null
}

try {
    Ensure-Admin

    $wslCommand = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
    if (-not $wslCommand) {
        throw "wsl.exe not found. Update Windows to a version that includes WSL."
    }

    $helpText = & wsl.exe --help 2>&1 | Out-String
    if ($helpText -match "--install") {
        $args = @("--install")
        if ($Distro) {
            $args += @("--distribution", $Distro)
        }

        Write-Log "Running wsl.exe $($args -join ' ')." "INFO"
        $process = Start-Process -FilePath "wsl.exe" -ArgumentList $args -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "wsl.exe exited with code $($process.ExitCode)."
        }
    } else {
        Write-Log "wsl.exe --install not available; enabling optional features instead." "WARN"
        Enable-WslFeatures
        Write-Log "WSL optional features enabled. A reboot may be required." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
