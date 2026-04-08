# Pandoc Table Formats for Word Output

Pandoc supports multiple table syntaxes. All produce proper Word tables when converting to `.docx`.

## Pipe Tables (Most Common)

Simple and compatible with GitHub Flavored Markdown:

```markdown
| Left   | Center  | Right  |
|--------|:-------:|-------:|
| Cell 1 | Cell 2  | Cell 3 |
| Cell 4 | Cell 5  | Cell 6 |
```

- `|--------|` = left-aligned (default)
- `|:------:|` = center-aligned
- `|-------:|` = right-aligned

### With Caption

```markdown
| Name  | Score |
|-------|------:|
| Alice |    95 |
| Bob   |    87 |

: Student Scores for Q4 2025
```

The `: caption` line below the table becomes a **Table Caption** in Word.

## Grid Tables

Most flexible — supports multi-line cells, cell spanning, and complex content:

```markdown
+---------------+---------------+--------------------+
| Fruit         | Price         | Advantages         |
+===============+===============+====================+
| Bananas       | $1.34         | - built-in wrapper |
|               |               | - bright color     |
+---------------+---------------+--------------------+
| Oranges       | $2.10         | - cures scurvy     |
|               |               | - tasty            |
+---------------+---------------+--------------------+

: Fruit Comparison Table
```

- Use `=` for the header row separator
- Multi-line cells supported with blank lines
- Lists inside cells supported

## Simple Tables

Lightweight but limited formatting:

```markdown
  Right     Left     Center     Default
-------     ------ ----------   -------
     12     12        12            12
    123     123       123          123
      1     1          1             1

: Simple alignment example
```

## Multiline Tables

Support multi-line rows and multi-paragraph cells:

```markdown
-------------------------------------------------------------
 Centered   Default           Right Left
  Header    Aligned         Aligned Aligned
----------- ------- --------------- -------------------------
   First    row                12.0 Example of a row that
                                    spans multiple lines.

  Second    row                 5.0 Here's another one. Note
                                    the blank line between
                                    rows.
-------------------------------------------------------------

: Multiline table example
```

## Table Tips for Word Output

### Column Widths

Pandoc calculates column widths proportionally. For pipe tables, relative widths come from the header separator lengths:

```markdown
| Short | Very Long Column Name Here |
|-------|----------------------------|
| A     | B                          |
```

### Complex Content in Cells

Grid tables support:
- **Lists** inside cells
- **Code blocks** inside cells
- **Multiple paragraphs** inside cells
- **Bold/italic** formatting

### Empty Cells

Use spaces to create empty cells:

```markdown
| A | B |
|---|---|
| 1 |   |
|   | 2 |
```

### Table Width in Word

Pandoc-generated tables use the full page width by default. To control table width, customize the **Table** style in your reference document.

### Header-less Tables

Grid tables can omit headers:

```markdown
+-----+-----+
| A   | B   |
+-----+-----+
| C   | D   |
+-----+-----+
```

### Maximum Compatibility

For maximum compatibility across markdown processors and Word output:
1. Use **pipe tables** for simple data
2. Use **grid tables** for complex content (lists, multi-line cells)
3. Always include a caption with `: Caption text` when a label is needed
4. Test the conversion: `pandoc test.md -s -o test.docx`
