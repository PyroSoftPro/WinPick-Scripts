# NAME: Xbox Game Bar
# DESCRIPTION: Removes Xbox Game Bar for all users and deprovisions it. Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Xbox Game Bar using WinGet (Microsoft Store).
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
        try {
            $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
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

function Apply-GameDvrRegistryFix {
    Write-Log "Applying Game DVR registry settings..." "INFO"
    try {
        $runningAsSystem = ($env:USERNAME -eq "SYSTEM" -or $env:USERPROFILE -like "*\\system32\\config\\systemprofile")
        if ($runningAsSystem) {
            Write-Log "Running as SYSTEM - detecting logged-in user..." "INFO"
            $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
            if ($loggedInUser -and $loggedInUser -ne "NT AUTHORITY\\SYSTEM") {
                $username = $loggedInUser.Split("\\")[1]
                $sid = (New-Object System.Security.Principal.NTAccount($username)).Translate([System.Security.Principal.SecurityIdentifier]).Value
                Write-Log "Applying settings for user: $username (SID: $sid)" "INFO"
                reg add "HKU\\$sid\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR" /f /t REG_DWORD /v "AppCaptureEnabled" /d 0 2>$null | Out-Null
                reg add "HKU\\$sid\\System\\GameConfigStore" /f /t REG_DWORD /v "GameDVR_Enabled" /d 0 2>$null | Out-Null
            } else {
                Write-Log "Warning: Could not detect logged-in user for registry settings" "WARN"
            }
        } else {
            reg add "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR" /f /t REG_DWORD /v "AppCaptureEnabled" /d 0 2>$null | Out-Null
            reg add "HKCU\\System\\GameConfigStore" /f /t REG_DWORD /v "GameDVR_Enabled" /d 0 2>$null | Out-Null
        }
        Write-Log "Game DVR registry settings applied." "INFO"
    } catch {
        Write-Log "Warning: Could not apply Game DVR registry settings: $($_.Exception.Message)" "WARN"
    }
}

function Remove-XboxGameBar {
    $appxName = "Microsoft.XboxGamingOverlay"
    $removeCmd = Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue
    $supportsAllUsers = $false
    if ($removeCmd) {
        $supportsAllUsers = $removeCmd.Parameters.ContainsKey("AllUsers")
    }

    Write-Log "Removing installed Xbox Game Bar packages..." "INFO"
    $packages = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($packages) {
        foreach ($pkg in $packages) {
            if ($supportsAllUsers) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            } else {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            }
        }
        Write-Log "Installed packages removed." "INFO"
    } else {
        Write-Log "No installed packages found." "INFO"
    }

    Write-Log "Removing provisioned Xbox Game Bar package..." "INFO"
    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $appxName }
    if ($prov) {
        foreach ($p in $prov) {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName | Out-Null
        }
        Write-Log "Provisioned package removed." "INFO"
    } else {
        Write-Log "No provisioned package found." "INFO"
    }

    Apply-GameDvrRegistryFix
}

function Install-XboxGameBar {
    $wingetId = "9NZKPSTSNW4P"
    $appxName = "Microsoft.XboxGamingOverlay"

    $existing = Get-AppxPackage -Name $appxName -AllUsers -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Xbox Game Bar is already installed. No action taken." "INFO"
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }

    Write-Log "Installing Xbox Game Bar via WinGet..." "INFO"
    $args = @(
        "install",
        "--id", $wingetId,
        "--source", "msstore",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
    Write-Log "Xbox Game Bar installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall Xbox Game Bar)..." "INFO"
        Install-XboxGameBar
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Remove-XboxGameBar
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
