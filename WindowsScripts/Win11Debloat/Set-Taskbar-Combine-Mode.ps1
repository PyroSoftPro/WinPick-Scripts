# NAME: Set Taskbar Combine Mode
# DESCRIPTION: Sets taskbar combine mode for main or secondary displays on Windows 11.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [ValidateSet("Main", "Secondary")]
    [string]$Target = "Main",
    [ValidateSet("Always", "WhenFull", "Never")]
    [string]$Mode = "WhenFull",
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
    $regFile = if ($Target -eq "Main") {
        switch ($Mode) {
            "Always"   { "Regfiles\\Combine_Taskbar_Always.reg" }
            "WhenFull" { "Regfiles\\Combine_Taskbar_When_Full.reg" }
            "Never"    { "Regfiles\\Combine_Taskbar_Never.reg" }
        }
    } else {
        switch ($Mode) {
            "Always"   { "Regfiles\\Combine_MMTaskbar_Always.reg" }
            "WhenFull" { "Regfiles\\Combine_MMTaskbar_When_Full.reg" }
            "Never"    { "Regfiles\\Combine_MMTaskbar_Never.reg" }
        }
    }

    Write-Log "Setting taskbar combine mode ($Target) to $Mode..." "INFO"
    Import-RegFile $regFile
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
