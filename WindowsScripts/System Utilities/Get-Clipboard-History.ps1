# NAME: Get Clipboard History
# DESCRIPTION: Outputs text entries from Windows clipboard history. Use -Clear to clear history.
# UNDOABLE: No
# UNDO_DESC: Not supported.
# LINK: https://github.com/bastienperez/PowerShell-Toolbox
#

param (
    [switch]$Clear,
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

function Initialize-WinRT {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
    } catch {
        Write-Log "Windows Runtime assemblies not available: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Await-WinRT {
    param (
        [Parameter(Mandatory = $true)]
        $AsyncTask,
        [Parameter(Mandatory = $true)]
        [Type]$ResultType
    )

    $awaiter = [WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object { $_.Name -eq "GetAwaiter" -and $_.GetParameters().Count -eq 1 } |
        Select-Object -First 1

    $generic = $awaiter.MakeGenericMethod($ResultType)
    $generic.Invoke($null, @($AsyncTask)).GetResult()
}

try {
    Initialize-WinRT

    $clipboard = [Windows.ApplicationModel.DataTransfer.Clipboard, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
    if ($Clear) {
        $null = $clipboard::ClearHistory()
        Write-Log "Clipboard history cleared." "INFO"
        exit 0
    }

    $resultType = [Windows.ApplicationModel.DataTransfer.ClipboardHistoryItemsResult, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
    $result = Await-WinRT -AsyncTask $clipboard::GetHistoryItemsAsync() -ResultType $resultType

    $items = @($result.Items)
    foreach ($item in $items) {
        if ($item.Content.Contains("Text")) {
            $text = Await-WinRT -AsyncTask $item.Content.GetTextAsync() -ResultType ([string])
            $text
        }
    }

    Write-Log "Clipboard history read completed." "INFO"
    exit 0
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    exit 1
}
