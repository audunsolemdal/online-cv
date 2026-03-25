Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

function Select-DownloadFolder {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = [Environment]::GetFolderPath("Desktop")
    $dialog.ShowNewFolderButton = $false
    $dialog.Description = "Select a directory for PDF downloads"

    try {
        while ($true) {
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                return $dialog.SelectedPath
            }

            $result = [System.Windows.Forms.MessageBox]::Show(
                "You clicked Cancel. Would you like to try again or exit?",
                "Select a location",
                [System.Windows.Forms.MessageBoxButtons]::RetryCancel
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
                return $null
            }
        }
    }
    finally {
        $dialog.Dispose()
    }
}

function Get-PdfLinks {
    param(
        [Parameter(Mandatory = $true)]
        [Uri] $SiteUri
    )

    $response = Invoke-WebRequest -Uri $SiteUri.AbsoluteUri -UseBasicParsing
    $pattern = 'href\s*=\s*["''](?<href>[^"'']+\.pdf(?:\?[^"'']*)?)["'']'
    $matches = [regex]::Matches($response.Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $pdfLinks = New-Object System.Collections.Generic.List[Uri]

    foreach ($match in $matches) {
        $href = $match.Groups["href"].Value -replace "^http://", "https://"

        if ([string]::IsNullOrWhiteSpace($href)) {
            continue
        }

        try {
            $candidateUri = [Uri]::new($SiteUri, $href)
        }
        catch {
            continue
        }

        if ($candidateUri.Scheme -ne "https") {
            continue
        }

        if ($candidateUri.Host -ne $SiteUri.Host) {
            continue
        }

        if (-not $candidateUri.AbsolutePath.ToLowerInvariant().EndsWith(".pdf")) {
            continue
        }

        $pdfLinks.Add($candidateUri)
    }

    return $pdfLinks | Sort-Object AbsoluteUri -Unique
}

function Save-Pdfs {
    param(
        [Parameter(Mandatory = $true)]
        [Uri[]] $PdfUris,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    $downloadCount = 0

    foreach ($pdfUri in $PdfUris) {
        $fileName = [IO.Path]::GetFileName($pdfUri.LocalPath)

        if ([string]::IsNullOrWhiteSpace($fileName)) {
            continue
        }

        $targetPath = Join-Path -Path $DestinationPath -ChildPath $fileName

        if (Test-Path -LiteralPath $targetPath) {
            Write-Host "Skipping existing file: $fileName"
            continue
        }

        Invoke-WebRequest -Uri $pdfUri.AbsoluteUri -OutFile $targetPath -UseBasicParsing
        $downloadCount++
    }

    return $downloadCount
}

function Grab-Pdfs {
    $siteUri = [Uri] "https://cv.solom.no/"
    $destinationPath = Select-DownloadFolder

    if ([string]::IsNullOrWhiteSpace($destinationPath)) {
        return
    }

    $pdfUris = Get-PdfLinks -SiteUri $siteUri

    if (-not $pdfUris) {
        [System.Windows.Forms.MessageBox]::Show(
            "No PDF links were found on $($siteUri.AbsoluteUri).",
            "No PDFs Found"
        ) | Out-Null
        return
    }

    $downloadCount = Save-Pdfs -PdfUris $pdfUris -DestinationPath $destinationPath

    Write-Host "... PDF downloading is complete."
    [System.Windows.Forms.MessageBox]::Show(
        "Downloaded $downloadCount PDF file(s) to $destinationPath.",
        "Job Complete"
    ) | Out-Null
}

Grab-Pdfs
