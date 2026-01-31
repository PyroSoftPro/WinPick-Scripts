# NAME: Remove HP OEM Apps
# DESCRIPTION: Removes common HP OEM app packages for all users.
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
        $pattern = if ($name -like "*`**") { $name } else { "*$name*" }
        $packages = Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($pkg in $packages) {
                if ($supportsAllUsers) {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                } else {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                }
            }
        }

        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pattern }
        if ($prov) {
            foreach ($p in $prov) {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName | Out-Null
            }
        }
    }
}

try {
    Ensure-Admin
    Write-Log "Removing HP OEM apps..." "INFO"
    $apps = @(
        "AD2F1837.HPAIExperienceCenter",
        "AD2F1837.HPJumpStarts",
        "AD2F1837.HPPCHardwareDiagnosticsWindows",
        "AD2F1837.HPPowerManager",
        "AD2F1837.HPPrivacySettings",
        "AD2F1837.HPSupportAssistant",
        "AD2F1837.HPSureShieldAI",
        "AD2F1837.HPSystemInformation",
        "AD2F1837.HPQuickDrop",
        "AD2F1837.HPWorkWell",
        "AD2F1837.myHP",
        "AD2F1837.HPDesktopSupportUtilities",
        "AD2F1837.HPQuickTouch",
        "AD2F1837.HPEasyClean",
        "AD2F1837.HPConnectedMusic",
        "AD2F1837.HPFileViewer",
        "AD2F1837.HPRegistration",
        "AD2F1837.HPWelcome",
        "AD2F1837.HPConnectedPhotopoweredbySnapfish",
        "AD2F1837.HPPrinterControl"
    )
    Remove-AppxPackages $apps
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
