# NAME: Install Chocolatey
# DESCRIPTION: Installs Chocolatey. Use -Upgrade to upgrade if already installed.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/jhochwald/PowerShell-collection
#

param (
    [switch]$Upgrade,
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

try {
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        if ($Upgrade) {
            Write-Log "Upgrading Chocolatey..." "INFO"
            choco upgrade chocolatey -y | Out-Null
            Write-Log "Chocolatey upgrade completed." "INFO"
        } else {
            Write-Log "Chocolatey is already installed." "INFO"
        }
        exit 0
    }

    Write-Log "Installing Chocolatey..." "INFO"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $script = (Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -UseBasicParsing).Content
    Invoke-Expression $script

    Write-Log "Chocolatey installation completed." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
