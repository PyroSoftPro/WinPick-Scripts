# NAME: Enable Trusted Remoting
# DESCRIPTION: Enables PowerShell remoting and configures TrustedHosts.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/stevencohn/WindowsPowerShell
#

param (
    [string]$TrustedHosts = "*",
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
        $argList += @("-TrustedHosts", $TrustedHosts)
        if ($Verbose) { $argList += "-Verbose" }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

try {
    Ensure-Admin
    Enable-PSRemoting -Force
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $TrustedHosts -Force
    Write-Log "PowerShell remoting enabled. TrustedHosts set to '$TrustedHosts'." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
