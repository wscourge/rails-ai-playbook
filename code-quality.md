# Code Quality Guidelines

> General code quality rules for Rails apps. Copy to `docs/CODE_QUALITY.md` for new projects.
> This doc grows with the project — add project-specific rules as they emerge during development.

---

## Controllers

- **Three jobs only:** authorize, call an interactor, render. If you're writing business logic in a controller, it belongs somewhere else.
- **Never trust URL params for data access.** Always scope queries through authorization helpers. If a user shouldn't see a record, the query shouldn't return it — don't check after the fact.
- **Return 404 for unauthorized access, not 403.** Don't reveal that a record exists to someone who can't see it.
- **Strong params, always.** Whitelist every attribute explicitly. Never `.permit!`.

---

## Interactors

- **All business logic lives in interactors.** Controllers are thin. Models are thin. Interactors are where the real work happens.
- **One interactor, one purpose.** If it does two unrelated things, split it. Use `Interactor::Organizer` to compose.
- **Validate params in a dedicated `Validate*` interactor.** This is the first step in every organizer. Do NOT use Rails model validations for business rules.
- **Use `context.fail!` for expected failures** — never raise exceptions for validation or business rule violations.
- **Wrap multi-write organizers in transactions.** If step 3 fails, steps 1 and 2 roll back.
- **Interactors can call other interactors** via organizers. Models should never call interactors. Keep the dependency arrow one-directional: Controller → Interactor → Model.

---

## Jobs

- **Jobs only define configuration and call an interactor.** A job class sets queue, retries, concurrency — then delegates all work to an interactor in `perform`. No business logic in the job itself.
- **One job, one interactor.** If a job needs to do multiple things, the interactor it calls should be an `Interactor::Organizer`.
- **Name jobs after what they trigger.** `ProcessPaymentJob` calls `ProcessPayment` interactor. The mapping should be obvious.

```ruby
# Good
class ProcessPaymentJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(invoice_id) { invoice_id }

  def perform(invoice_id)
    ProcessPayment.call!(invoice_id: invoice_id)
  end
end

# Bad — business logic in the job
class ProcessPaymentJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    charge = Stripe::Charge.create(amount: invoice.total, ...)
    invoice.update!(paid_at: Time.current, charge_id: charge.id)
    UserMailer.receipt(invoice).deliver_later
  end
end
```

---

## Models

- **No business validations in models.** Models only enforce data shape at the DB level — NOT NULL, unique indexes, foreign keys, CHECK constraints. Business validation (required fields, format checks, authorization) lives in `Validate*` interactors.
- **Scopes for reusable queries.** If a `where` clause appears in more than one place, make it a scope. Named scopes make code readable.
- **Minimize callbacks.** Normalizing data in `before_validation` is fine. Triggering jobs, sending emails, or modifying other records in `after_create` is not — that belongs in an interactor where it's explicit and testable.
- **Associations tell the domain story.** Read the model file and you should understand the relationships. Use descriptive foreign key names over generic ones.

---

## Database

- **Index every foreign key.** No exceptions. Also index columns you query or sort by frequently.
- **Database constraints are the last line of defense.** `NOT NULL`, unique indexes, CHECK constraints, and foreign keys catch bugs that validations miss. Code can have bugs. Constraints can't be bypassed. Use both.
- **Migrations are append-only.** Never edit a migration that's been run. Need to change something? Write a new migration.
- **Back every association with a real foreign key.** This prevents orphaned records and makes the schema self-documenting.

---

## Authorization

- **Think in scopes, not permissions.** Don't ask "can this user do this action?" — narrow the query to only return records the user can see, then operate on the result.
- **Use constants for domain strings.** User types, statuses, categories — anything referenced in more than one place should be a constant on the model, not a string literal.
- **Type-check helpers live on the User model.** Use `current_user.admin?` etc. — never define role-check methods in controllers.

---

## Frontend

- **Pages are thin.** Over 100 lines? Extract sub-components. Complex state? Extract a hook.
- **Check [shadcn/ui Blocks](https://www.shadcn.io/blocks/) first.** Before building a custom component, see if a ready-made block exists. Use it as-is or adapt it. Only build from scratch if nothing fits.
- **Use the component library.** shadcn/ui for standard controls. Custom components only for domain-specific UI the library doesn't cover.
- **Install all shadcn/ui components upfront.** Don't add them one-by-one. Install the full set on project setup so they're always available. Make sure every component is i18n-ready (no hardcoded English in placeholders, empty states, aria labels, etc.).
- **Icons use wrapper components.** Never import directly from `lucide-react` in pages or components. Each icon has a dedicated file in `components/icons/` (e.g., `close.tsx` exports `IconClose` from Lucide). This makes icon library swaps a single-directory change.
- **Design tokens, not hardcoded values.** Use semantic color/spacing tokens, never raw color codes or pixel values.
- **Mobile first, always.** Base styles target 320px (minimum supported width). Add `sm:`, `md:`, `lg:` breakpoints to scale up — never the other way around.
- **Minimum supported width: 320px.** Nothing should overflow, clip, or require horizontal scrolling at 320px.
- **Don't skip tablets.** Explicitly handle the `md` (768px) breakpoint. Adjust grid columns, sidebar behavior, padding, and form layouts for tablet-sized screens — don't jump from phone to desktop.
- **Stylelint for CSS.** Run `bun lint:css` on all CSS files. Catches invalid properties, enforces alphabetical ordering, and knows about Tailwind directives. Fix auto-fixable issues with `bun lint:css:fix`.
- **ESLint for JS/TS code quality.** Run `bun lint` to catch errors, unused vars, and React hook issues. Fix auto-fixable issues with `bun lint:fix`.
- **Prettier for auto-formatting.** Run `bun format` to format JS/TS, CSS, and YAML files. Prettier owns all style decisions (quotes, semicolons, indentation) — ESLint only handles code quality rules.
- **Bun for JS package management.** Use `bun add`, `bun install`, `bun test`, `bunx` — never `npm` or `npx`.

---

## Error Handling

- **Raise meaningful exceptions.** Domain-specific exception classes tell you exactly what went wrong without reading a stack trace.
- **Don't rescue broadly.** `rescue => e` catches everything including typos and nil errors. Rescue specific exceptions you expect and can handle. Let unexpected errors bubble up.
- **Trust the framework.** If a record isn't found, Rails renders 404 automatically. Don't catch exceptions just to manually replicate what the framework already does.

---

## Performance

- **Prevent N+1 queries.** Use `includes` or `preload` when you know the view will access associations.
- **Denormalize sparingly but intentionally.** If a computed value is expensive to derive and queried often, denormalize it. Document why it exists and ensure it stays in sync through a single code path.
- **Paginate all list endpoints.** No endpoint should return unbounded results.

---

## Bullet (N+1 Detection) {#bullet}

**Always include the Bullet gem** in development and test environments. It detects N+1 queries, unused eager loading, and counter cache opportunities.

### Gemfile

```ruby
group :development, :test do
  gem "bullet"
end
```

### Configuration

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true           # Browser popup
  Bullet.bullet_logger = true   # log/bullet.log
  Bullet.console = true         # Browser console
  Bullet.rails_logger = true    # Rails log
  Bullet.add_footer = true      # Page footer
end

# config/environments/test.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.raise = true           # RAISE in tests — fail fast on N+1
end
```

### RSpec Integration

```ruby
# spec/support/bullet.rb
if Bullet.enable?
  RSpec.configure do |config|
    config.before(:each) { Bullet.start_request }
    config.after(:each) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end
```

---

## Ruby Class Structure

**Always use `class << self` for class methods**, never `self.method_name`. Keep class methods at the top of the class, before instance methods.

```ruby
# ✅ CORRECT
class User < ApplicationRecord
  class << self
    def find_by_email(email)
      find_by(email_address: email)
    end

    def active
      where(deactivated_at: nil)
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role == ADMIN
  end
end

# ❌ WRONG — don't use self.method_name
class User < ApplicationRecord
  def self.find_by_email(email)
    find_by(email_address: email)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def self.active  # Also wrong: class methods scattered among instance methods
    where(deactivated_at: nil)
  end
end
```

### Class Layout Order

1. Constants
2. Includes / Concerns
3. Associations
4. Enums
5. `class << self` block (all class methods)
6. Instance methods (public, then private)

---

## i18n

- **No hardcoded English anywhere.** Every user-facing string must use `I18n.t()` in Ruby and `useTranslation()` in React.
- **Keys follow a convention:** `controller.action.element` for backend, `page.section.element` for frontend.
- **See [i18n.md](i18n.md) for setup and patterns.**

---

## yamllint (YAML Linting) {#yamllint}

**Lint all YAML files** — Rails locale files (`config/locales/`) and frontend locale files (`app/frontend/locales/`). Catches syntax errors, inconsistent indentation, and trailing whitespace before they cause runtime surprises.

### Installation

```bash
brew install yamllint
```

### Configuration

```yaml
# .yamllint.yml
extends: default

rules:
  line-length: disable
  truthy:
    check-keys: false
  indentation:
    spaces: 2
  trailing-spaces: enable
  new-line-at-end-of-file: enable
  empty-lines:
    max: 1
```

### Scripts

Add to the project `Makefile` or use directly:

```bash
# Lint all locale files (backend + frontend)
yamllint config/locales/ app/frontend/locales/

# Lint a specific file
yamllint config/locales/en.yml
```

### What it catches

- **Syntax errors** — missing colons, bad indentation, duplicate keys
- **Trailing whitespace** — invisible characters that cause diffs
- **Inconsistent indentation** — enforces 2-space indent
- **Missing newline at end of file** — POSIX compliance

### Auto-formatting with Prettier

yamllint detects problems but doesn't fix them. Use **Prettier with `prettier-plugin-yaml`** to auto-format YAML files. Its defaults (2-space indent, trailing newline, consistent quoting) are aligned with the yamllint rules above.

```bash
# Format all locale YAML files
bun format

# Or target YAML specifically
bunx prettier --write 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml'
```

See the [ESLint + Prettier section in inertia-react.md](inertia-react.md#eslint--prettier) for full Prettier setup including the YAML plugin.

---

## Error Tracking (Sentry)

- **Always configure Sentry** for production error tracking.
- **Filter sensitive params** — never send passwords, tokens, or API keys to Sentry.
- **Set user context** so errors are attributable.
- **See [sentry.md](sentry.md) for setup.**

---

## General Principles

- **Naming matters more than comments.** Spend time on names. A well-named method eliminates the need for documentation.
- **Methods should do one thing.** If you're describing a method with "and" — it does too much.
- **Prefer explicit over clever.** Metaprogramming, dynamic method definitions, and dense one-liners are hard to debug and hard for the next person to understand. Write boring code.
- **Delete dead code.** Don't comment it out. Git has history.
- **Small methods, small classes, small commits.** If a method is over 15 lines, it probably does too much. If a class is over 200 lines, it has too many responsibilities.
- **Consistency over personal preference.** Follow the patterns already established in the codebase.

---

## Git Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for all commit messages.

### Format

```
type(scope): short description

Optional body explaining WHY, not WHAT.

Optional footer (e.g., BREAKING CHANGE: ...)
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature or user-facing change |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Tooling, deps, config (no production code) |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |
| `build` | Build system or external deps |

### Examples

```bash
feat(auth): add Google OAuth login
fix(billing): handle expired card error gracefully
refactor(interactors): extract address validation step
test(teams): add request specs for invitation flow
chore(deps): bump rails to 8.1
docs(schema): document team_members constraints
feat(api)!: change pagination response format
```

### Rules

- Subject line under 72 characters
- Use imperative mood: "add feature" not "added feature"
- Scope is optional but encouraged — use the feature area
- Add `!` after type/scope for breaking changes
- Body for context when the "why" isn't obvious from the subject
