# Playbook Update Plan

> Comprehensive plan to update the playbook based on patterns from the `health` project.
> **Created:** 2026-03-04

---

## Overview

After analyzing the `health` project at `/Users/me/ws/tzif.io/health`, I've identified numerous patterns and improvements that should be incorporated into the playbook. This plan organizes updates by priority and complexity.

---

## Phase 1: High-Priority Updates (Essential Patterns)

### 1.1 E2E Testing with Playwright

**Status:** Partial in playbook, needs significant enhancement

The health project has a mature E2E testing setup that the playbook only mentions briefly. Need to add:

- [ ] **`spec/support/capybara.rb`** - Full Playwright driver configuration
  - Headed/headless modes via `E2E=headed|debug`
  - `PLAYWRIGHT_SLOW_MO` for debugging
  - Console error tracking module
  - Server configuration (port, host, timeouts)

- [ ] **`spec/support/system_helpers.rb`** - E2E helper module
  - `login_as(user)` - UI-based login
  - `logout` - UI-based logout  
  - `expect_page_rendered` - Page render validation
  - `take_screenshot(name)` - Debug screenshots

- [ ] **`spec/support/shared_examples/rendered_page.rb`** - Reusable assertion

- [ ] **`spec/system/console_errors_spec.rb`** - Template for JS error detection
  - Tests all public pages
  - Tests all authenticated pages
  - Pattern for catching Vite import errors, React errors, runtime exceptions

- [ ] Update **testing-guidelines.md** with expanded E2E section
  - When to write E2E vs request specs
  - Console error detection patterns
  - CI configuration for Playwright

**Files to update:**
- `testing-guidelines.md` - Expand E2E section significantly
- `project-structure.md` - Add E2E file templates

---

### 1.2 Anyway Config for Backend Configuration

**Status:** Not in playbook

The health project uses `app/configs/` with Anyway Config gem for structured configuration. This is cleaner than raw ENV vars.

- [ ] Add **config management** section to `_PLAYBOOK_NEW_PROJECT.md`
- [ ] Create new **`anyway-config.md`** playbook file with:
  - Gemfile entry
  - `app/configs/` directory structure
  - Example config classes (StripeConfig, SentryConfig, OAuthConfig)
  - YAML config files pattern (`config/stripe.yml`, etc.)
  - ENV var prefix conventions
  - Development fallbacks pattern

**Pattern:**
```ruby
# app/configs/stripe_config.rb
class StripeConfig < Anyway::Config
  config_name :stripe
  env_prefix :stripe
  
  attr_config :public_key, :secret_key, :webhook_secret
  attr_config price_pro_monthly: nil, price_pro_annual: nil
end
```

**Files to create:**
- `anyway-config.md` - New playbook file

**Files to update:**
- `_PLAYBOOK_NEW_PROJECT.md` - Reference the new file
- `project-structure.md` - Add app/configs/ to structure

---

### 1.3 Development Seeds (Separate from Production)

**Status:** Partially documented, needs enhancement

The health project has a clean separation:
- `db/seeds/` - Production seeds (reference data, plans)
- `db/dev_seeds/` - Development-only seeds (fake users, sample data)
- `lib/tasks/dev_seeds.rake` - Rake task to load dev seeds

- [ ] Expand **code-quality.md** dev seeds section with:
  - Directory structure pattern
  - `seed_record` helper for true idempotency
  - Example rake task
  - FFaker usage patterns
  - Edge case coverage checklist

**Files to update:**
- `code-quality.md` - Expand "Development Seed Data" section

---

### 1.4 Reference Data Pattern (db/data/)

**Status:** Not in playbook

The health project uses `db/data/` for YAML reference data:
- Countries, languages, time zones
- Seeded categories, types, providers
- Loaded via `db/seeds/reference_data.rb`

- [ ] Add new section to **code-quality.md** for reference data:
  - When to use YAML files vs database seeds
  - Directory structure (`db/data/<model_plural>/`)
  - Loading pattern in seeds
  - i18n considerations (EN + native names)

**Files to update:**
- `code-quality.md` - Add "Reference Data" section

---

### 1.5 CI Workflow Template

**Status:** Not in playbook

The health project has a comprehensive GitHub Actions CI workflow.

- [ ] Create new **`ci-workflow.md`** playbook file with:
  - Complete `.github/workflows/ci.yml` template
  - Security scanning (Brakeman, bundler-audit, importmap audit)
  - RuboCop with caching
  - RSpec with Playwright browser install
  - Dependabot configuration

**Files to create:**
- `ci-workflow.md` - New playbook file

**Files to update:**
- `_PLAYBOOK_NEW_PROJECT.md` - Add CI setup step

---

## Phase 2: Medium-Priority Updates (Improved Patterns)

### 2.1 Multiple Frontend Layouts

**Status:** Implied but not explicit in playbook

The health project has distinct layouts:
- `app-layout.jsx` - Main app with sidebar
- `auth-layout.jsx` - Login/signup pages
- `marketing-layout.jsx` - Public pages
- `settings-layout.jsx` - Settings with sidebar
- `staff-layout.jsx` - Staff admin

- [ ] Add to **inertia-react.md** or **project-structure.md**:
  - Layout directory structure
  - When to use each layout
  - Layout switching pattern

**Files to update:**
- `project-structure.md` - Document layout structure

---

### 2.2 Icons Wrapper Components

**Status:** Mentioned briefly, needs template

The health project wraps every lucide-react icon:
```jsx
// app/frontend/components/icons/loading.jsx
export function LoadingIcon(props) {
  return <Loader2 className={cn("animate-spin", props.className)} {...props} />;
}
```

- [ ] Add complete icons pattern to **inertia-react.md**:
  - Why wrapper components (consistent sizing, animation, tree-shaking)
  - Directory structure
  - Index file for exports
  - Common icon examples

**Files to update:**
- `inertia-react.md` - Add icons wrapper section

---

### 2.3 Server-Side Data Table Pattern

**Status:** Not in playbook

The health project has `useServerDataTable` hook for server-side pagination with URL sync.

- [ ] Add to **inertia-react.md**:
  - `Indexable` concern (already in code-quality.md)
  - `useServerDataTable` hook implementation
  - URL query param synchronization
  - Integration with `DataTable` component

**Files to update:**
- `inertia-react.md` - Add server-side table pattern

---

### 2.4 Interactors Directory Organization

**Status:** Mentioned but structure not explicit

The health project organizes interactors by domain:
```
app/interactors/
├── users/
│   ├── create_user.rb
│   ├── register.rb
│   └── validate_registration.rb
├── billing/
│   ├── get_invoices.rb
│   └── create_subscription.rb
└── profiles/
    └── ...
```

- [ ] Add to **interactors.md**:
  - Directory structure by domain
  - Naming conventions
  - When to use organizers
  - Transaction wrapping pattern

**Files to update:**
- `interactors.md` - Add organization pattern

---

### 2.5 Enhanced Review Checklist

**Status:** Exists but incomplete compared to health project

The health project CLAUDE.md has a more comprehensive checklist including E2E tests.

- [ ] Update **project-structure.md** CLAUDE.md template with:
  - E2E test items
  - Bullet gem N+1 detection
  - yamllint for locale files
  - Console error detection

**Files to update:**
- `project-structure.md` - Enhance review checklist

---

## Phase 3: Lower-Priority Updates (Nice to Have)

### 3.1 Factory Traits Pattern

**Status:** Examples exist but not comprehensive

Document common factory trait patterns:
- `:verified` / `:unverified` for email verification
- `:staff` / `:admin` / `:super_admin` for roles
- `:with_handle` for optional attributes
- `:google_oauth` for OAuth users

**Files to update:**
- `testing-guidelines.md` - Add factory traits section

---

### 3.2 Frontend Lib Structure

**Status:** Not documented

```
app/frontend/lib/
├── config.ts      # shadcn config
├── utils.js       # cn() and other utilities
├── validators.js  # Zod schemas
├── sentry.js      # Sentry init
├── i18n.js        # i18n init
└── hooks/         # Custom hooks
```

**Files to update:**
- `project-structure.md` - Document lib/ structure

---

### 3.3 Spec Directory Structure

**Status:** Basic structure exists, needs detail

```
spec/
├── interactors/    # Heavy coverage
├── requests/       # Heavy coverage
├── models/         # Medium coverage
├── services/       # If services exist
├── jobs/           # Job specs
├── lib/            # Lib specs
├── system/         # E2E specs
│   ├── public_pages_spec.rb
│   ├── auth_spec.rb
│   ├── console_errors_spec.rb
│   └── staff/
├── support/
│   ├── shared_contexts/
│   └── shared_examples/
├── cassettes/      # VCR recordings
└── factories/
```

**Files to update:**
- `testing-guidelines.md` - Expand directory structure

---

### 3.4 Roadmap Template Enhancement

**Status:** Exists but health project version is more structured

Add:
- Phase structure (MVP → Intelligence → Scale)
- More explicit legend documentation
- Task grouping patterns

**Files to update:**
- `project-structure.md` - Enhance ROADMAP.md template

---

### 3.5 Single Database for Solid Stack

**Status:** In solid-stack.md but health project uses single DB

The health project uses single PostgreSQL database for all Solid* services instead of separate SQLite databases. Document this as the recommended approach.

**Files to update:**
- `solid-stack.md` - Recommend single DB pattern

---

## Execution Order

1. **Create `ci-workflow.md`** - Self-contained, no dependencies
2. **Create `anyway-config.md`** - Self-contained, high value
3. **Update `testing-guidelines.md`** - E2E patterns (largest update)
4. **Update `code-quality.md`** - Reference data, dev seeds
5. **Update `project-structure.md`** - Structure templates, checklist
6. **Update `inertia-react.md`** - Icons, data table patterns
7. **Update `interactors.md`** - Organization pattern
8. **Update `_PLAYBOOK_NEW_PROJECT.md`** - Reference new files

---

## Files Summary

### New Files to Create
- `ci-workflow.md` - GitHub Actions CI template
- `anyway-config.md` - Backend configuration pattern

### Files to Update (Major)
- `testing-guidelines.md` - E2E testing with Playwright
- `code-quality.md` - Reference data, dev seeds enhancement
- `project-structure.md` - Enhanced templates and structure

### Files to Update (Minor)
- `_PLAYBOOK_NEW_PROJECT.md` - Reference new files
- `inertia-react.md` - Icons, data tables
- `interactors.md` - Organization
- `solid-stack.md` - Single DB recommendation
