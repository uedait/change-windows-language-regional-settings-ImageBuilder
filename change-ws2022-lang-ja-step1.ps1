function Invoke-LanguagePackCabFileDownload
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $LangPackIsoUri,

        [Parameter(Mandatory = $true)]
        [long] $OffsetToCabFileInIsoFile,

        [Parameter(Mandatory = $true)]
        [long] $CabFileSize,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CabFileHash,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationFilePath
    )

    $request = [System.Net.HttpWebRequest]::Create($LangPackIsoUri)
    $request.Method = 'GET'

    # Set the language pack CAB file data range.
    $request.AddRange('bytes', $OffsetToCabFileInIsoFile, $OffsetToCabFileInIsoFile + $CabFileSize - 1)

    # Donwload the language pack CAB file.
    $response = $request.GetResponse()
    $reader = New-Object -TypeName 'System.IO.BinaryReader' -ArgumentList $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($DestinationFilePath)
    $contents = $reader.ReadBytes($response.ContentLength)
    $fileStream.Write($contents, 0, $contents.Length)
    $fileStream.Dispose()
    $reader.Dispose()
    $response.Close()
    $response.Dispose()

    # Verify integrity of the downloaded language pack CAB file.
    $fileHash = Get-FileHash -Algorithm SHA1 -LiteralPath $DestinationFilePath
    if ($fileHash.Hash -ne $CabFileHash) {
        throw ('The file hash of the language pack CAB file "{0}" is not match to expected value. The download was may failed.') -f $DestinationFilePath
    }
}

# Download the language pack CAB file for Japanese.
#
# Reference:
# - Windows Server 2022 - Evaluation Center
#   https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022
$langPackFilePath = Join-Path -Path $env:TEMP -ChildPath 'Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab'
$params = @{
    LangPackIsoUri           = 'https://software-static.download.prss.microsoft.com/pr/download/20348.1.210507-1500.fe_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso'
    OffsetToCabFileInIsoFile = 0x107d35800L
    CabFileSize              = 54130307
    CabFileHash              = '298667B848087EA1377F483DC15597FD5F38A492'
    DestinationFilePath      = $langPackFilePath
}
Invoke-LanguagePackCabFileDownload @params -Verbose

# Install the language pack.
Add-WindowsPackage -Online -NoRestart -PackagePath $langPackFilePath -Verbose

# Delete the language pack CAB file.
Remove-Item -LiteralPath $langPackFilePath -Force -Verbose

# Install the Japanese language related capabilities.
Add-WindowsCapability -Online -Name 'Language.Basic~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.OCR~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Handwriting~~~ja-JP~0.0.1.0' -Verbose   # Optional
Add-WindowsCapability -Online -Name 'Language.Speech~~~ja-JP~0.0.1.0' -Verbose        # Optional
Add-WindowsCapability -Online -Name 'Language.TextToSpeech~~~ja-JP~0.0.1.0' -Verbose  # Optional

# Set the time zone for the current computer.
Set-TimeZone -Id 'Tokyo Standard Time' -Verbose

# Restart the system to take effect the language pack installation.
# Restart-Computer