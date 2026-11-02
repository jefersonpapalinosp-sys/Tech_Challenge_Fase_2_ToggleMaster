param(
    [string]$Source = "ToggleMaster_Fase2_Roteiro_Video_AJUSTADO.md",
    [string]$DocxOutput = "ToggleMaster_Fase2_Roteiro_Video_AJUSTADO.docx",
    [string]$PdfOutput = "ToggleMaster_Fase2_Roteiro_Video_AJUSTADO.pdf"
)

$ErrorActionPreference = "Stop"

function Remove-InlineMarkdown {
    param([string]$Text)

    $clean = $Text -replace '\*\*', ''
    $clean = $clean -replace '`', ''
    return $clean.Trim()
}

function Add-WordParagraph {
    param(
        $Document,
        [string]$Text,
        [int]$Style = -1,
        [string]$FontName = "Aptos",
        [double]$FontSize = 10.5,
        [bool]$Bold = $false,
        [double]$SpaceAfter = 6,
        [double]$LeftIndent = 0,
        [double]$FirstLineIndent = 0
    )

    $start = $Document.Content.End - 1
    $range = $Document.Range($start, $start)
    $range.Text = $Text
    $range.InsertParagraphAfter()
    $paragraphRange = $Document.Range($start, $Document.Content.End - 1)
    $paragraphRange.Style = $Style
    $paragraphRange.Font.Name = $FontName
    $paragraphRange.Font.Size = $FontSize
    $paragraphRange.Font.Bold = [int]$Bold
    $paragraphRange.ParagraphFormat.SpaceAfter = $SpaceAfter
    $paragraphRange.ParagraphFormat.LeftIndent = $LeftIndent
    $paragraphRange.ParagraphFormat.FirstLineIndent = $FirstLineIndent
    return $paragraphRange
}

function Add-MarkdownTable {
    param(
        $Document,
        [System.Collections.Generic.List[object]]$Rows
    )

    if ($Rows.Count -eq 0) {
        return
    }

    $columnCount = ($Rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    $insertRange = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $table = $Document.Tables.Add($insertRange, $Rows.Count, $columnCount)
    $table.Borders.Enable = 1
    $table.AllowAutoFit = $true
    $table.AutoFitBehavior(1)

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Rows[$rowIndex]
        for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
            $value = if ($columnIndex -lt $row.Count) { $row[$columnIndex] } else { "" }
            $cellRange = $table.Cell($rowIndex + 1, $columnIndex + 1).Range
            $cellRange.Text = Remove-InlineMarkdown $value
            $cellRange.Font.Name = "Aptos"
            $cellRange.Font.Size = 8.5
            if ($rowIndex -eq 0) {
                $cellRange.Font.Bold = 1
                $cellRange.Shading.BackgroundPatternColor = 14277081
            }
        }
    }

    $table.Rows.Item(1).HeadingFormat = -1
    $table.Range.ParagraphFormat.SpaceAfter = 2
    $table.Range.InsertParagraphAfter()
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$projectRoot = Split-Path -Parent $sourcePath
$docxPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $DocxOutput))
$pdfPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $PdfOutput))
$lines = Get-Content -LiteralPath $sourcePath -Encoding UTF8

$word = $null
$document = $null

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $document = $word.Documents.Add()

    $document.PageSetup.PaperSize = 7
    $document.PageSetup.TopMargin = $word.CentimetersToPoints(1.8)
    $document.PageSetup.BottomMargin = $word.CentimetersToPoints(1.8)
    $document.PageSetup.LeftMargin = $word.CentimetersToPoints(1.8)
    $document.PageSetup.RightMargin = $word.CentimetersToPoints(1.8)

    $normalStyle = $document.Styles.Item(-1)
    $normalStyle.Font.Name = "Aptos"
    $normalStyle.Font.Size = 10.5
    $normalStyle.ParagraphFormat.SpaceAfter = 6

    $index = 0
    while ($index -lt $lines.Count) {
        $line = $lines[$index]

        if ($line -match '^```') {
            $index++
            $codeLines = [System.Collections.Generic.List[string]]::new()
            while ($index -lt $lines.Count -and $lines[$index] -notmatch '^```') {
                $codeLines.Add($lines[$index])
                $index++
            }
            $codeText = $codeLines -join [char]11
            $codeRange = Add-WordParagraph -Document $document -Text $codeText -FontName "Consolas" -FontSize 8 -SpaceAfter 8
            $codeRange.Shading.BackgroundPatternColor = 15790320
            $codeRange.ParagraphFormat.LeftIndent = $word.CentimetersToPoints(0.3)
            $codeRange.ParagraphFormat.RightIndent = $word.CentimetersToPoints(0.3)
            $index++
            continue
        }

        if ($line -match '^\|') {
            $tableRows = [System.Collections.Generic.List[object]]::new()
            while ($index -lt $lines.Count -and $lines[$index] -match '^\|') {
                $tableLine = $lines[$index].Trim().Trim('|')
                $cells = @($tableLine -split '\|' | ForEach-Object { $_.Trim() })
                $isSeparator = ($cells | Where-Object { $_ -notmatch '^:?-{3,}:?$' }).Count -eq 0
                if (-not $isSeparator) {
                    $tableRows.Add($cells)
                }
                $index++
            }
            Add-MarkdownTable -Document $document -Rows $tableRows
            continue
        }

        if ($line -match '^# (.+)$') {
            Add-WordParagraph -Document $document -Text (Remove-InlineMarkdown $matches[1]) -Style -63 -FontSize 22 -Bold $true -SpaceAfter 12 | Out-Null
        }
        elseif ($line -match '^## (.+)$') {
            Add-WordParagraph -Document $document -Text (Remove-InlineMarkdown $matches[1]) -Style -2 -FontSize 16 -Bold $true -SpaceAfter 8 | Out-Null
        }
        elseif ($line -match '^### (.+)$') {
            Add-WordParagraph -Document $document -Text (Remove-InlineMarkdown $matches[1]) -Style -3 -FontSize 12 -Bold $true -SpaceAfter 6 | Out-Null
        }
        elseif ($line -match '^>\s*(.*)$') {
            $quote = Add-WordParagraph -Document $document -Text (Remove-InlineMarkdown $matches[1]) -FontSize 9.5 -SpaceAfter 8 -LeftIndent ($word.CentimetersToPoints(0.6))
            $quote.Font.Italic = 1
            $quote.Shading.BackgroundPatternColor = 16185078
        }
        elseif ($line -match '^[-*] (.+)$') {
            Add-WordParagraph -Document $document -Text ("• " + (Remove-InlineMarkdown $matches[1])) -SpaceAfter 3 -LeftIndent ($word.CentimetersToPoints(0.6)) -FirstLineIndent (-$word.CentimetersToPoints(0.35)) | Out-Null
        }
        elseif ($line -match '^---+$') {
            Add-WordParagraph -Document $document -Text "" -SpaceAfter 2 | Out-Null
        }
        elseif (-not [string]::IsNullOrWhiteSpace($line)) {
            $paragraph = Add-WordParagraph -Document $document -Text (Remove-InlineMarkdown $line)
            if ($line -match '^\*\*.+\*\*') {
                $paragraph.Font.Bold = 1
            }
        }

        $index++
    }

    $footer = $document.Sections.Item(1).Footers.Item(1).Range
    $footer.Text = "ToggleMaster · Tech Challenge Fase 2 · Roteiro do vídeo    "
    $footer.Font.Name = "Aptos"
    $footer.Font.Size = 8
    $footer.ParagraphFormat.Alignment = 1
    $footer.Collapse(0)
    $footer.Fields.Add($footer, -1, "PAGE", $true) | Out-Null

    $document.SaveAs2($docxPath, 16)
    $document.ExportAsFixedFormat($pdfPath, 17)

    [pscustomobject]@{
        Word = $docxPath
        Pdf = $pdfPath
        Pages = $document.ComputeStatistics(2)
    }
}
finally {
    if ($document) {
        $document.Close($false)
        [Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
    }
    if ($word) {
        $word.Quit()
        [Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
