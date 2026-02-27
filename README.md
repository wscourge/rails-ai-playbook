# Rails AI Playbook

A structured playbook for building Rails apps with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Opinionated setup, living documentation, and automated quality enforcement.

This is the system I use to build Rails applications with Claude Code. It gives Claude the context it needs to make good decisions — architecture patterns, code quality rules, testing principles, design system conventions — so I spend less time correcting and more time building.

---

## What's in Here

### Setup & Configuration
| File | What It Does |
|------|-------------|
| [PLAYBOOK.md](PLAYBOOK.md) | Main playbook — Claude reads this when creating a new app |
| [project-structure.md](project-structure.md) | Templates for CLAUDE.md and all project docs + creation checklist |
| [brand-interview.md](brand-interview.md) | Questions to ask before building — feeds into DESIGN.md |
| [env-template.md](env-template.md) | Environment variable patterns |

### Stack-Specific Guides
| File | What It Does |
|------|-------------|
| [auth.md](auth.md) | Rails authentication + OmniAuth |
| [inertia-react.md](inertia-react.md) | Inertia + React + Vite + shadcn/ui + frontend philosophy |
| [solid-stack.md](solid-stack.md) | Solid Queue/Cache/Cable (single database) |
| [stripe-payments.md](stripe-payments.md) | Stripe CLI workflow + Pay gem |
| [kamal-deploy.md](kamal-deploy.md) | Kamal deployment on Hetzner Cloud |

### Quality & Standards (copy to each project)
| File | What It Does |
|------|-------------|
| [code-quality.md](code-quality.md) | General code quality rules — controllers, services, models, database |
| [testing-guidelines.md](testing-guidelines.md) | Testing principles — layers, naming, sad paths, mocking, E2E |
| [hooks/](hooks/) | Post-commit quality hooks with linting + design system checks |

### Feature Recipes
| File | What It Does |
|------|-------------|
| [settings-page.md](settings-page.md) | User settings (profile, billing, notifications) |
| [email-verification.md](email-verification.md) | Password reset + email verification |
| [contact-page.md](contact-page.md) | Contact form setup |
| [legal-pages.md](legal-pages.md) | Privacy Policy + Terms of Service |
| [analytics-seo.md](analytics-seo.md) | GA4, Search Console, meta tags, sitemap |
| [logo-generation.md](logo-generation.md) | Logo + favicon generation via AI |

---

## How It Works

### 1. Install

Copy this playbook to your Claude Code config directory:

```bash
git clone https://github.com/One-Man-App-Studio/rails-ai-playbook.git ~/.claude/rails-playbook
```

Then point your global `~/.claude/CLAUDE.md` at it:

```markdown
## Project Playbooks

When creating a new **Rails app**, see: `~/.claude/rails-playbook/PLAYBOOK.md`
```

### 2. Create a New App

Tell Claude you want to build something. It reads the playbook and:

1. **Interviews you** — project basics, domain model (entities, relationships, business rules), brand identity, technical requirements
2. **Scaffolds project docs** — SCHEMA.md, BUSINESS_RULES.md, DESIGN.md, ARCHITECTURE.md, CODE_QUALITY.md, TESTING.md, and more
3. **Generates the Rails app** — following the stack-specific guides as needed
4. **Sets up quality hooks** — post-commit linting and design system enforcement

### 3. Build Features

As you build, the docs **grow with the project**:
- SCHEMA.md updates with every migration
- BUSINESS_RULES.md captures edge cases as you discover them
- CODE_QUALITY.md gains project-specific rules
- The post-commit hook gets tuned to your design system

The playbook gives you a strong starting point. The project fills in the rest.

---

## The Stack

This playbook is opinionated. It assumes:

| Layer | Technology |
|-------|------------|
| **Server** | Rails + PostgreSQL |
| **Frontend** | Inertia.js + React + Vite |
| **Styling** | Tailwind + shadcn/ui |
| **Auth** | Rails sessions (+ optional OAuth) |
| **Payments** | Stripe via Pay gem |
| **Jobs** | Solid Queue (single DB) |
| **Cache** | Solid Cache (single DB) |
| **Email** | Resend (prod) / letter_opener_web (dev) |
| **Testing (Ruby)** | RSpec + FactoryBot + FFaker + Shoulda Matchers |
| **Testing (JS)** | Jest (logic only) |
| **CSS Linting** | Stylelint |
| **JS Linting** | ESLint |
| **Formatting** | Prettier (JS/TS/CSS/YAML) |
| **YAML Linting** | yamllint |
| **Business Logic** | Interactor gem |
| **Error Tracking** | Sentry |
| **Search** | pg_search (PostgreSQL full-text) |
| **i18n** | Rails I18n + react-i18next |
| **CI/CD** | GitHub Actions (auto-deploy on push to main) |
| **Hosting** | Kamal + Hetzner Cloud |

If your stack is different, the structural patterns (living docs, quality hooks, interview-first workflow) still apply — you'd just swap out the stack-specific guides.

---

## Key Ideas

**Interview first.** Claude asks about your project before writing code. Domain model, business rules, brand identity, technical requirements. This conversation becomes the documentation that guides the entire build.

**Living documentation.** Docs aren't written once and forgotten. They start with general principles from the playbook and grow with project-specific rules as you build. Claude references them on every task.

**Automated quality enforcement.** Post-commit hooks catch common violations — linting errors, hardcoded colors, raw HTML elements, unscoped database queries. Claude fixes issues before moving on.

**Business logic in interactors, always.** Controllers are thin (authorize, call interactor, render). Models are thin (scopes, associations, DB-level constraints). Interactors are where the real work happens.

---

## Adapting for Your Stack

The playbook is structured so you can swap pieces:

- **Not using Inertia?** Replace `inertia-react.md` with your frontend patterns (Hotwire, API+SPA, etc.)
- **Not using Stripe?** Remove `stripe-payments.md`, swap in your payment provider
- **Not using Kamal/Hetzner?** Replace `kamal-deploy.md` with your deployment target
- **Not using Rails?** The quality principles, testing guidelines, interview workflow, and living docs pattern work with any framework

The core value isn't the specific technologies — it's the system of structured documentation, automated enforcement, and interview-driven project setup.

---

## License

MIT
