# NAME: OneDrive
# DESCRIPTION: Removes Microsoft OneDrive from the system. Use -Undo to reinstall via WinGet.
# UNDOABLE: Yes
# UNDO_DESC: Reinstalls Microsoft OneDrive using WinGet.
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

function Stop-OneDriveProcesses {
    Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Remove-OneDriveAppx {
    Write-Log "Removing OneDrive Appx package..." "INFO"
    Get-AppxPackage -AllUsers *OneDriveSync* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.OneDriveSync" } |
        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null }
}

function Uninstall-OneDriveSetup {
    Write-Log "Running OneDriveSetup.exe /uninstall..." "INFO"
    $setupPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )
    foreach ($path in $setupPaths) {
        if (Test-Path $path) {
            Start-Process -FilePath $path -ArgumentList "/uninstall" -Wait -WindowStyle Hidden
        }
    }
}

function Remove-OneDriveScheduledTasks {
    Write-Log "Removing OneDrive scheduled tasks..." "INFO"
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $_.TaskName -like "*OneDrive*" -or $_.TaskPath -like "*OneDrive*"
        } | ForEach-Object {
            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "Warning: Could not remove scheduled tasks: $($_.Exception.Message)" "WARN"
    }
}

function Remove-OneDriveRunEntries {
    Write-Log "Removing OneDrive Run entries..." "INFO"
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            Remove-ItemProperty -Path $key -Name "OneDrive" -ErrorAction SilentlyContinue
        }
    }
}

function Remove-OneDriveFiles {
    Write-Log "Removing OneDrive files and folders (excluding user OneDrive data)..." "INFO"
    $paths = @(
        "$env:ProgramData\Microsoft OneDrive",
        "$env:SystemDrive\OneDriveTemp",
        "${env:ProgramFiles}\Microsoft OneDrive",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -Path (Join-Path $_.FullName "NTUSER.DAT")
    }
    foreach ($profile in $userProfiles) {
        $localAppData = Join-Path $profile.FullName "AppData\Local\Microsoft\OneDrive"
        $roamingAppData = Join-Path $profile.FullName "AppData\Roaming\Microsoft\OneDrive"
        foreach ($path in @($localAppData, $roamingAppData)) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-OneDriveShortcuts {
    Write-Log "Removing OneDrive shortcuts..." "INFO"
    $shortcutPaths = @()
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -Path (Join-Path $_.FullName "NTUSER.DAT")
    }
    foreach ($profile in $userProfiles) {
        $shortcutPaths += @(
            "$($profile.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk",
            "$($profile.FullName)\Desktop\OneDrive.lnk"
        )
    }
    $shortcutPaths += "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
    foreach ($path in $shortcutPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-OneDrive {
    $wingetId = "Microsoft.OneDrive"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is not available. Install WinGet (App Installer) and retry."
    }
    Write-Log "Installing OneDrive via WinGet..." "INFO"
    $args = @(
        "install",
        "--id", $wingetId,
        "--source", "winget",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "WinGet failed with exit code $($process.ExitCode)."
    }
    Write-Log "OneDrive installed successfully." "INFO"
}

try {
    Ensure-Admin
    if ($Undo) {
        Write-Log "Starting undo operation (reinstall OneDrive)..." "INFO"
        Install-OneDrive
    } else {
        Write-Log "Starting removal operation..." "INFO"
        Stop-OneDriveProcesses
        Remove-OneDriveAppx
        Uninstall-OneDriveSetup
        Remove-OneDriveScheduledTasks
        Remove-OneDriveRunEntries
        Remove-OneDriveShortcuts
        Remove-OneDriveFiles
    }
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
