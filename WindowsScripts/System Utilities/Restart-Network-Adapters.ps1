# NAME: Restart Network Adapters
# DESCRIPTION: Restarts all physical network adapters.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/fleschutz/PowerShell
#

param (
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
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

try {
    Ensure-Admin

    $adapters = Get-NetAdapter -Physical -ErrorAction Stop
    if (-not $adapters) {
        Write-Log "No physical network adapters found." "WARN"
        exit 0
    }

    foreach ($adapter in $adapters) {
        Write-Log "Restarting adapter: $($adapter.Name)" "INFO"
        if (Get-Command Restart-NetAdapter -ErrorAction SilentlyContinue) {
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
        } else {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
        }
    }

    Write-Log "Network adapters restarted." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
