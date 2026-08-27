# Msgbox — Message Box Templates

This document contains ready-to-paste wikitext for the `{{Msgbox}}` base template and all shortcut templates.

All styles use [Codex design tokens](https://doc.wikimedia.org/codex/latest/design-tokens/) — CSS variables that Vector 2022, Minerva (mobile), and dark mode understand natively. No `MediaWiki:Common.css` edits required.

---

## Table of Contents

1. [Template:Msgbox](#templatemsgbox)
2. [Shortcut Templates](#shortcut-templates)
   - [Template:Stub](#templatestub)
   - [Template:Citation needed](#templatecitation-needed)
   - [Template:Cleanup](#templatecleanup)
   - [Template:Original research](#templateoriginal-research)
   - [Template:Under construction](#templateunder-construction)
   - [Template:Merge](#templatemerge)
   - [Template:Delete](#templatedelete)
   - [Template:Fact checked](#templatefact-checked)
   - [Template:Unverified](#templateunverified)
3. [Codex Design Tokens Reference](#codex-design-tokens-reference)
4. [How to Add a New Type](#how-to-add-a-new-type)

---

## Template:Msgbox

**Page to create:** `Template:Msgbox`

This is the base meta-template. All shortcut templates build on top of it. The documentation is embedded directly in the template page using `<noinclude>` — it only appears when viewing the template itself, never on articles that use it.

### What it does

- Renders a left-bordered message box with optional icon
- Supports two modes:
  - **Structured:** `issue` + `fix` for simple problem/solution messages
  - **Freeform:** `text` for rich content (lists, multiple paragraphs, any wikitext)
- `text` overrides `issue`/`fix` when provided — use it for complex content
- Accepts `icon` parameter for an emoji or image to the left of the text
- Accepts `accent` and `bg` parameters to control the color scheme
- Defaults to a neutral blue notice style
- Bold and icons are applied by shortcut templates, not the base — this avoids rendering artifacts when the base template page is viewed directly
- Automatically adapts to light/dark mode via Codex tokens
- Falls back to hardcoded hex values for skins that don't support CSS variables
- Includes TemplateData for VisualEditor support — editors can insert and edit the template via the VE template dialog

### Wikitext

Paste the entire block below into `Template:Msgbox`:

```wikitext
<div style="border: 1px solid {{{border|var(--border-color-base, #a2a9b1)}}}; border-left: 10px solid {{{accent|var(--border-color-progressive, #36c)}}}; background-color: {{{bg|var(--background-color-neutral-subtle, #f8f9fa)}}}; color: var(--color-base, #202122); padding: 8px 12px; margin-bottom: 1em; line-height: 1.5; box-sizing: border-box; display: flex; align-items: center; gap: 10px;">
<div style="flex-shrink: 0; font-size: 24px;">{{{icon|}}}</div>
<div>{{#if:{{{text|}}}|{{{text|}}}|{{{issue|{{{1|}}}}}}{{{fix|{{{2|}}}}}} }}</div>
</div><noinclude>
<div style="border: 1px solid var(--border-color-base, #a2a9b1); background-color: var(--background-color-success-subtle, #ecfcf4); padding: 1em; margin-top: 1em;">
<div style="font-size: 125%; font-weight: bold; border-bottom: 1px solid var(--border-color-base, #a2a9b1); padding-bottom: 4px; margin-bottom: 8px;">Template documentation</div>

'''<code><nowiki>{{Msgbox}}</nowiki></code>''' is the base template for article message boxes. It uses [https://doc.wikimedia.org/codex/latest/design-tokens/ Codex design tokens] for automatic light/dark theme support across Vector 2022, Minerva (mobile), MonoBook, and Timeless.

== Basic usage ==

=== Simple (issue + fix) ===

<pre>
{{Msgbox
|icon=ℹ️
|issue='''Describe the problem.'''
|fix=Describe what the editor should do.
}}
</pre>

Renders as:

{{Msgbox
|icon=ℹ️
|issue='''Describe the problem.'''
|fix=Describe what the editor should do.
}}

=== Rich text (text parameter) ===

Use <code>text</code> instead of <code>issue</code>/<code>fix</code> when you need lists, multiple paragraphs, or any complex wikitext:

<pre>
{{Msgbox
|icon=⚠️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|text='''This article has multiple issues.''' Please help [[Rollerskating Wiki:Contributing|improve it]] or discuss these issues on the [[{{TALKPAGENAME}}|talk page]].
* This article '''may contain original research.'''
* This article '''needs additional citations''' for verification.
}}
</pre>

Renders as:

{{Msgbox
|icon=⚠️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|text='''This article has multiple issues.''' Please help [[Rollerskating Wiki:Contributing|improve it]] or discuss these issues on the [[{{TALKPAGENAME}}|talk page]].
* This article '''may contain original research.'''
* This article '''needs additional citations''' for verification.
}}

== Parameters ==

{| class="wikitable"
! Parameter !! Required !! Description
|-
| <code>text</code> || No || Freeform rich content. Overrides <code>issue</code> and <code>fix</code> when provided. Supports any wikitext: bold, links, lists, multiple paragraphs.
|-
| <code>issue</code> or <code>1</code> || No || Problem statement (add <code><nowiki>'''bold'''</nowiki></code> in calling templates). Used when <code>text</code> is not provided.
|-
| <code>fix</code> or <code>2</code> || No || What should be done to fix it. Appended after <code>issue</code>. Used when <code>text</code> is not provided.
|-
| <code>icon</code> || No || Emoji or image shown to the left of the text. Default: none.
|-
| <code>accent</code> || No || Left border color (CSS value or Codex token). Default: progressive blue.
|-
| <code>bg</code> || No || Background color. Default: neutral subtle.
|-
| <code>border</code> || No || Outer border color. Default: base.
|}

== Types ==

There are no hardcoded types. Instead, pass Codex tokens to <code>accent</code> and <code>bg</code> to get different styles. The recommended combinations are shown below.

=== Notice (default) ===

For general informational messages, stubs, and neutral notices. This is the default when no <code>accent</code> or <code>bg</code> is specified.

<pre>
{{Msgbox|icon=ℹ️|issue='''This is a notice.''' |fix=No action needed.}}
</pre>
{{Msgbox|icon=ℹ️|issue='''This is a notice.''' |fix=No action needed.}}

=== Warning (content and style issues) ===

For content quality problems: missing citations, original research, POV, cleanup, tone.

<pre>
{{Msgbox
|icon=⚠️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This article needs additional citations.'''
|fix=Please help improve it by adding reliable sources.
}}
</pre>
{{Msgbox
|icon=⚠️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This article needs additional citations.'''
|fix=Please help improve it by adding reliable sources.
}}

=== Error (deletion) ===

For deletion proposals, speedy deletion, and serious policy violations.

<pre>
{{Msgbox
|icon=❌
|accent=var(--border-color-error, #d33)
|bg=var(--background-color-error-subtle, #fee7e6)
|issue='''This article has been proposed for deletion.'''
|fix=Discuss on the talk page.
}}
</pre>
{{Msgbox
|icon=❌
|accent=var(--border-color-error, #d33)
|bg=var(--background-color-error-subtle, #fee7e6)
|issue='''This article has been proposed for deletion.'''
|fix=Discuss on the talk page.
}}

=== Success (resolved) ===

For resolved issues, completed reviews, or positive status.

<pre>
{{Msgbox
|icon=✅
|accent=var(--border-color-success, #14866d)
|bg=var(--background-color-success-subtle, #ecfcf4)
|issue='''This issue has been resolved.'''
|fix=You may remove this notice.
}}
</pre>
{{Msgbox
|icon=✅
|accent=var(--border-color-success, #14866d)
|bg=var(--background-color-success-subtle, #ecfcf4)
|issue='''This issue has been resolved.'''
|fix=You may remove this notice.
}}

=== Progressive (merge and move) ===

For merge proposals, split proposals, and move discussions.

<pre>
{{Msgbox
|icon=🔀
|accent=var(--border-color-progressive, #36c)
|bg=var(--background-color-progressive-subtle, #eaf3ff)
|issue='''It has been suggested that this article be merged.'''
|fix=Discuss on the talk page.
}}
</pre>
{{Msgbox
|icon=🔀
|accent=var(--border-color-progressive, #36c)
|bg=var(--background-color-progressive-subtle, #eaf3ff)
|issue='''It has been suggested that this article be merged.'''
|fix=Discuss on the talk page.
}}

=== Neutral (protection and info) ===

For page protection notices and other low-priority information.

<pre>
{{Msgbox
|icon=🔒
|accent=var(--border-color-base, #a2a9b1)
|bg=var(--background-color-neutral-subtle, #f8f9fa)
|issue='''This article is semi-protected.'''
|fix=Only autoconfirmed users may edit.
}}
</pre>
{{Msgbox
|icon=🔒
|accent=var(--border-color-base, #a2a9b1)
|bg=var(--background-color-neutral-subtle, #f8f9fa)
|issue='''This article is semi-protected.'''
|fix=Only autoconfirmed users may edit.
}}

== Codex design tokens reference ==

All tokens adapt automatically to light and dark mode in Vector 2022 and Minerva.

=== Border colors ===

{| class="wikitable"
! Token !! Light value !! Use for
|-
| <code><nowiki>var(--border-color-progressive, #36c)</nowiki></code> || style="background: #36c; color: white;" | #36c || Notice, info, merge
|-
| <code><nowiki>var(--border-color-warning, #edab00)</nowiki></code> || style="background: #edab00;" | #edab00 || Content/style issues
|-
| <code><nowiki>var(--border-color-error, #d33)</nowiki></code> || style="background: #d33; color: white;" | #d33 || Deletion, speedy
|-
| <code><nowiki>var(--border-color-success, #14866d)</nowiki></code> || style="background: #14866d; color: white;" | #14866d || Resolved, good
|-
| <code><nowiki>var(--border-color-base, #a2a9b1)</nowiki></code> || style="background: #a2a9b1;" | #a2a9b1 || Neutral, protection
|}

=== Background colors ===

{| class="wikitable"
! Token !! Light value !! Use for
|-
| <code><nowiki>var(--background-color-progressive-subtle, #eaf3ff)</nowiki></code> || style="background: #eaf3ff;" | #eaf3ff || Notice, merge
|-
| <code><nowiki>var(--background-color-warning-subtle, #fef6e7)</nowiki></code> || style="background: #fef6e7;" | #fef6e7 || Content/style issues
|-
| <code><nowiki>var(--background-color-error-subtle, #fee7e6)</nowiki></code> || style="background: #fee7e6;" | #fee7e6 || Deletion
|-
| <code><nowiki>var(--background-color-success-subtle, #ecfcf4)</nowiki></code> || style="background: #ecfcf4;" | #ecfcf4 || Resolved
|-
| <code><nowiki>var(--background-color-neutral-subtle, #f8f9fa)</nowiki></code> || style="background: #f8f9fa;" | #f8f9fa || Default/neutral
|}

=== Text colors ===

{| class="wikitable"
! Token !! Description
|-
| <code><nowiki>var(--color-base, #202122)</nowiki></code> || Primary text color
|-
| <code><nowiki>var(--color-subtle, #54595d)</nowiki></code> || Secondary/muted text
|-
| <code><nowiki>var(--color-progressive, #36c)</nowiki></code> || Link/action color
|}

== Shortcut templates ==

These templates wrap <code><nowiki>{{Msgbox}}</nowiki></code> with preset styles and icons:

{| class="wikitable"
! Template !! Icon !! Style !! Usage
|-
| <code><nowiki>{{Stub}}</nowiki></code> || 📝 || Notice (blue) || Article is too short
|-
| <code><nowiki>{{Citation needed}}</nowiki></code> || 📚 || Warning (orange) || Needs sources
|-
| <code><nowiki>{{Cleanup}}</nowiki></code> || 🧹 || Warning (orange) || Formatting/quality issues
|-
| <code><nowiki>{{Original research}}</nowiki></code> || ⚠️ || Warning (orange) || Unverified claims
|-
| <code><nowiki>{{Under construction}}</nowiki></code> || 🚧 || Notice (blue) || Work in progress
|-
| <code><nowiki>{{Merge}}</nowiki></code> || 🔀 || Progressive (blue) || Merge proposal
|-
| <code><nowiki>{{Delete}}</nowiki></code> || ❌ || Error (red) || Deletion proposal
|-
| <code><nowiki>{{Fact checked}}</nowiki></code> || ✅ || Success (green) || Verified content
|-
| <code><nowiki>{{Unverified}}</nowiki></code> || 🔍 || Warning (orange) || Not yet fact-checked
|}

== See also ==

* [[Rollerskating Wiki:Guidelines]]
* [[Rollerskating Wiki:Contributing]]
* [https://doc.wikimedia.org/codex/latest/design-tokens/ Codex Design Tokens documentation]

</div>

<templatedata>
{
    "description": "A message box for article notices, warnings, and maintenance tags. Supports both simple (issue/fix) and freeform (text) modes. Uses Codex design tokens for automatic light/dark theme support.",
    "params": {
        "text": {
            "label": "Text",
            "description": "Freeform rich content. Overrides issue and fix when provided. Supports any wikitext: bold, links, lists, paragraphs.",
            "type": "content",
            "required": false
        },
        "issue": {
            "label": "Issue",
            "description": "Short problem statement. Used when text is not provided.",
            "type": "content",
            "required": false,
            "aliases": ["1"]
        },
        "fix": {
            "label": "Fix",
            "description": "What should be done to fix the issue. Appended after issue. Used when text is not provided.",
            "type": "content",
            "required": false,
            "aliases": ["2"]
        },
        "icon": {
            "label": "Icon",
            "description": "Emoji or image shown to the left of the text.",
            "type": "string",
            "required": false,
            "suggestedvalues": ["ℹ️", "⚠️", "❌", "✅", "🔀", "🔒", "📝", "📚", "🧹", "🚧"]
        },
        "accent": {
            "label": "Accent color",
            "description": "Left border color. Use a Codex design token for automatic dark mode support.",
            "type": "string",
            "required": false,
            "default": "var(--border-color-progressive, #36c)",
            "suggestedvalues": [
                "var(--border-color-progressive, #36c)",
                "var(--border-color-warning, #edab00)",
                "var(--border-color-error, #d33)",
                "var(--border-color-success, #14866d)",
                "var(--border-color-base, #a2a9b1)"
            ]
        },
        "bg": {
            "label": "Background color",
            "description": "Background color. Use a Codex design token for automatic dark mode support.",
            "type": "string",
            "required": false,
            "default": "var(--background-color-neutral-subtle, #f8f9fa)",
            "suggestedvalues": [
                "var(--background-color-neutral-subtle, #f8f9fa)",
                "var(--background-color-warning-subtle, #fef6e7)",
                "var(--background-color-error-subtle, #fee7e6)",
                "var(--background-color-success-subtle, #ecfcf4)",
                "var(--background-color-progressive-subtle, #eaf3ff)"
            ]
        },
        "border": {
            "label": "Border color",
            "description": "Outer border color.",
            "type": "string",
            "required": false,
            "default": "var(--border-color-base, #a2a9b1)"
        }
    },
    "format": "block",
    "paramOrder": ["icon", "text", "issue", "fix", "accent", "bg", "border"]
}
</templatedata>
[[Category:Template documentation]]
</noinclude>
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `text` | No | Freeform rich content. Overrides `issue`/`fix`. Supports any wikitext. |
| `issue` or `1` | No | Problem statement (bold applied by calling templates). Used when `text` is not provided. |
| `fix` or `2` | No | What should be done to fix it. Used when `text` is not provided. |
| `icon` | No | Emoji or image shown to the left of the text. Default: none |
| `accent` | No | Left border color (CSS value or Codex token). Default: progressive blue |
| `bg` | No | Background color. Default: neutral subtle |
| `border` | No | Outer border color. Default: base |

---

## Shortcut Templates

Each of these wraps `{{Msgbox}}` with preset colors and icons so editors don't need to remember Codex tokens. Bold is applied in these templates, not in the base. Documentation is embedded in each template via `<noinclude>`.

---

### Template:Stub

**Page to create:** `Template:Stub`

Uses the default notice style (blue). Shown on articles that are too short and need expansion.

```wikitext
{{Msgbox
|icon=📝
|issue='''This article is a stub.'''
|fix=You can help the Rollerskating Wiki by [{{fullurl:{{FULLPAGENAME}}|action=edit}} expanding it].
}}<noinclude>

== Usage ==

<pre>{{Stub}}</pre>

<templatedata>
{
    "description": "Marks an article as a stub — too short and needing expansion.",
    "params": {},
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Citation needed

**Page to create:** `Template:Citation needed`

Uses the warning style (orange). Shown on articles that lack sources or references.

The optional first unnamed parameter changes "article" to "section" or any other word.

```wikitext
{{Msgbox
|icon=📚
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This {{{1|article}}} needs additional citations for verification.'''
|fix=Please help [{{fullurl:{{FULLPAGENAME}}|action=edit}} improve this article] by adding citations to reliable sources.
}}<noinclude>

== Usage ==

For an entire article:
<pre>{{Citation needed}}</pre>

For a specific section:
<pre>{{Citation needed|section}}</pre>

<templatedata>
{
    "description": "Marks an article or section as needing additional citations for verification.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Cleanup

**Page to create:** `Template:Cleanup`

Uses the warning style (orange). Shown on articles with formatting or quality issues.

```wikitext
{{Msgbox
|icon=🧹
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This {{{1|article}}} may need cleanup.'''
|fix=Please help [{{fullurl:{{FULLPAGENAME}}|action=edit}} improve it] to meet the wiki's quality standards.
}}<noinclude>

== Usage ==

<pre>{{Cleanup}}</pre>

For a section:
<pre>{{Cleanup|section}}</pre>

<templatedata>
{
    "description": "Marks an article or section as needing cleanup for formatting or quality issues.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Original research

**Page to create:** `Template:Original research`

Uses the warning style (orange). Shown on articles that contain unverified claims or personal analysis.

```wikitext
{{Msgbox
|icon=⚠️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This {{{1|article}}} may contain original research.'''
|fix=Please [{{fullurl:{{FULLPAGENAME}}|action=edit}} improve it] by verifying claims and adding citations.
}}<noinclude>

== Usage ==

<pre>{{Original research}}</pre>

For a section:
<pre>{{Original research|section}}</pre>

<templatedata>
{
    "description": "Marks an article or section as potentially containing original research or unverified claims.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Under construction

**Page to create:** `Template:Under construction`

Uses the default notice style (blue). Shown on articles that are actively being worked on.

```wikitext
{{Msgbox
|icon=🚧
|issue='''This article is under construction.'''
|fix=Content may be incomplete or change significantly.
}}<noinclude>

== Usage ==

<pre>{{Under construction}}</pre>

<templatedata>
{
    "description": "Marks an article as under construction — content may be incomplete or changing.",
    "params": {},
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Merge

**Page to create:** `Template:Merge`

Uses the progressive style (blue background). Shown when a merge with another article is proposed. Requires the target article name as the first parameter.

```wikitext
{{Msgbox
|icon=🔀
|accent=var(--border-color-progressive, #36c)
|bg=var(--background-color-progressive-subtle, #eaf3ff)
|issue='''It has been suggested that this article be merged with [[{{{1}}}]].'''
|fix=Discuss this on the [[{{TALKPAGENAME}}|talk page]].
}}<noinclude>

== Usage ==

<pre>{{Merge|Other Article Name}}</pre>

<templatedata>
{
    "description": "Proposes merging this article with another article.",
    "params": {
        "1": {
            "label": "Target article",
            "description": "The name of the article to merge with.",
            "type": "wiki-page-name",
            "required": true
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Delete

**Page to create:** `Template:Delete`

Uses the error style (red). Shown on articles proposed for deletion.

```wikitext
{{Msgbox
|icon=❌
|accent=var(--border-color-error, #d33)
|bg=var(--background-color-error-subtle, #fee7e6)
|issue='''This article has been proposed for deletion.'''
|fix=Discuss this on the [[{{TALKPAGENAME}}|talk page]].
}}<noinclude>

== Usage ==

<pre>{{Delete}}</pre>

<templatedata>
{
    "description": "Marks an article as proposed for deletion.",
    "params": {},
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Fact checked

**Page to create:** `Template:Fact checked`

Uses the success style (green). Shown on articles whose sources have been verified.

```wikitext
{{Msgbox
|icon=✅
|accent=var(--border-color-success, #14866d)
|bg=var(--background-color-success-subtle, #ecfcf4)
|issue='''This {{{1|article}}} has been fact-checked.'''
|fix=Sources have been verified as of {{{date|an unknown date}}}.
}}<noinclude>

== Usage ==

<pre>{{Fact checked}}</pre>

With a date:
<pre>{{Fact checked|date=March 2026}}</pre>

For a section:
<pre>{{Fact checked|section|date=March 2026}}</pre>

<templatedata>
{
    "description": "Marks an article or section as having been fact-checked and verified.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        },
        "date": {
            "label": "Date",
            "description": "When the fact-check was completed (e.g. \"March 2026\").",
            "type": "string",
            "required": false
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

### Template:Unverified

**Page to create:** `Template:Unverified`

Uses the warning style (orange). Shown on articles that have not yet been fact-checked.

```wikitext
{{Msgbox
|icon=🔍
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''This {{{1|article}}} has not yet been fact-checked.'''
|fix=Claims may be inaccurate or unsourced. Please help [{{fullurl:{{FULLPAGENAME}}|action=edit}} verify its content].
}}<noinclude>

== Usage ==

<pre>{{Unverified}}</pre>

For a section:
<pre>{{Unverified|section}}</pre>

<templatedata>
{
    "description": "Marks an article or section as not yet fact-checked — claims may be inaccurate or unsourced.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

---

## Codex Design Tokens Reference

These are the CSS custom properties used by the templates. Vector 2022 and Minerva define these and automatically adjust them for dark mode. The fallback value (after the comma) is used by skins that don't define the variable (MonoBook, Timeless).

### Border Colors (for `accent` parameter)

| Token | Light | Dark | Use for |
|-------|-------|------|---------|
| `var(--border-color-progressive, #36c)` | `#36c` | `#6699ff` | Notice, info, merge |
| `var(--border-color-warning, #edab00)` | `#edab00` | `#edab00` | Content/style issues |
| `var(--border-color-error, #d33)` | `#d33` | `#f55` | Deletion, speedy |
| `var(--border-color-success, #14866d)` | `#14866d` | `#14866d` | Resolved, good |
| `var(--border-color-base, #a2a9b1)` | `#a2a9b1` | `#54595d` | Neutral, protection |

### Background Colors (for `bg` parameter)

| Token | Light | Use for |
|-------|-------|---------|
| `var(--background-color-progressive-subtle, #eaf3ff)` | `#eaf3ff` | Notice, merge |
| `var(--background-color-warning-subtle, #fef6e7)` | `#fef6e7` | Content/style issues |
| `var(--background-color-error-subtle, #fee7e6)` | `#fee7e6` | Deletion |
| `var(--background-color-success-subtle, #ecfcf4)` | `#ecfcf4` | Resolved |
| `var(--background-color-neutral-subtle, #f8f9fa)` | `#f8f9fa` | Default/neutral |

### Text Colors

| Token | Description |
|-------|-------------|
| `var(--color-base, #202122)` | Primary text |
| `var(--color-subtle, #54595d)` | Secondary/muted text |
| `var(--color-progressive, #36c)` | Links and actions |

---

## How to Add a New Type

To create a new shortcut template (e.g. `Template:POV`):

1. Pick the appropriate `accent` and `bg` tokens from the reference above
2. Pick an emoji icon
3. Create the template page with this pattern:

```wikitext
{{Msgbox
|icon=⚖️
|accent=var(--border-color-warning, #edab00)
|bg=var(--background-color-warning-subtle, #fef6e7)
|issue='''The neutrality of this {{{1|article}}} is disputed.'''
|fix=Please see the discussion on the [[{{TALKPAGENAME}}|talk page]].
}}<noinclude>

== Usage ==

<pre>{{POV}}</pre>

For a section:
<pre>{{POV|section}}</pre>

<templatedata>
{
    "description": "Marks an article or section as having a neutrality dispute.",
    "params": {
        "1": {
            "label": "Scope",
            "description": "What to tag: \"article\" (default) or \"section\".",
            "type": "string",
            "required": false,
            "default": "article",
            "suggestedvalues": ["article", "section"]
        }
    },
    "format": "inline"
}
</templatedata>
[[Category:Maintenance templates]]
</noinclude>
```

4. Add it to the shortcut templates table in the `Template:Msgbox` documentation
