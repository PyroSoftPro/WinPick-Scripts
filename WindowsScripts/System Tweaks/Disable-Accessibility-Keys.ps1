# NAME: Disable Accessibility Keys
# DESCRIPTION: Disables Sticky Keys, Toggle Keys, and Filter Keys shortcuts. Use -Undo to restore defaults.
# UNDOABLE: Yes
# UNDO_DESC: Restores the default accessibility key settings.
# LINK: https://github.com/WinTweakers/WindowsToolbox
#

param (
    [switch]$Undo,
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }
$ErrorActionPreference = "Stop"

$Settings = @(
    @{ Path = "HKCU:\Control Panel\Accessibility\StickyKeys"; Name = "Flags"; DisabledValue = "506"; DefaultValue = "510" },
    @{ Path = "HKCU:\Control Panel\Accessibility\ToggleKeys"; Name = "Flags"; DisabledValue = "58"; DefaultValue = "58" },
    @{ Path = "HKCU:\Control Panel\Accessibility\Keyboard Response"; Name = "Flags"; DisabledValue = "122"; DefaultValue = "126" }
)

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
    foreach ($setting in $Settings) {
        if (-not (Test-Path -Path $setting.Path)) {
            New-Item -Path $setting.Path -Force | Out-Null
        }

        $value = if ($Undo) { $setting.DefaultValue } else { $setting.DisabledValue }
        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $value -Force
    }

    $action = if ($Undo) { "Restored" } else { "Disabled" }
    Write-Log "$action accessibility key shortcuts." "INFO"
    Write-Log "Script completed successfully." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
