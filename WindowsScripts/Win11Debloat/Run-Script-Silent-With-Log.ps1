# NAME: Run Script Silent With Log
# DESCRIPTION: Runs a PowerShell script non-interactively and logs stdout/stderr to a file.
# UNDOABLE: No
# UNDO_DESC: N/A
#

param (
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    [string[]]$Arguments,
    [string]$LogPath,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

function Resolve-LogPath {
    if ($LogPath) {
        return $LogPath
    }
    $scriptName = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    return Join-Path (Split-Path -Parent $ScriptPath) "$scriptName.run.log"
}

try {
    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    $logFile = Resolve-LogPath
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
    if ($Arguments -and $Arguments.Count -gt 0) {
        $argList += $Arguments
    }

    $proc = Start-Process -FilePath "PowerShell.exe" `
        -ArgumentList $argList `
        -Wait -NoNewWindow -PassThru `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError $logFile

    if ($proc.ExitCode -ne 0) {
        throw "Script exited with code $($proc.ExitCode). See log: $logFile"
    }
    Write-Host "Script completed successfully. Log: $logFile"
    exit 0
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
