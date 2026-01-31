# NAME: Disable Bing and Cortana in Search
# DESCRIPTION: Disables Bing web search and Cortana integration in Windows Search and removes Bing Search app package.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
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
    if (-not $isAdmin) {
        Write-Log "Re-launching with administrator privileges..." "INFO"
        try {
            $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
            if ($Verbose) { $argList += "-Verbose" }
            Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        } catch {
            Write-Log "Failed to elevate to administrator: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
}

function Import-RegFile {
    param (
        [string]$RelativePath
    )
    $path = Join-Path $PSScriptRoot $RelativePath
    if (-not (Test-Path $path)) {
        throw "Registry file not found: $path"
    }
    $proc = Start-Process -FilePath "reg.exe" -ArgumentList @("import", "`"$path`"") -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) {
        throw "reg import failed with exit code $($proc.ExitCode)"
    }
}

function Remove-AppxPackages {
    param (
        [string[]]$AppxNames
    )
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    foreach ($name in $AppxNames) {
        $packages = Get-AppxPackage -Name $name -AllUsers -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($pkg in $packages) {
                if ($supportsAllUsers) {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                } else {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                }
            }
        }

        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $name }
        if ($prov) {
            foreach ($p in $prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName | Out-Null
            }
        }
    }
}

try {
    Ensure-Admin
    Write-Log "Disabling Bing and Cortana in Windows Search..." "INFO"
    Import-RegFile "Regfiles\\Disable_Bing_Cortana_In_Search.reg"
    Write-Log "Removing Bing Search app package..." "INFO"
    Remove-AppxPackages @("Microsoft.BingSearch")
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
