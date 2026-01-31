# NAME: Microsoft Compatibility Appraiser Task
# DESCRIPTION: Disables the Microsoft Compatibility Appraiser scheduled task. Use -Undo to enable it.
# UNDOABLE: Yes
# UNDO_DESC: Enables the Microsoft Compatibility Appraiser scheduled task.
# LINK: https://github.com/memstechtips/Winhance
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$TaskName = "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"

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
        if ($Undo) { $argList += "-Undo" }
        if ($Verbose) { $argList += "-Verbose" }
        Start-Process -FilePath "PowerShell.exe" -ArgumentList $argList -Verb RunAs
        exit 0
    }
}

function Set-TaskState {
    param (
        [string]$Name,
        [bool]$Enable
    )
    $action = if ($Enable) { "/Enable" } else { "/Disable" }
    & schtasks /Change /TN "$Name" $action | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "schtasks failed with exit code $LASTEXITCODE"
    }
}

try {
    Ensure-Admin
    if ($Undo) {
        Set-TaskState -Name $TaskName -Enable $true
        Write-Log "Microsoft Compatibility Appraiser task enabled." "INFO"
    } else {
        Set-TaskState -Name $TaskName -Enable $false
        Write-Log "Microsoft Compatibility Appraiser task disabled." "INFO"
    }

    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
