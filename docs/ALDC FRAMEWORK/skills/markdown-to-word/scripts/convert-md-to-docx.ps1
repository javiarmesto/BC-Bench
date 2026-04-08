<#
.SYNOPSIS
    Convert Markdown files to Word (.docx) using pandoc.

.DESCRIPTION
    Converts one or more Markdown (.md) files to Microsoft Word (.docx) format
    using pandoc. Supports custom reference templates, table of contents,
    numbered sections, and batch/recursive processing.

.PARAMETER InputFile
    Path to a single Markdown file to convert.

.PARAMETER InputDir
    Path to a directory containing Markdown files for batch conversion.

.PARAMETER OutputDir
    Directory for output files. Defaults to same directory as input.

.PARAMETER Template
    Path to a Word reference document (.docx) for styling.

.PARAMETER Toc
    Include a table of contents.

.PARAMETER TocDepth
    Depth of the table of contents (default: 3).

.PARAMETER NumberSections
    Add numbering to section headings.

.PARAMETER Dpi
    DPI for image resolution (default: 300).

.PARAMETER ResourcePath
    Additional paths to search for images (semicolon-separated).

.PARAMETER Recursive
    When using -InputDir, process subdirectories recursively.

.PARAMETER Lang
    Document language (e.g., "es-ES", "en-US").

.EXAMPLE
    .\convert-md-to-docx.ps1 -InputFile "report.md"

.EXAMPLE
    .\convert-md-to-docx.ps1 -InputFile "report.md" -Template "template.docx" -Toc

.EXAMPLE
    .\convert-md-to-docx.ps1 -InputDir "docs/" -Template "template.docx" -Toc -Recursive

.EXAMPLE
    .\convert-md-to-docx.ps1 -InputFile "report.md" -Lang "es-ES" -NumberSections -Dpi 300
#>

[CmdletBinding(DefaultParameterSetName = 'SingleFile')]
param(
    [Parameter(ParameterSetName = 'SingleFile', Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputFile,

    [Parameter(ParameterSetName = 'BatchDir', Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$InputDir,

    [string]$OutputDir,

    [ValidateScript({ if ($_) { Test-Path $_ -PathType Leaf } else { $true } })]
    [string]$Template,

    [switch]$Toc,

    [ValidateRange(1, 6)]
    [int]$TocDepth = 3,

    [switch]$NumberSections,

    [ValidateRange(72, 600)]
    [int]$Dpi = 300,

    [string]$ResourcePath,

    [switch]$Recursive,

    [string]$Lang
)

# --- Functions ---

function Test-PandocInstalled {
    try {
        $null = Get-Command pandoc -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error @"
pandoc is not installed or not in PATH.

Install pandoc:
  winget install --id JohnMacFarlane.Pandoc
  choco install pandoc
  scoop install pandoc

Download: https://pandoc.org/installing.html
"@
        return $false
    }
}

function ConvertTo-Docx {
    param(
        [string]$Source,
        [string]$Destination
    )

    $args = @($Source, '-s')

    if ($Template) {
        $args += "--reference-doc=$Template"
    }

    if ($Toc) {
        $args += '--toc'
        $args += "--toc-depth=$TocDepth"
    }

    if ($NumberSections) {
        $args += '--number-sections'
    }

    if ($Dpi -ne 96) {
        $args += "--dpi=$Dpi"
    }

    if ($ResourcePath) {
        $args += "--resource-path=$ResourcePath"
    }

    if ($Lang) {
        $args += "--metadata=lang:$Lang"
    }

    $args += '-o'
    $args += $Destination

    Write-Verbose "pandoc $($args -join ' ')"

    & pandoc @args

    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item $Destination).Length
        $sizeKB = [math]::Round($size / 1024, 1)
        Write-Host "  [OK] $(Split-Path $Source -Leaf) -> $(Split-Path $Destination -Leaf) ($sizeKB KB)" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  [FAIL] $(Split-Path $Source -Leaf)" -ForegroundColor Red
        return $false
    }
}

# --- Main ---

if (-not (Test-PandocInstalled)) {
    exit 1
}

$files = @()
$basePath = ""

if ($PSCmdlet.ParameterSetName -eq 'SingleFile') {
    $files += Get-Item $InputFile
    $basePath = Split-Path $InputFile -Parent
}
else {
    $searchParams = @{
        Path   = $InputDir
        Filter = '*.md'
    }
    if ($Recursive) {
        $searchParams['Recurse'] = $true
    }
    $files = Get-ChildItem @searchParams
    $basePath = Resolve-Path $InputDir
}

if ($files.Count -eq 0) {
    Write-Warning "No .md files found."
    exit 0
}

Write-Host "`nMarkdown to Word Conversion" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "Files to convert: $($files.Count)"
if ($Template) { Write-Host "Template: $Template" }
if ($Toc) { Write-Host "Table of Contents: depth $TocDepth" }
Write-Host ""

$success = 0
$failed = 0

foreach ($file in $files) {
    if ($OutputDir) {
        if ($Recursive -and $basePath) {
            $relativePath = $file.FullName.Replace($basePath.ToString(), "").TrimStart("\")
            $outputPath = Join-Path $OutputDir ($relativePath -replace '\.md$', '.docx')
        }
        else {
            $outputPath = Join-Path $OutputDir ($file.BaseName + ".docx")
        }
        $outputFolder = Split-Path $outputPath -Parent
        if (-not (Test-Path $outputFolder)) {
            New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        }
    }
    else {
        $outputPath = Join-Path $file.DirectoryName ($file.BaseName + ".docx")
    }

    if (ConvertTo-Docx -Source $file.FullName -Destination $outputPath) {
        $success++
    }
    else {
        $failed++
    }
}

Write-Host "`n--------------------------" -ForegroundColor Cyan
Write-Host "Results: $success OK, $failed failed out of $($files.Count) files" -ForegroundColor $(if ($failed -gt 0) { 'Yellow' } else { 'Green' })
