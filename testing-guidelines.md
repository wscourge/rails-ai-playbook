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
├── factories/
│   ├── users.rb
│   └── ...
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
end
```

### Support Files

```ruby
# spec/support/factory_bot.rb
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
```

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
    expect(json_response["meta"]).to include("current_page", "total_pages")
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
│   ├── useDebounce.ts
│   ├── __tests__/
│   │   └── useDebounce.test.ts
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

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { FFaker::Internet.email }
    name { FFaker::Name.name }
    password { "password123" }

    trait :admin do
      role { "admin" }
    end

    trait :with_subscription do
      after(:create) do |user|
        # create subscription
      end
    end
  end
end
```

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

### Mock your interfaces, not third-party code

Stub your interactor/service interfaces, not external client libraries. If you mock what you don't own, your tests pass while production breaks.

### Prefer real objects when possible

Only stub external services (notification providers, email delivery, payment processors) and slow dependencies. Let models, interactors, and database interactions run for real — that's the whole point of the test.

### Use RSpec doubles properly

```ruby
# Stub an external service
allow(StripeClient).to receive(:create_customer).and_return(double(id: "cus_123"))

# Verify a side effect
expect(Mailer).to have_received(:send_welcome).with(user)
```

---

## E2E / System Tests

### Playwright over Selenium

Use `capybara-playwright-driver` — same Capybara DSL, but Playwright under the hood. More reliable with modern JS frameworks.

### Keep E2E tests focused

Each system test should cover one complete user flow. Don't chain multiple features into mega-tests — when they fail, you can't tell what broke.

### E2E is for JavaScript-dependent flows

If a behavior can be verified without rendering JS components, test it at the request spec layer. Reserve browser tests for multi-step interactions that require real JS execution.

### E2E covers React

Do not unit-test React components with Jest. E2E (Playwright) tests verify that components render correctly, handle user interactions, and display the right data. This is where you test the full frontend.
