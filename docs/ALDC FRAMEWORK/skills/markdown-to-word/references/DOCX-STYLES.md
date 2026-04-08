# DOCX Style Reference for Pandoc

Complete mapping between Markdown/Pandoc elements and Word (.docx) style names. Customize these styles in your `reference.docx` template to control the appearance of generated Word documents.

## Paragraph Styles

| Markdown Element | Word Style Name | Notes |
|-----------------|----------------|-------|
| `# Heading` | **Heading 1** | Top-level heading |
| `## Heading` | **Heading 2** | Second-level heading |
| `### Heading` | **Heading 3** | Third-level heading |
| `#### Heading` | **Heading 4** | Fourth-level heading |
| `##### Heading` | **Heading 5** | Fifth-level heading |
| `###### Heading` | **Heading 6** | Sixth-level heading |
| Normal text | **Body Text** | Default paragraph after first |
| First paragraph after heading | **First Paragraph** | No indent paragraph |
| `> blockquote` | **Block Text** | Indented paragraph |
| Fenced code block | **Source Code** | Monospaced block |
| Indented code block | **Source Code** | Same as fenced |
| Figure caption | **Image Caption** | Below images |
| Table caption | **Table Caption** | Below tables |
| YAML `abstract` | **Abstract** | Document abstract |
| YAML `title` | **Title** | Cover page title |
| YAML `subtitle` | **Subtitle** | Cover page subtitle |
| YAML `author` | **Author** | Cover page author |
| YAML `date` | **Date** | Cover page date |
| `---` horizontal rule | **Horizontal Rule** | Page separator |
| TOC title | **TOC Heading** | Table of contents heading |

## List Styles

| Markdown Element | Word Style Name | Notes |
|-----------------|----------------|-------|
| `- item` | **List Bullet** | Unordered list (loose) |
| `- item` (compact) | **Compact** | Unordered list (tight/no blank lines) |
| `1. item` | **List Number** | Ordered list |
| Nested bullet | **List Bullet 2–5** | Nesting levels 2–5 |
| Nested number | **List Number 2–5** | Nesting levels 2–5 |
| Definition term | **Definition Term** | Definition list term |
| Definition desc | **Definition** | Definition list description |

## Character (Inline) Styles

| Markdown Element | Word Style Name | Notes |
|-----------------|----------------|-------|
| `**bold**` | **Strong** | Character style (Bold) |
| `*italic*` | **Emphasis** | Character style (Italic) |
| `` `code` `` | **Verbatim Char** | Inline monospaced |
| `[link](url)` | **Hyperlink** | Clickable link |
| `~~strikethrough~~` | **Strikethrough** | Struck-through text |
| Superscript `^text^` | **Superscript** | Raised text |
| Subscript `~text~` | **Subscript** | Lowered text |
| Small caps `[text]{.smallcaps}` | **SmallCaps** | Small capital letters |

## Table Styles

| Element | Word Style Name | Notes |
|---------|----------------|-------|
| Table | **Table** | Default table style |
| Header row | Uses **Header Row** toggle | First row of table |
| Table alignment | Per-cell alignment | Left/Center/Right from markdown |

## Footnote Styles

| Element | Word Style Name | Notes |
|---------|----------------|-------|
| Footnote marker | **Footnote Reference** | Superscript number in text |
| Footnote text | **Footnote Text** | Content at page bottom |

## TOC (Table of Contents) Styles

| Element | Word Style Name | Notes |
|---------|----------------|-------|
| TOC heading | **TOC Heading** | "Table of Contents" title |
| Level 1 entry | **TOC 1** | Maps to Heading 1 |
| Level 2 entry | **TOC 2** | Maps to Heading 2 |
| Level 3 entry | **TOC 3** | Maps to Heading 3 |

## Header/Footer Styles

These are set in the reference document's headers and footers sections in Word:

- **Header**: Set in the header area of the reference document
- **Footer**: Set in the footer area of the reference document
- **Page Number**: Configured within header/footer

## How to Customize

1. Generate default reference:
   ```bash
   pandoc -o my-reference.docx --print-default-data-file reference.docx
   ```

2. Open `my-reference.docx` in Microsoft Word

3. Modify styles via **Home → Styles** panel:
   - Right-click a style → **Modify...**
   - Change font, size, color, spacing, borders
   - Set **Automatically update** if desired

4. Edit headers/footers:
   - Double-click header/footer area
   - Add page numbers, title, logos

5. Save and use:
   ```bash
   pandoc input.md -s --reference-doc=my-reference.docx -o output.docx
   ```

## Tips

- The **content** of the reference document is ignored — only **styles** are extracted
- Always include all heading levels (1–6) in the reference document even if empty
- Test with a sample markdown that uses all elements to verify styles
- Keep the reference document version-controlled alongside your project
