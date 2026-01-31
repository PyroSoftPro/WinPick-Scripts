# NAME: Set File Explorer Launch Location
# DESCRIPTION: Sets the default File Explorer launch location (Home, This PC, Downloads, or OneDrive).
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [ValidateSet("Home", "ThisPC", "Downloads", "OneDrive")]
    [string]$Location = "Home",
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
    $regFile = switch ($Location) {
        "Home"      { "Regfiles\\Launch_File_Explorer_To_Home.reg" }
        "ThisPC"    { "Regfiles\\Launch_File_Explorer_To_This_PC.reg" }
        "Downloads" { "Regfiles\\Launch_File_Explorer_To_Downloads.reg" }
        "OneDrive"  { "Regfiles\\Launch_File_Explorer_To_OneDrive.reg" }
    }
    Write-Log "Setting File Explorer launch location to $Location..." "INFO"
    Import-RegFile $regFile
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
