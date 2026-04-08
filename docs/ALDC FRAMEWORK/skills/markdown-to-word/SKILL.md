---
name: 'markdown-to-word'
description: 'Convert Markdown files to Word (.docx) documents using pandoc. Use when asked to "convert markdown to word", "export md to docx", "generate word document from markdown", "create docx from md", "formato VS Sistemas", "documento para cliente", "generar word", or when working with .md files that need professional Word document output. Supports custom templates (including VS Sistemas branded template), table of contents, metadata, cover pages, styles, headers/footers, page breaks, images, and batch conversions. Always use the VS Sistemas template (templates/vs-sistemas.docx) unless another template is explicitly requested.'
---

# Markdown to Word (.docx) Conversion

Expert skill for converting Markdown documents to professional Microsoft Word (.docx) files using **pandoc**. Covers single-file conversions, batch processing, custom styling with reference templates, and advanced configurations for producing publication-ready Word documents.

## When to Use This Skill

- User asks to "convert markdown to word" or "export md to docx"
- User wants to generate Word documents from `.md` files
- User needs professional-looking `.docx` output with custom styles
- User wants batch conversion of multiple markdown files
- User needs a Word document with TOC, cover page, headers/footers
- User asks for "formato VS Sistemas" or "documento para cliente"
- User is preparing documentation deliverables in Word format

## Available Templates

### VS Sistemas (default): `templates/vs-sistemas.docx`

Branded template with VS Sistemas corporate identity:
- **Logo** in header (right-aligned, transparent PNG)
- **Colors**: Headings in orange #FE5000, body in black, footer in gray #808080
- **Font**: Calibri throughout (body 11pt, H1 20pt, H2 16pt, H3 14pt)
- **Footer**: "VS Sistemas Solutions SL" + page number + copyright
- **Tables**: Orange #F74F02 header row with white text
- **Blockquotes**: Orange left border, italic gray text
- **Code**: Consolas 9pt on light gray background

**All Pandoc style mappings included**: Title, Subtitle, Author, Date, Abstract, Heading 1–6, Body Text, First Paragraph, Block Text, Source Code, Verbatim Char, Strong, Emphasis, Hyperlink, List Bullet, List Number, TOC Heading, Table Caption, Image Caption, Footnote Text/Reference.

### Quick Usage

```bash
# Default: VS Sistemas template
pandoc input.md -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx -o output.docx

# With TOC
pandoc input.md -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx --toc --toc-depth=3 -o output.docx

# Full professional document
pandoc input.md -s \
  --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx \
  --toc --toc-depth=3 --number-sections \
  --metadata lang="es-ES" \
  --dpi=300 \
  -o output.docx
```

### Using YAML Front Matter (recommended)

Add this to the top of any `.md` file — pandoc reads the `reference-doc` path automatically:

```yaml
---
title: "Mejoras para Pedidos de Marketplaces"
subtitle: "Alcance de la Solución"
author: "VS Sistemas"
date: "2026-03-12"
lang: es-ES
toc: true
toc-depth: 3
reference-doc: .github/skills/markdown-to-word/templates/vs-sistemas.docx
---
```

Then simply run:

```bash
pandoc input.md -s -o output.docx
```

### Cover Page Limitation

Pandoc `--reference-doc` does NOT support cover pages. The VS Sistemas template provides header/footer/styles but no cover. For documents requiring a cover page:

1. Generate with pandoc as normal
2. Open in Word and add cover page manually, OR
3. Use the full docx-js generator approach (see `references/` for code patterns)

## Prerequisites

### Installing Pandoc

```bash
# Windows
winget install --id JohnMacFarlane.Pandoc

# macOS
brew install pandoc

# Linux (Debian/Ubuntu)
sudo apt-get install pandoc
```

## Quick Start

### Basic Conversion

```bash
# Simple conversion
pandoc input.md -o output.docx

# Standalone with structure
pandoc input.md -s -o output.docx

# With TOC
pandoc input.md -s --toc -o output.docx

# With metadata
pandoc input.md -s --metadata title="My Document" --metadata author="Author" -o output.docx
```

### Using a Reference Template

```bash
# VS Sistemas template (default for this project)
pandoc input.md -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx -o output.docx

# Any custom template
pandoc input.md -s --reference-doc=template.docx -o output.docx

# Generate pandoc default template to customize
pandoc -o custom-reference.docx --print-default-data-file reference.docx
```

## Comprehensive CLI Reference

### Core Options

| Option | Description | Example |
|--------|-------------|---------|
| `-o, --output <file>` | Output file | `-o report.docx` |
| `-s, --standalone` | Standalone document | `-s` |
| `-f, --from <format>` | Input format | `-f markdown` |
| `--reference-doc=<file>` | Word template for styles | `--reference-doc=vs-sistemas.docx` |
| `--toc` | Include table of contents | `--toc` |
| `--toc-depth=<N>` | TOC depth (default: 3) | `--toc-depth=2` |
| `--metadata <key>=<val>` | Set metadata field | `--metadata title="Report"` |
| `--resource-path=<dir>` | Search path for images | `--resource-path=./images` |
| `--number-sections` | Number section headings | `--number-sections` |
| `--highlight-style=<style>` | Code highlight style | `--highlight-style=tango` |
| `--dpi=<N>` | DPI for images | `--dpi=300` |

### Markdown Input Flavors

| Flag | Description |
|------|-------------|
| `-f markdown` | Pandoc extended Markdown (default) |
| `-f gfm` | GitHub Flavored Markdown |
| `-f commonmark` | CommonMark strict |
| `-f markdown+yaml_metadata_block` | With YAML front matter |

## YAML Front Matter for Word Output

```yaml
---
title: "Project Report"
subtitle: "Quarterly Review Q4 2025"
author:
  - "Jane Doe"
  - "John Smith"
date: "2025-12-15"
abstract: |
  This document summarizes the key findings.
lang: es-ES
toc: true
toc-depth: 3
number-sections: true
reference-doc: .github/skills/markdown-to-word/templates/vs-sistemas.docx
---
```

### Supported Metadata Fields for DOCX

| Field | Effect in Word |
|-------|---------------|
| `title` | Document title (Title style) |
| `subtitle` | Document subtitle (Subtitle style) |
| `author` | Author property (Author style) |
| `date` | Date property (Date style) |
| `abstract` | Abstract paragraph (Abstract style) |
| `lang` | Document language (e.g., `es-ES`) |
| `subject` | Document subject property |
| `keywords` | Document keywords property |

## Working with Reference Documents (Templates)

### Creating a Custom Template

1. Extract the default: `pandoc -o my-template.docx --print-default-data-file reference.docx`
2. Open in Word and customize styles (Heading 1–6, Body Text, Source Code, etc.)
3. Use: `pandoc input.md -s --reference-doc=my-template.docx -o output.docx`

### VS Sistemas Template Style Map

| Pandoc Element | Word Style | VS Sistemas Appearance |
|----------------|-----------|----------------------|
| `# Heading 1` | Heading 1 | Calibri 20pt bold, orange #FE5000 |
| `## Heading 2` | Heading 2 | Calibri 16pt, orange #FE5000 |
| `### Heading 3` | Heading 3 | Calibri 14pt, orange #FE5000 |
| `#### Heading 4` | Heading 4 | Calibri 12pt bold italic, orange |
| Normal paragraph | Body Text | Calibri 11pt, black |
| First paragraph | First Paragraph | Same as Body Text |
| `> blockquote` | Block Text | Italic gray, orange left border |
| `` `code` `` | Verbatim Char | Consolas 10pt, dark gray |
| Code block | Source Code | Consolas 9pt, #F7F7F7 bg |
| `**bold**` | Strong | Bold |
| `*italic*` | Emphasis | Italic |
| `[link](url)` | Hyperlink | Orange #F74F02, underlined |
| Table header row | (first row) | Orange #F74F02 bg, white text |
| `---` title | Title | Calibri 28pt bold, orange, centered |
| `---` subtitle | Subtitle | Calibri 16pt, gray, centered |
| `---` author | Author | Calibri 12pt, gray, centered |
| `---` date | Date | Calibri 11pt, light gray, centered |
| `---` abstract | Abstract | Calibri 11pt italic, indented |
| TOC heading | TOC Heading | Calibri 16pt bold, orange |
| TOC level 1 | toc 1 | Bold dark gray |
| TOC level 2 | toc 2 | Indented dark gray |
| TOC level 3 | toc 3 | Double-indented light gray |
| Footnote | Footnote Text | Calibri 9pt, dark gray |

For the complete reference see [references/DOCX-STYLES.md](references/DOCX-STYLES.md).

## Page Breaks

```markdown
Some text before the break.

\newpage

Text on the next page.
```

Or using raw OpenXML:

````markdown
```{=openxml}
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
```
````

## Images

```markdown
![Figure caption](images/diagram.png){ width=80% }

![Another image](photo.jpg){ width=5in height=3in }
```

Set DPI for proper sizing:

```bash
pandoc input.md -s --dpi=300 --resource-path=./images -o output.docx
```

## Tables

```markdown
| Column A | Column B | Column C |
|----------|:--------:|---------:|
| Left     | Center   | Right    |
| Data 1   | Data 2   | Data 3   |
```

For complex tables see [references/PANDOC-TABLES.md](references/PANDOC-TABLES.md).

## Batch Conversion

### Bash

```bash
for f in *.md; do
    pandoc "$f" -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx --toc -o "${f%.md}.docx"
done
```

### PowerShell

```powershell
Get-ChildItem -Filter "*.md" | ForEach-Object {
    $output = $_.BaseName + ".docx"
    pandoc $_.FullName -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx --toc -o $output
}
```

### PowerShell: Recursive

```powershell
$srcDir = "docs"; $outDir = "output"
Get-ChildItem -Path $srcDir -Filter "*.md" -Recurse | ForEach-Object {
    $rel = $_.FullName.Replace((Resolve-Path $srcDir).Path, "").TrimStart("\")
    $out = Join-Path $outDir ($rel -replace '\.md$', '.docx')
    $dir = Split-Path $out -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    pandoc $_.FullName -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx -o $out
}
```

## Advanced Recipes

### Full Professional Document

```bash
pandoc input.md -s \
  --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx \
  --toc --toc-depth=3 --number-sections \
  --metadata title="Annual Report 2025" \
  --metadata author="VS Sistemas" \
  --metadata date="December 2025" \
  --metadata lang="es-ES" \
  --dpi=300 --resource-path=./images \
  --highlight-style=tango \
  -o annual-report-2025.docx
```

### Multiple Files into One Document

```bash
pandoc chapter1.md chapter2.md chapter3.md \
  -s --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx \
  --toc --number-sections -o complete-book.docx
```

### With Lua Filters

```bash
pandoc input.md -s --lua-filter=custom-filter.lua \
  --reference-doc=.github/skills/markdown-to-word/templates/vs-sistemas.docx -o output.docx
```

## Conversion Script

For automated conversions use: [scripts/convert-md-to-docx.ps1](scripts/convert-md-to-docx.ps1)

```powershell
# Single file with VS Sistemas template
.\scripts\convert-md-to-docx.ps1 -InputFile "report.md" -Template ".github/skills/markdown-to-word/templates/vs-sistemas.docx" -Toc

# Batch
.\scripts\convert-md-to-docx.ps1 -InputDir "docs/" -Template ".github/skills/markdown-to-word/templates/vs-sistemas.docx" -Toc -Recursive
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `pandoc: command not found` | `winget install JohnMacFarlane.Pandoc` |
| Styles not applied | Verify `--reference-doc` path is correct |
| TOC not updating in Word | Right-click TOC → Update Field → Update entire table |
| Images not appearing | Use `--resource-path=./images` |
| No cover page | Pandoc limitation — add manually in Word |
| Encoding issues (Windows) | `chcp 65001`, save `.md` as UTF-8 |
| Tables misaligned | Use pipe tables with consistent separators |
| Font not available | Edit reference-doc in Word with available fonts |

## References

- [Pandoc DOCX Writer Documentation](https://pandoc.org/MANUAL.html#creating-a-custom-reference-docx)
- [Pandoc User's Guide](https://pandoc.org/MANUAL.html)
- [DOCX Styles Reference](references/DOCX-STYLES.md)
- [Pandoc Tables Reference](references/PANDOC-TABLES.md)
- [Conversion Script](scripts/convert-md-to-docx.ps1)
