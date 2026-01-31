# NAME: Set Taskbar Search Mode
# DESCRIPTION: Sets the Windows 11 taskbar search appearance (hide, icon, label, or box).
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [ValidateSet("Hide", "Icon", "Label", "Box")]
    [string]$Mode = "Icon",
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

try {
    $regFile = switch ($Mode) {
        "Hide"  { "Regfiles\\Hide_Search_Taskbar.reg" }
        "Icon"  { "Regfiles\\Show_Search_Icon.reg" }
        "Label" { "Regfiles\\Show_Search_Icon_And_Label.reg" }
        "Box"   { "Regfiles\\Show_Search_Box.reg" }
    }
    Write-Log "Setting taskbar search mode to $Mode..." "INFO"
    Import-RegFile $regFile
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
