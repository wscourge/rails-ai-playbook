# Brand Interview

> Questions to ask before building any new app. Answers go into `docs/DESIGN.md`.

---

## Instructions for Claude

**Before writing any code for a new project:**

1. Ask these questions conversationally (not all at once)
2. Record answers in `docs/DESIGN.md` using the template below
3. Reference the design doc when building UI components
4. Update the design doc as decisions evolve

---

## Questions to Ask

### Project Identity

1. **What's the app called?** (name, any tagline? — skip if undecided, we'll use `myapp` as a placeholder)
2. **One sentence: what does it do?**
3. **Who is the target user?** (role, technical level, context)
4. **What feeling should the app evoke?** (professional, playful, minimal, bold, warm, techy?)

### Visual Direction

5. **Are there 1-2 websites or apps whose design you like?** (for reference)
6. **Color preferences?**
   - Any colors you love or hate?
   - Industry conventions to follow or break?
   - Light + dark mode are always supported (system default). Any palette preferences for each?
7. **Typography vibe?**
   - Modern/geometric vs classic/serif?
   - Playful vs professional?
   - Any specific fonts you like?

### Component Style

8. **Border radius preference?**
   - Sharp (4px) - data-focused, precise
   - Soft (12-16px) - friendly, modern
   - Pill (full round) - playful, bold
9. **Border weight?**
   - Subtle (1px) - minimal, light
   - Emphasized (2px) - confident, solid
10. **Shadow style?**
    - None - flat design
    - Subtle - slight depth
    - Dramatic - elevated cards

### Tone & Voice

11. **How should copy read?**
    - Formal vs casual?
    - Technical vs plain language?
    - Any words/phrases to use or avoid?
12. **Error messages style?**
    - Technical and precise?
    - Friendly and apologetic?

### Practical Constraints

13. **Any brand assets already?** (logo, colors, fonts)
14. **Accessibility requirements?** (WCAG level, specific needs)
15. **Mobile-first or desktop-first?**

---

## docs/DESIGN.md Template

After the interview, create this file in the project:

```markdown
# [App Name] Design System

> Design decisions and brand guidelines for [App Name].

---

## Brand Identity

**Name:** [App name]
**Tagline:** [If any]
**One-liner:** [What it does]
**Target user:** [Who uses it]
**Feeling:** [Adjectives - e.g., "professional but approachable"]

### Reference Sites
- [Site 1](url) - what I like about it
- [Site 2](url) - what I like about it

---

## Color Palette

### Primary Colors
| Name | Value | Usage |
|------|-------|-------|
| Primary | `hsl(X X% X%)` | Main CTAs, active states |
| Primary Foreground | `hsl(X X% X%)` | Text on primary |

### Accent Colors
| Name | Value | Usage |
|------|-------|-------|
| Accent | `hsl(X X% X%)` | Secondary actions, highlights |

### Semantic Colors
| Name | Value | Usage |
|------|-------|-------|
| Success | `hsl(142 76% 36%)` | Positive states |
| Warning | `hsl(38 92% 50%)` | Caution states |
| Destructive | `hsl(0 84% 60%)` | Errors, delete actions |
| Info | `hsl(199 89% 48%)` | Informational |

### Neutrals
| Name | Value | Usage |
|------|-------|-------|
| Background | `hsl(X X% X%)` | Page background |
| Foreground | `hsl(X X% X%)` | Primary text |
| Muted | `hsl(X X% X%)` | Secondary text, borders |
| Card | `hsl(X X% X%)` | Card backgrounds |

---

## Typography

### Font Stack
- **Display/Headings:** [Font name] → `--font-heading` in `@theme`
- **Body:** [Font name] → `--font-body` in `@theme`
- **Monospace:** [Font name]

### Font Loading

Load fonts from Google Fonts or local files. Add the `<link>` in the HTML head, then set the `@theme` tokens:

```css
/* Example: Different heading and body fonts */
@theme {
  --font-heading: "Plus Jakarta Sans", ui-sans-serif, system-ui, sans-serif;
  --font-body: "Inter", ui-sans-serif, system-ui, sans-serif;
}
```

Headings (`h1`–`h6`) automatically use `font-heading`. Everything else uses `font-body`. To override inline, use `className="font-heading"` or `className="font-body"`.

### Type Scale
| Element | Size | Weight | Font |
|---------|------|--------|------|
| H1 | 3rem | 700 | Display |
| H2 | 2.25rem | 700 | Display |
| H3 | 1.875rem | 600 | Display |
| Body | 1rem | 400 | Body |
| Small | 0.875rem | 400 | Body |

---

## Component Patterns

### Borders
- **Radius:** [sharp/soft/pill] - `[value]`
- **Weight:** [subtle/emphasized] - `[value]`

### Shadows
- **Style:** [none/subtle/dramatic]
- **Card shadow:** `[value]`
- **Elevated shadow:** `[value]`

### Buttons
- Primary: [description]
- Secondary: [description]
- Ghost: [description]

### Cards
- Default: [border, shadow, radius]
- Elevated: [for important content]

---

## Tone & Voice

**Style:** [Formal/Casual/Technical/Friendly]

**Do:**
- [Guideline]
- [Guideline]

**Don't:**
- [Anti-pattern]
- [Anti-pattern]

**Error messages:** [Style description]

---

## Layout

**Approach:** [Mobile-first / Desktop-first]
**Max content width:** [value]
**Spacing scale:** [Tailwind default / custom]

---

## Accessibility

**Target:** [WCAG AA / AAA]
**Requirements:**
- [Specific requirement]
- [Specific requirement]
```

---

## After Creating docs/DESIGN.md

1. Add link to project's CLAUDE.md
2. Reference when building any UI component
3. Update as design decisions evolve
4. Use Tailwind `@theme` block to implement color tokens
