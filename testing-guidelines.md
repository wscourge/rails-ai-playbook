# Testing Guidelines

> General testing principles for Rails apps. Copy to `docs/TESTING.md` for new projects.
> This doc grows with the project — add project-specific testing patterns as they emerge.

---

## Testing Layers

### Ruby (RSpec)

| Layer | Tool | Purpose | Volume |
|-------|------|---------|--------|
| **Interactors** | RSpec | Business logic, validations, orchestration | Heavy |
| **Requests** | RSpec request specs | Authorization, correct response/props | Heavy |
| **Models** | RSpec | Associations, scopes, computed attributes | Medium |
| **E2E (System)** | Capybara + Playwright | Critical happy paths in a real browser | Light |

### JavaScript (Jest)

| Layer | Tool | Purpose | Volume |
|-------|------|---------|--------|
| **Utility functions** | Jest | Pure logic, helpers, formatters | Medium |
| **Hooks** | Jest | Custom React hooks with logic | Light |
| **Validators** | Jest | Frontend validation schemas | Medium |

**Do NOT test React components with Jest.** Component rendering, user interactions, and visual regressions are covered by E2E tests (Playwright). Jest is strictly for unit-testing JavaScript/TypeScript logic — utility functions, validation schemas, custom hooks with business logic, and data transformations.

**Test at the lowest possible layer.** If you can verify it in an interactor test, don't write a request test. If you can verify it in a request test, don't write a browser test. Higher layers are slower, flakier, and harder to debug.

---

## RSpec Setup

### Gemfile

```ruby
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "ffaker"
  gem "shoulda-matchers"
  gem "vcr"
  gem "webmock"
end
```

### Install

```bash
bin/rails generate rspec:install
```

### Directory Structure

```
spec/
├── spec_helper.rb
├── rails_helper.rb
├── interactors/
│   ├── create_user_spec.rb
│   └── ...
├── models/
│   ├── user_spec.rb
│   └── ...
├── requests/
│   ├── api/
│   │   └── v1/
│   │       └── users_spec.rb
│   └── pages/
│       └── dashboard_spec.rb
├── support/
│   ├── factory_bot.rb
│   ├── shoulda_matchers.rb
│   ├── vcr.rb
│   ├── reference_data.rb
│   ├── factories/       # One file per model: <model_plural>.rb
│   │   ├── users.rb
│   │   ├── staffs.rb
│   │   ├── contact_requests.rb
│   │   └── ...
│   ├── cassettes/       # VCR recordings (committed to git)
│   │   ├── stripe/
│   │   │   ├── create_customer.yml
│   │   │   └── create_subscription.yml
│   │   └── ...
│   ├── shared_contexts/
│   │   ├── authenticated_user.rb
│   │   └── staff_user.rb
│   └── shared_examples/
│       ├── unauthorized_access.rb
│       └── paginated_endpoint.rb
└── system/
    └── user_flows_spec.rb
```

### rails_helper.rb Essentials

```ruby
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  # Reference data (plans, roles, etc.) loads on app boot via initializer.
  # With transactional fixtures, it persists across all tests.
  # No need to create plans/roles in specs — they're always present.
end
```

### Support Files

```ruby
# spec/support/factory_bot.rb
FactoryBot.definition_file_paths = ["spec/support/factories"]

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

# spec/support/shoulda_matchers.rb
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# spec/support/reference_data.rb
#
# Reference data (plans, roles, categories) loads automatically on app boot
# via config/initializers/reference_data.rb. With transactional fixtures
# (the default), this data persists across all tests.
#
# If you use DatabaseCleaner with truncation for system tests, configure it
# to exclude reference data tables:
#
# RSpec.configure do |config|
#   config.before(:each, type: :system) do
#     DatabaseCleaner.strategy = :truncation, {
#       except: %w[plans roles categories]
#     }
#   end
# end
```
### VCR + WebMock Setup

VCR records real HTTP responses as YAML "cassettes" and replays them in future test runs. WebMock blocks all unrecorded HTTP requests so nothing leaks to external services.

```ruby
# spec/support/vcr.rb
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/support/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Allow localhost for Capybara/Playwright system tests
  config.ignore_localhost = true

  # ── Filter sensitive env vars from cassettes ──────────────────
  # Every env var listed here gets replaced with a placeholder
  # in recorded cassettes so secrets are never committed to git.
  # Uses Anyway Config naming convention (see env-template.md).
  {
    "STRIPE_SECRET_KEY"        => "sk_test_VCR_PLACEHOLDER",
    "STRIPE_PUBLIC_KEY"        => "pk_test_VCR_PLACEHOLDER",
    "STRIPE_WEBHOOK_SECRET"    => "whsec_VCR_PLACEHOLDER",
    "GOOGLE_OAUTH_CLIENT_ID"   => "VCR_GOOGLE_CLIENT_ID",
    "GOOGLE_OAUTH_CLIENT_SECRET" => "VCR_GOOGLE_CLIENT_SECRET",
    "BREVO_API_KEY"             => "xkeysib-VCR_PLACEHOLDER",
    "BREVO_SMTP_PASSWORD"       => "xsmtpsib-VCR_PLACEHOLDER",
    "SENTRY_DSN"               => "https://vcr@vcr.ingest.sentry.io/0",
    "LLM_OPENAI_API_KEY"       => "sk-VCR_PLACEHOLDER",
    "LLM_ANTHROPIC_API_KEY"    => "sk-ant-VCR_PLACEHOLDER",
  }.each do |env_var, placeholder|
    if ENV[env_var].present?
      config.filter_sensitive_data(placeholder) { ENV[env_var] }
    end
  end

  # Default: block all unrecorded HTTP requests
  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri body]
  }
end

# Block all HTTP by default (even outside VCR cassettes)
WebMock.disable_net_connect!(allow_localhost: true)
```

#### Using VCR in specs

```ruby
# Option 1: metadata tag (recommended)
RSpec.describe Stripe::CreateSubscription, type: :interactor, vcr: true do
  # Cassette auto-named from spec description:
  # spec/support/cassettes/Stripe_CreateSubscription/creates_a_subscription.yml
  it "creates a subscription" do
    result = described_class.call(user: user, price_id: "price_xxx")
    expect(result).to be_a_success
  end
end

# Option 2: explicit cassette name
it "charges the customer" do
  VCR.use_cassette("stripe/charge_customer") do
    result = ChargeCustomer.call(user: user)
    expect(result).to be_a_success
  end
end
```

#### Re-recording cassettes

When an API changes or you need fresh recordings:

```bash
# Delete specific cassette and re-run the spec
rm spec/support/cassettes/stripe/create_subscription.yml
bundle exec rspec spec/interactors/stripe/create_subscription_spec.rb

# Delete ALL cassettes and re-record everything
rm -rf spec/support/cassettes
bundle exec rspec
```

**You must have real API credentials in `.env` to re-record.** See the README's "Re-recording VCR Cassettes" section for which env vars each service needs.

#### VCR env vars reference

These env vars are needed **only when re-recording cassettes** (not for normal test runs). Uses Anyway Config naming convention:

| Env var | Service | Where to get it |
|---------|---------|-----------------|
| `STRIPE_SECRET_KEY` | Stripe | [Dashboard → API keys](https://dashboard.stripe.com/test/apikeys) (test mode) |
| `STRIPE_PUBLIC_KEY` | Stripe | Same page |
| `STRIPE_WEBHOOK_SECRET` | Stripe | `stripe listen` CLI output |
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuth | [Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials) |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google OAuth | Same page |
| `BREVO_API_KEY` | Brevo (email + SMS) | [Brevo dashboard → SMTP & API](https://app.brevo.com) |
| `BREVO_SMTP_PASSWORD` | Brevo (SMTP) | [Brevo dashboard → SMTP & API](https://app.brevo.com) |
| `SENTRY_DSN` | Sentry | [Sentry → Project Settings](https://sentry.io) |
| `LLM_OPENAI_API_KEY` | OpenAI (via ruby_llm) | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `LLM_ANTHROPIC_API_KEY` | Anthropic (via ruby_llm) | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |

> Add rows here as you integrate new external APIs. Every service that makes HTTP requests in the app must have its credentials listed here.

#### Rules

- **Cassettes are committed to git.** They are deterministic test fixtures — everyone on the team gets the same test results without needing API credentials.
- **Filter every secret.** Add `filter_sensitive_data` for every env var that appears in HTTP traffic. Verify cassette YAML files contain no real keys before committing.
- **One cassette scope per external service.** Organize cassettes in subdirectories: `spec/support/cassettes/stripe/`, `spec/support/cassettes/openai/`, etc.
- **Re-record when APIs change.** If a test fails because the cassette response no longer matches the API, delete the cassette and re-record with real credentials.
- **WebMock blocks everything.** If a test makes an HTTP call without a VCR cassette, it fails immediately. This is intentional — no accidental network calls in tests.
---

## Shared Contexts & Shared Examples

**Use `shared_context` for common setup** (authentication, tenant scoping, etc.) and **`shared_example` for reusable behavior assertions** (unauthorized access, pagination, soft-delete). Keep them in `spec/support/shared_contexts/` and `spec/support/shared_examples/`.

### Shared Contexts

```ruby
# spec/support/shared_contexts/authenticated_user.rb

RSpec.shared_context "authenticated user" do
  let(:current_user) { create(:user) }

  before { sign_in(current_user) }
end

# spec/support/shared_contexts/staff_user.rb

RSpec.shared_context "staff user" do
  let(:current_user) { create(:user) }
  let!(:staff) { create(:staff, user: current_user) }

  before { sign_in(current_user) }
end

# spec/support/shared_contexts/admin_user.rb

RSpec.shared_context "admin user" do
  let(:current_user) { create(:user) }
  let!(:staff) { create(:staff, :admin, user: current_user) }

  before { sign_in(current_user) }
end
```

#### Usage

```ruby
RSpec.describe "Staff Dashboard", type: :request do
  include_context "staff user"

  describe "GET /staff" do
    it "renders the dashboard" do
      get "/staff"
      expect(response).to have_http_status(:ok)
    end
  end
end
```

### Shared Examples

```ruby
# spec/support/shared_examples/unauthorized_access.rb

RSpec.shared_examples "unauthorized access" do |method, path|
  context "when not authenticated" do
    it "redirects to login" do
      send(method, path)
      expect(response).to redirect_to(login_path)
    end
  end

  context "when user is not staff" do
    include_context "authenticated user"

    it "returns 404" do
      send(method, path)
      expect(response).to have_http_status(:not_found)
    end
  end
end

# spec/support/shared_examples/paginated_endpoint.rb

RSpec.shared_examples "paginated endpoint" do
  it "returns paginated results" do
    expect(json_response).to have_key("data")
    expect(json_response).to have_key("meta")
    expect(json_response["meta"]).to include(
      "current_page", "per_page", "total_pages", "total_count"
    )
  end
end

# spec/support/shared_examples/soft_deletable.rb

RSpec.shared_examples "soft deletable" do |factory_name|
  let(:record) { create(factory_name) }

  it "soft deletes instead of destroying" do
    record.discard
    expect(record.reload.discarded_at).to be_present
  end

  it "is excluded from default scope" do
    record.discard
    expect(described_class.kept).not_to include(record)
  end
end
```

#### Usage

```ruby
RSpec.describe "Staff::ContactRequests", type: :request do
  it_behaves_like "unauthorized access", :get, "/staff/contact_requests"

  describe "GET /staff/contact_requests" do
    include_context "staff user"

    it "lists contact requests" do
      create_list(:contact_request, 3)
      get "/staff/contact_requests"
      expect(response).to have_http_status(:ok)
    end
  end
end
```

### When to Extract

- **Shared context:** when 3+ specs use the same `let` + `before` setup
- **Shared example:** when 3+ specs assert the same behavioral contract
- **Don't over-abstract.** If a shared example needs many parameters to work, it's too generic — just write the tests inline.

---

## Jest Setup

### Installation

```bash
npm install --save-dev jest @types/jest ts-jest
```

### jest.config.js

```js
module.exports = {
  testEnvironment: "node",
  roots: ["<rootDir>/app/frontend"],
  testMatch: ["**/__tests__/**/*.test.{js,jsx,ts,tsx}"],
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/app/frontend/$1",
  },
  transform: {
    "^.+\\.(ts|tsx|js|jsx)$": "ts-jest",
  },
};
```

### Directory Structure

```
app/frontend/
├── lib/
│   ├── validators.ts
│   ├── formatters.ts
│   ├── __tests__/
│   │   ├── validators.test.ts
│   │   └── formatters.test.ts
├── hooks/
│   ├── use-debounce.ts
│   ├── __tests__/
│   │   └── use-debounce.test.ts
```

### What to Test with Jest

```ts
// ✅ DO: Test validation schemas
import { validateEmail, validateSignupForm } from "@/lib/validators";

describe("validateEmail", () => {
  it("rejects empty email", () => {
    expect(validateEmail("")).toEqual({ valid: false, error: "Email is required" });
  });

  it("rejects invalid format", () => {
    expect(validateEmail("not-an-email")).toEqual({
      valid: false, error: "Invalid email format",
    });
  });

  it("accepts valid email", () => {
    expect(validateEmail("user@example.com")).toEqual({ valid: true });
  });
});

// ✅ DO: Test utility/helper functions
import { formatCurrency, pluralize } from "@/lib/formatters";

describe("formatCurrency", () => {
  it("formats cents to dollars", () => {
    expect(formatCurrency(1999)).toBe("$19.99");
  });
});

// ❌ DON'T: Test React components — that's what E2E is for
// ❌ DON'T: Test component rendering, clicks, or visual output
```

### package.json Scripts

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch"
  }
}
```

---

## Principles

### Test the contract, not the implementation

Assert what happens (output, side effects, state changes), not how it happens internally. Tests that verify method calls or internal ordering break on every refactor and provide zero confidence.

### Name tests like sentences

`it "prevents deactivated user from logging in"` not `it "test_auth_edge_case_4"`. Someone should be able to read test names alone and understand every behavior the system supports.

### Every bug gets a regression test

Before you fix a bug, write a test that reproduces it. Watch it fail. Fix the code. Watch it pass. This guarantees the same bug never ships twice.

### Don't test the framework

Rails already tests that associations and built-in features work. Test your business rules — the things that are unique to your domain and would break if someone changed them.

### Cover the sad paths

Happy paths are obvious and rarely where bugs live. The real value is in: invalid inputs, unauthorized access, state transitions that shouldn't be allowed, empty collections, nil values, and race conditions.

### Tests are documentation

A new developer should be able to read your spec file and understand what the feature does, what the edge cases are, and what's not allowed — without reading the implementation.

### Arrange-Act-Assert, always

Setup the world (`let` / `before`), do the thing (`subject` or inline call), check the result (`expect`). One concept per test. If a test fails, you should know exactly what broke from the test name alone.

### Flaky tests are worse than no tests

A test that passes 95% of the time erodes trust in the entire suite. Fix flaky tests immediately or delete them. Never skip them.

---

## RSpec Patterns

### Interactor Specs

```ruby
RSpec.describe CreateUser, type: :interactor do
  subject(:context) { described_class.call(params) }

  let(:params) { { email: "user@example.com", name: "Jane" } }

  context "when params are valid" do
    it "succeeds" do
      expect(context).to be_a_success
    end

    it "creates a user" do
      expect { context }.to change(User, :count).by(1)
    end

    it "provides the user" do
      expect(context.user).to be_persisted
      expect(context.user.email).to eq("user@example.com")
    end
  end

  context "when email is missing" do
    let(:params) { { name: "Jane" } }

    it "fails" do
      expect(context).to be_a_failure
    end

    it "provides an error message" do
      expect(context.error).to include("email")
    end
  end
end
```

### Request Specs

```ruby
RSpec.describe "Users API", type: :request do
  describe "POST /api/v1/users" do
    let(:valid_params) { { user: { email: "new@example.com", name: "Jane" } } }

    context "when authenticated" do
      before { sign_in(user) }

      it "creates a user and returns 201" do
        post "/api/v1/users", params: valid_params
        expect(response).to have_http_status(:created)
        expect(json_response["email"]).to eq("new@example.com")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "/api/v1/users", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

### Factory Bot

Use `factory_bot_rails` for test data. Combine with **FFaker** for realistic random values.

**One factory file per model.** Each model gets its own file at `spec/support/factories/<model_plural>.rb`. Never combine multiple factories into a single file.

```ruby
# spec/support/factories/users.rb
FactoryBot.define do
  factory :user do
    email_address { FFaker::Internet.unique.email }
    password { "password123" }
    password_confirmation { "password123" }
    first_name { FFaker::Name.first_name }
    last_name { FFaker::Name.last_name }
    email_verified_at { Time.current }

    # ── Verification traits ─────────────────────────────────
    trait :verified do
      email_verified_at { Time.current }
    end

    trait :unverified do
      email_verified_at { nil }
    end

    # ── Optional attributes ─────────────────────────────────
    trait :with_handle do
      handle { FFaker::Internet.unique.user_name.gsub(/[^a-z0-9_-]/, "")[0..20] }
    end

    # ── OAuth traits ────────────────────────────────────────
    trait :google_oauth do
      google_uid { SecureRandom.hex(10) }
      password { nil }
      password_confirmation { nil }
      email_verified_at { Time.current }
    end

    # ── Role traits ─────────────────────────────────────────
    trait :staff do
      staff { true }
      staff_role { "staff" }
    end

    trait :admin do
      staff { true }
      staff_role { "admin" }
    end

    trait :super_admin do
      staff { true }
      staff_role { "super_admin" }
    end

    # ── Subscription traits ─────────────────────────────────
    trait :with_subscription do
      after(:create) do |user|
        # Create subscription via Pay gem
      end
    end
  end
end
```

**Common trait patterns:**

| Trait | Purpose | Example |
|-------|---------|---------|
| `:verified` / `:unverified` | Email verification state | `create(:user, :unverified)` |
| `:with_*` | Add optional associated data | `create(:user, :with_handle)` |
| `:google_oauth` | OAuth user (no password) | `create(:user, :google_oauth)` |
| `:staff` / `:admin` | Role-based access | `create(:user, :admin)` |
| `:suspended` / `:deleted` | Account states | `create(:user, :suspended)` |

### FFaker over Faker

**Always use `ffaker`, not `faker`.** FFaker is significantly faster and avoids slow test suites as factory count grows.

```ruby
# ✅ CORRECT — FFaker
email { FFaker::Internet.email }
name { FFaker::Name.name }
phone { FFaker::PhoneNumber.phone_number }
address { FFaker::Address.street_address }
company { FFaker::Company.name }

# ❌ WRONG — Faker (slow)
email { Faker::Internet.email }
```

---

## Mocking & Stubbing

### VCR for external HTTP — always

Every test that hits an external API must use **VCR**. VCR records the real response once, then replays it on every subsequent run. This means:
- Tests are fast and deterministic (no network calls)
- Tests work offline and in CI without credentials
- You test against real API responses, not hand-written stubs

**Never manually stub HTTP responses** for services that VCR can record. Manual stubs drift from reality and hide breaking API changes.

### When to use RSpec doubles instead of VCR

Only use `allow`/`expect` doubles for:
- **Internal interfaces** — stubbing one interactor inside another to isolate the unit under test
- **Side effects you want to verify** — `expect(Mailer).to have_received(:send_welcome)`
- **Expensive operations that don't make HTTP calls** — e.g. file system, long computations

### Prefer real objects when possible

Let models, interactors, and database interactions run for real — that's the whole point of the test. Only introduce test doubles when there's a concrete reason (external HTTP, isolation, side-effect verification).

### Use RSpec doubles properly

```ruby
# Stub an internal interface
allow(NotifySlack).to receive(:call).and_return(true)

# Verify a side effect
expect(Mailer).to have_received(:send_welcome).with(user)
```

---

## E2E / System Tests (Capybara + Playwright)

E2E tests run in a real browser with full JavaScript execution. They catch:
- Vite import errors (missing exports, broken imports)
- React rendering errors
- JavaScript runtime errors and console.error calls
- UI interaction bugs

### When to Write E2E Tests

Write E2E tests for:
- Critical user flows (signup, login, checkout)
- Complex multi-step forms
- JavaScript-heavy interactions (modals, dropdowns, date pickers)
- Features that request specs can't adequately test

**Don't** write E2E tests for:
- Simple CRUD operations (use request specs)
- Business logic (use interactor specs)
- API responses (use request specs)

**Test at the lowest possible layer.** If you can verify it in an interactor test, don't write a request test. If you can verify it in a request test, don't write an E2E test.

### Installation

```ruby
# Gemfile
group :test do
  gem "capybara"
  gem "capybara-playwright-driver"
end
```

```bash
bundle install
bun add -d playwright
./node_modules/.bin/playwright install chromium
```

### Capybara + Playwright Configuration

```ruby
# spec/support/capybara.rb
require "capybara/rspec"
require "capybara/playwright"

# ─── Playwright CLI Path ────────────────────────────────────
ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"] ||= File.expand_path(
  "../../node_modules/.bin/playwright", __dir__
)

# ─── Server Configuration ───────────────────────────────────
Capybara.server = :puma, { Silent: true }
Capybara.server_port = 3001
Capybara.app_host = "http://localhost:3001"
Capybara.default_max_wait_time = 10

# ─── Playwright Driver Options ──────────────────────────────
e2e_mode = ENV.fetch("E2E", "headless")
headed = %w[headed debug].include?(e2e_mode)
slow_mo = ENV.fetch("PLAYWRIGHT_SLOW_MO", headed ? 50 : 0).to_i

# ─── Register Playwright Driver ─────────────────────────────
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: !headed,
    slowMo: slow_mo,
  )
end

Capybara.default_driver = :rack_test        # Fast for non-JS tests
Capybara.javascript_driver = :playwright    # Playwright for JS tests

# ─── Console Error Tracking ─────────────────────────────────
module ConsoleErrorTracking
  CONSOLE_ERROR_SCRIPT = <<~JS
    (function() {
      return window.__consoleErrors || [];
    })()
  JS

  INSTALL_ERROR_TRACKING_SCRIPT = <<~JS
    (function() {
      if (!window.__consoleErrorsInstalled) {
        window.__consoleErrors = [];
        window.__consoleErrorsInstalled = true;

        const originalError = console.error;
        console.error = function(...args) {
          window.__consoleErrors.push({
            type: 'console_error',
            message: args.map(a => String(a)).join(' ')
          });
          originalError.apply(console, args);
        };

        window.addEventListener('error', function(e) {
          window.__consoleErrors.push({
            type: 'page_error',
            message: e.message || String(e)
          });
        });

        window.addEventListener('unhandledrejection', function(e) {
          window.__consoleErrors.push({
            type: 'unhandled_rejection',
            message: e.reason ? (e.reason.message || String(e.reason)) : 'Unknown rejection'
          });
        });
      }
    })()
  JS

  class << self
    def get_errors(page)
      return [] unless page.driver.respond_to?(:evaluate_script)
      page.evaluate_script(CONSOLE_ERROR_SCRIPT) || []
    rescue StandardError
      []
    end

    def relevant_errors(errors, ignore_patterns = [])
      errors.reject do |error|
        message = error["message"] || error[:message] || ""
        ignore_patterns.any? { |pattern| message.include?(pattern) }
      end
    end
  end
end

# ─── RSpec Configuration ────────────────────────────────────
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by(:playwright)
  end

  # Install error tracking after each page load
  config.after(:each, type: :system) do |example|
    next if example.metadata[:skip_console_check]

    begin
      page.execute_script(ConsoleErrorTracking::INSTALL_ERROR_TRACKING_SCRIPT)
    rescue StandardError
      # Page might be in error state
    end
  end

  # Check for console errors after each E2E test
  config.after(:each, type: :system) do |example|
    next if example.metadata[:skip_console_check]

    ignore_patterns = Array(example.metadata[:ignore_console_errors])
    ignore_patterns += ["ResizeObserver loop"]  # Common harmless warning

    errors = ConsoleErrorTracking.get_errors(page)
    relevant = ConsoleErrorTracking.relevant_errors(errors, ignore_patterns)

    if relevant.any?
      error_messages = relevant.map { |e| "  [#{e['type']}] #{e['message']}" }.join("\n")
      raise "Browser console errors detected:\n#{error_messages}"
    end
  end

  # Pause on failure in debug mode
  config.after(:each, type: :system) do |example|
    if example.exception && ENV["E2E"] == "debug"
      puts "\n\n🔴 Test failed. Browser paused for debugging."
      puts "   Press Enter to continue..."
      $stdin.gets
    end
  end
end
```

### System Helpers

```ruby
# spec/support/system_helpers.rb
module SystemHelpers
  # Log in a user via the UI
  def login_as(user)
    visit login_path
    find("input[type='email'], input[name*='email']", match: :first).fill_in with: user.email_address
    find("input[type='password']", match: :first).fill_in with: "password123"
    click_button text: /sign in|log in/i
    expect(page).to have_current_path(%r{/app/|/staff/})
  end

  # Log out the current user
  def logout
    visit logout_path
    expect(page).to have_current_path(root_path)
  end

  # Assert page rendered successfully (no error boundary)
  def expect_page_rendered
    expect(page).not_to have_text("Something went wrong")
    expect(page).to have_css("h1")
  end

  # Screenshot for debugging
  def take_screenshot(name = nil)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = name || "screenshot"
    path = Rails.root.join("tmp/screenshots/#{filename}_#{timestamp}.png")
    FileUtils.mkdir_p(File.dirname(path))
    page.save_screenshot(path)
    puts "Screenshot saved: #{path}"
    path
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
```

### Shared Examples for E2E

```ruby
# spec/support/shared_examples/rendered_page.rb
RSpec.shared_examples "a rendered page" do
  it "renders without error" do
    expect(page).not_to have_text("Something went wrong")
    expect(page).to have_css("h1")
  end
end

# spec/support/shared_examples/requires_authentication.rb
RSpec.shared_examples "requires authentication" do |method, path|
  it "redirects unauthenticated users to login" do
    send(method, path)
    expect(response).to redirect_to(login_path)
  end
end
```

### Running E2E Tests

```bash
# Headless (default) — for CI and fast local runs
bundle exec rspec spec/system

# With visible browser — for debugging
E2E=headed bundle exec rspec spec/system

# Debug mode — pauses on failure
E2E=debug bundle exec rspec spec/system

# Slow motion — see each action
PLAYWRIGHT_SLOW_MO=200 E2E=headed bundle exec rspec spec/system

# Single test file
bundle exec rspec spec/system/auth_spec.rb
```

### Console Error Detection Tests

Create a dedicated spec to verify all pages load without JS errors:

```ruby
# spec/system/console_errors_spec.rb
require "rails_helper"

RSpec.describe "Console Error Detection", type: :system do
  describe "Public pages" do
    it "home page loads without JS errors" do
      visit root_path
      expect_page_rendered
    end

    it "login page loads without JS errors" do
      visit login_path
      expect_page_rendered
    end

    it "signup page loads without JS errors" do
      visit signup_path
      expect_page_rendered
    end
  end

  describe "Authenticated pages" do
    let!(:user) { create(:user, :verified) }

    before { login_as(user) }

    it "dashboard loads without JS errors" do
      visit dashboard_path
      expect_page_rendered
    end

    it "settings page loads without JS errors" do
      visit settings_path
      expect_page_rendered
    end
  end
end
```

### Ignoring Expected Errors

```ruby
# Ignore specific console errors
it "handles expected warning", ignore_console_errors: ["Expected warning"] do
  visit some_path
end

# Skip console checking entirely
it "tests error page", :skip_console_check do
  visit "/404"
end
```

### Writing E2E Tests

```ruby
# spec/system/auth_spec.rb
require "rails_helper"

RSpec.describe "Authentication", type: :system do
  describe "Login flow" do
    let!(:user) { create(:user, :verified, email_address: "test@example.com") }

    it "allows user to log in" do
      visit login_path

      fill_in "Email", with: "test@example.com"
      fill_in "Password", with: "password123"
      click_button "Sign in"

      expect(page).to have_current_path(%r{/app/})
      expect(page).to have_content("Dashboard")
    end

    it "shows error for invalid credentials" do
      visit login_path

      fill_in "Email", with: "test@example.com"
      fill_in "Password", with: "wrong"
      click_button "Sign in"

      expect(page).to have_content(/invalid|incorrect/i)
    end
  end
end
```

### E2E Directory Structure

```
spec/system/
├── auth_spec.rb              # Login, signup, logout flows
├── console_errors_spec.rb    # JS error detection across all pages
├── public_pages_spec.rb      # Marketing pages, contact form
├── dashboard_spec.rb         # Main app functionality
├── settings_spec.rb          # Settings page interactions
└── staff/
    └── admin_spec.rb         # Staff admin panel
```

### CI Configuration

```yaml
# .github/workflows/ci.yml
e2e:
  runs-on: ubuntu-latest
  steps:
    - name: Install Playwright
      run: ./node_modules/.bin/playwright install chromium --with-deps

    - name: Run E2E tests
      run: bundle exec rspec spec/system

    - name: Upload screenshots on failure
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: playwright-screenshots
        path: tmp/screenshots/
```
