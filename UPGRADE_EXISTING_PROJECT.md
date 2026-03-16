# Upgrade an Existing Project to the Latest Playbook

> Bring an older project in line with the current playbook conventions.
> Run through each section, skip items that already exist.

For new projects, see [_PLAYBOOK_NEW_PROJECT.md](_PLAYBOOK_NEW_PROJECT.md).
For day-to-day conventions, see [_PLAYBOOK_EXISTING_PROJECT.md](_PLAYBOOK_EXISTING_PROJECT.md).

---

## How to Use This Guide

1. Open this file alongside the project you're upgrading
2. Work through each section top to bottom
3. Skip items the project already has
4. Commit after each section with `chore: upgrade to latest playbook — [section]`
5. Run linters after each section to catch issues early

---

## 1. Project Documentation Structure

Ensure the `docs/` folder exists with all required files. Create any that are missing:

```
docs/
├── SCHEMA.md           # Every table, column, relationship, index
├── BUSINESS_RULES.md   # Domain logic, permissions, edge cases
├── DESIGN.md           # Brand identity (colors, typography, components)
├── ARCHITECTURE.md     # Technical decisions, data model, key flows
├── CODE_QUALITY.md     # Code quality rules (from playbook)
├── TESTING.md          # Testing principles (from playbook)
├── PROJECT_SETUP.md    # Local dev, testing, deploy
└── ROADMAP.md          # Feature priorities
```

**Actions:**

- [ ] Create missing docs from templates in [project-structure.md](project-structure.md)
- [ ] Update `docs/CODE_QUALITY.md` — diff against latest [code-quality.md](code-quality.md) and merge new rules
- [ ] Update `docs/TESTING.md` — diff against latest [testing-guidelines.md](testing-guidelines.md) and merge new rules
- [ ] Ensure `docs/SCHEMA.md` reflects current database state (`bin/rails db:schema:dump` then document)
- [ ] Ensure `docs/ROADMAP.md` exists and is current

---

## 2. CLAUDE.md (Root)

The root `CLAUDE.md` should be a brief index that links to docs. Compare against the [template](project-structure.md#claudemd-template) and update:

- [ ] Links to all docs/ files listed above
- [ ] Stack table reflects current technologies
- [ ] Quick Reference section (commands, key paths)
- [ ] Mandatory Conventions section (backend + frontend rules)
- [ ] Review Checklist matches latest [_PLAYBOOK_EXISTING_PROJECT.md review checklist](_PLAYBOOK_EXISTING_PROJECT.md#review-checklist)
- [ ] Non-Negotiables section present

---

## 3. .claude/ Directory

### .claude/CLAUDE.md

This file contains Claude-specific project rules. Create it if missing, or update to match the latest template:

```markdown
## General

When a terminal command output is not accessible, use the `./tmp/commands-output/` in the current project instead of the root `/tmp`.

## Feature Development Workflow

When implementing a feature, follow this structure:

1. **Plan** — Break the feature into small, concrete implementation steps. Write them to `docs/ROADMAP.md` (or confirm they're already there). Mark items `[ ]` as you plan, `[x]` as you complete them.

2. **Implement** — Work through steps one at a time. Commit after each logical chunk. Keep `docs/ROADMAP.md` updated as you go.

3. **Test the feature** — Write tests for the new functionality. Run them and confirm they pass.

4. **Verify existing tests** — Run the full test suite (`bundle exec rspec` for Ruby, `bun test` for JS) to ensure nothing broke.

Only mark a feature complete when all four steps are done.
```

**Actions:**

- [ ] Create `.claude/CLAUDE.md` if missing
- [ ] Add the "General" section (scratch files rule) if missing
- [ ] Ensure Feature Development Workflow is present

### .claude/hooks/post-commit-audit.sh

Copy the latest hook from [hooks/post-commit-audit.sh](hooks/post-commit-audit.sh) and customize the design system checks for your project.

**Actions:**

- [ ] Copy latest `post-commit-audit.sh` to `.claude/hooks/`
- [ ] Customize the "CUSTOMIZE per project" section (border radius, opacity modifiers, etc.)
- [ ] Make it executable: `chmod +x .claude/hooks/post-commit-audit.sh`

### .claude/settings.json

Register the hook if not already done:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/post-commit-audit.sh"
          }
        ]
      }
    ]
  }
}
```

**Actions:**

- [ ] Create `.claude/settings.json` if missing
- [ ] Register post-commit-audit hook

---

## 4. Linter & Formatter Configs

Compare each config file against the latest playbook version. Update or create as needed:

| File | Source | Check |
|------|--------|-------|
| `.rubocop.yml` | [code-quality.md](code-quality.md#rubocop) | Rules match latest playbook |
| `.rubocop_todo.yml` | Auto-generated | Exists (regenerate with `bundle exec rubocop --auto-gen-config` if stale) |
| `eslint.config.mjs` | [inertia-react.md](inertia-react.md#eslint--prettier) | Has import sorting + unused import removal |
| `.prettierrc` | [inertia-react.md](inertia-react.md#eslint--prettier) | Single quotes, trailing commas, 80 width |
| `.prettierignore` | [inertia-react.md](inertia-react.md#eslint--prettier) | Skips node_modules, public, vendor, tmp |
| `.stylelintrc.json` | [inertia-react.md](inertia-react.md#stylelint) | Tailwind-aware rules |
| `.yamllint.yml` | [code-quality.md](code-quality.md#yamllint) | YAML linting for locale files |
| `jsconfig.json` | [inertia-react.md](inertia-react.md#path-alias----appfrontend) | `@` → `app/frontend/` alias |

**Actions:**

- [ ] Update each config to match latest playbook
- [ ] Ensure `package.json` has all lint/format scripts:
  ```json
  {
    "scripts": {
      "lint:js": "prettier --check 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml' && eslint app/frontend/",
      "lint:js:fix": "prettier --write 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml' && eslint app/frontend/ --fix",
      "lint:css": "stylelint \"app/frontend/**/*.css\"",
      "lint:css:fix": "stylelint \"app/frontend/**/*.css\" --fix"
    }
  }
  ```
- [ ] Run all linters and fix issues:
  ```bash
  bundle exec rubocop -A
  bun lint:js:fix
  bun lint:css:fix
  yamllint config/locales/ app/frontend/locales/
  ```

---

## 5. Frontend File Naming (kebab-case)

All frontend files (`.js`, `.jsx`, `.ts`, `.tsx`) must use kebab-case. If the project uses PascalCase or camelCase filenames, rename them:

| Old (PascalCase) | New (kebab-case) |
|------------------|-----------------|
| `Home.jsx` | `home.jsx` |
| `ForgotPassword.jsx` | `forgot-password.jsx` |
| `ThemeProvider.tsx` | `theme-provider.tsx` |
| `AppLayout.jsx` | `app-layout.jsx` |
| `ErrorBoundary.jsx` | `error-boundary.jsx` |
| `useFlashToasts.js` | `use-flash-toasts.js` |
| `useDebounce.js` | `use-debounce.js` |

Directories under `pages/` also use kebab-case: `Auth/` → `auth/`, `App/` → `app/`, `Staff/` → `staff/`.

**Actions:**

- [ ] Rename all PascalCase/camelCase frontend files to kebab-case
- [ ] Rename PascalCase directories under `pages/` to kebab-case
- [ ] Update all import paths (`@/components/ThemeProvider` → `@/components/theme-provider`)
- [ ] Update the Inertia resolve function to convert PascalCase page names from Rails to kebab-case file paths:
  ```jsx
  resolve: (name) => {
    const pages = import.meta.glob("../pages/**/*.jsx", { eager: true });
    const kebab = name
      .split("/")
      .map((segment) =>
        segment
          .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
          .replace(/([A-Z])([A-Z][a-z])/g, "$1-$2")
          .toLowerCase()
      )
      .join("/");
    return pages[`../pages/${kebab}.jsx`];
  },
  ```
- [ ] Verify the app boots and all pages render correctly

---

## 6. Gems & Dependencies

Ensure these gems are present (add any that are missing):

| Gem | Group | Purpose |
|-----|-------|---------|
| `interactor` | default | Business logic |
| `strong_migrations` | default | Safe migration checks |
| `anyway_config` | default | Typed configuration |
| `pay` | default | Stripe payments (if applicable) |
| `pg_search` | default | Full-text search (if applicable) |
| `sentry-ruby` + `sentry-rails` | default | Error tracking |
| `bullet` | development, test | N+1 detection |
| `rspec-rails` | development, test | Testing framework |
| `factory_bot_rails` | development, test | Test factories |
| `ffaker` | development, test | Fake data |
| `shoulda-matchers` | test | One-liner tests |
| `vcr` + `webmock` | test | HTTP stubbing |
| `rubocop` + extensions | development, test | Linting |
| `annotate` | development | Schema annotations on models, factories, specs |

**Actions:**

- [ ] Add missing gems, run `bundle install`
- [ ] Configure Bullet in `config/environments/development.rb` and `config/environments/test.rb` (see [code-quality.md](code-quality.md#bullet))
- [ ] Configure strong_migrations initializer if missing
- [ ] Install annotate: `bin/rails generate annotate:install`, configure settings (see [code-quality.md](code-quality.md#annotate))
- [ ] Run `bin/rails annotate_models` to annotate all existing models, factories, and specs

---

## 7. Configuration Layer

### Backend: Anyway Config

If the project accesses `ENV["X"]` directly, migrate to Anyway Config classes:

```ruby
# app/configs/stripe_config.rb
class StripeConfig < ApplicationConfig
  attr_config :public_key, :secret_key, :webhook_secret
end
```

Then use `StripeConfig.secret_key` instead of `ENV["STRIPE_SECRET_KEY"]`.

See [env-template.md](env-template.md#configuration-layer) for the full pattern.

**Actions:**

- [ ] Create `app/configs/application_config.rb` base class
- [ ] Create config classes for each service (Stripe, Google OAuth, Brevo, Sentry, etc.)
- [ ] Replace all `ENV["X"]` calls with config class accessors
- [ ] Update `.env.example` if new variables were discovered

### Frontend: Zod Schema

Ensure frontend config is validated at boot with a Zod schema. See [env-template.md](env-template.md).

---

## 8. Interactor Pattern

If the project uses service objects instead of interactors, migrate to the Interactor gem pattern:

- [ ] Add `interactor` gem if missing
- [ ] Create `app/interactors/` directory structure
- [ ] Migrate service objects to interactors (one at a time, with tests)
- [ ] Ensure controllers only authorize → call interactor → render
- [ ] Move any `validates` from models into `Validate*` interactors

See [interactors.md](interactors.md) for patterns and examples.

---

## 9. Reference Data (YAML)

If plans, roles, or other reference data live in seeds or hardcoded constants, migrate to YAML:

- [ ] Create `db/reference_data/` directory
- [ ] Move reference data to YAML files
- [ ] Add initializer to auto-load on boot
- [ ] Ensure test environment loads reference data (survives database cleaner)

See [code-quality.md](code-quality.md#reference-data) for the full pattern.

---

## 10. Dev Seed Data

If the project lacks a `dev:seed` task:

- [ ] Create `lib/tasks/dev_seeds.rake`
- [ ] Create `db/dev_seeds/` directory with seed files
- [ ] Add a `seed_record` helper for idempotent creates
- [ ] Cover every user type, plan, status, and edge case
- [ ] Verify with `bin/rails dev:seed`

See [code-quality.md](code-quality.md#development-seed-data) for conventions.

---

## 11. i18n

If any hardcoded English strings exist:

- [ ] Backend: Replace all hardcoded strings with `I18n.t()` calls
- [ ] Frontend: Replace all hardcoded strings with `useTranslation()` / `t()` calls
- [ ] Ensure locale files exist for all strings
- [ ] Run `yamllint` on locale files

See [i18n.md](i18n.md) for setup and conventions.

---

## 12. README.md

Compare against the [README template](project-structure.md#readmemd-template). Ensure it has:

- [ ] Prerequisites table
- [ ] Getting Started section (clone, install, env, db, seed, dev:seed, bin/dev)
- [ ] Testing section (rspec, jest, stylelint)
- [ ] Code Quality section (all linters)
- [ ] Dev Seed Data section
- [ ] Third-Party Services (Development) table
- [ ] VCR cassette re-recording instructions
- [ ] Release section (GitHub Actions CI/CD)
- [ ] Third-Party Services (Production) table
- [ ] Environment Variables table
- [ ] Staff Admin section (if applicable)
- [ ] Background Jobs table
- [ ] Production Access section
- [ ] Troubleshooting section
- [ ] Documentation links table

---

## 13. CI/CD

Ensure GitHub Actions CI pipeline runs all checks:

- [ ] `bundle exec rspec` — Ruby tests
- [ ] `bun test` — JS tests
- [ ] `bundle exec rubocop` — Ruby linting
- [ ] `bun lint:js` — Prettier + ESLint
- [ ] `bun lint:css` — CSS linting
- [ ] `yamllint` — YAML linting
- [ ] Auto-deploy to production on success (if using Kamal)

See [kamal-deploy.md](kamal-deploy.md#automated-deployment-github-actions) for the workflow file.

---

## 14. Final Verification

After all upgrades:

```bash
# All linters pass
bundle exec rubocop
bun lint:js
bun lint:css
yamllint config/locales/ app/frontend/locales/

# All tests pass
bundle exec rspec
bun test

# Dev seeds work
bin/rails dev:seed

# App boots cleanly
bin/dev
```

- [ ] All linters pass with zero errors
- [ ] Full test suite passes
- [ ] `bin/rails dev:seed` runs without errors
- [ ] App boots and renders correctly
- [ ] Commit everything: `chore: complete playbook upgrade`
