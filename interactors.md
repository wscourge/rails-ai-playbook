# Interactors

> Business logic patterns using the [Interactor](https://github.com/collectiveidea/interactor) gem. Replaces service objects.

---

## Why Interactors

- **One interactor, one job.** Each interactor does exactly one small thing: validate params, create a record, send an email, charge a card.
- **Composable.** Use `Interactor::Organizer` to chain small steps into a workflow. Each step can fail independently.
- **Rollback built-in.** If step 3 fails, steps 1 and 2 roll back automatically (if you define `rollback`).
- **Consistent interface.** Every interactor returns a context with `.success?` / `.failure?`. Controllers never need to know the internals.

---

## Setup

### Gemfile

```ruby
gem "interactor", "~> 3.0"
gem "interactor-rails", "~> 2.0"
```

### Directory Structure

```
app/interactors/
├── users/
│   ├── validate_signup_params.rb
│   ├── create_user.rb
│   ├── send_welcome_email.rb
│   └── signup.rb              # Organizer
├── billing/
│   ├── validate_subscription_params.rb
│   ├── create_stripe_customer.rb
│   ├── create_subscription.rb
│   └── subscribe.rb           # Organizer
└── teams/
    ├── validate_invite_params.rb
    ├── create_invitation.rb
    ├── send_invite_email.rb
    └── invite_member.rb       # Organizer
```

---

## Conventions

### Naming

- **Single interactors:** verb + noun → `CreateUser`, `SendWelcomeEmail`, `ValidateSignupParams`
- **Organizers:** short action name → `Signup`, `Subscribe`, `InviteMember`
- **Validation interactors:** always prefixed with `Validate` → `ValidateSignupParams`

### Class Structure

```ruby
class Users::CreateUser
  include Interactor

  delegate :email, :name, :password, to: :context

  def call
    user = User.new(email:, name:, password:)

    unless user.save
      context.fail!(error: user.errors.full_messages.join(", "))
    end

    context.user = user
  end

  def rollback
    context.user&.destroy
  end
end
```

### Rules

1. **Always use `context.fail!`** to signal failure — never raise exceptions for expected business errors.
2. **Set output on context** — `context.user = user`, not return values.
3. **Use `delegate`** to pull values from context cleanly.
4. **Keep it tiny.** If an interactor is over 30 lines, it probably does too much. Split it.
5. **No database transactions inside individual interactors** — let the organizer handle wrapping in a transaction if needed.

---

## Validation Interactors

**All request param validation happens in interactors, not in Rails models.** Models only enforce DB-level constraints (NOT NULL, unique indexes, foreign keys). Business validation — required fields, format checks, authorization — lives in a `Validate*` interactor.

```ruby
class Users::ValidateSignupParams
  include Interactor

  delegate :email, :name, :password, to: :context

  def call
    errors = []

    errors << I18n.t("errors.email_required") if email.blank?
    errors << I18n.t("errors.email_invalid") unless email&.match?(URI::MailTo::EMAIL_REGEXP)
    errors << I18n.t("errors.name_required") if name.blank?
    errors << I18n.t("errors.password_too_short") if password.blank? || password.length < 8

    if User.exists?(email:)
      errors << I18n.t("errors.email_taken")
    end

    context.fail!(errors:) if errors.any?
  end
end
```

### Why Not Model Validations?

- **Models are for data shape** (column types, NOT NULL, unique constraints at DB level).
- **Interactors are for business rules** (is this email taken? is the user allowed to do this? are all required fields present?).
- This keeps models thin, makes validation testable in isolation, and avoids the Rails pattern where models accumulate dozens of conditional validations.

---

## Organizers

Compose multiple interactors into a workflow:

```ruby
class Users::Signup
  include Interactor::Organizer

  organize Users::ValidateSignupParams,
           Users::CreateUser,
           Users::SendWelcomeEmail
end
```

### With Transaction Wrapping

For multi-write organizers, wrap in a transaction:

```ruby
class Billing::Subscribe
  include Interactor::Organizer

  around do |interactor|
    ActiveRecord::Base.transaction do
      interactor.call
    rescue Interactor::Failure
      raise ActiveRecord::Rollback
    end
  end

  organize Billing::ValidateSubscriptionParams,
           Billing::CreateStripeCustomer,
           Billing::CreateSubscription
end
```

---

## Controller Integration

Controllers call organizers (or single interactors) and handle the result:

```ruby
class Api::V1::UsersController < ApplicationController
  allow_unauthenticated_access only: [:create]

  def create
    result = Users::Signup.call(
      email: params.dig(:user, :email),
      name: params.dig(:user, :name),
      password: params.dig(:user, :password)
    )

    if result.success?
      render json: { user: serialize(result.user) }, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  private

  def serialize(user)
    { id: user.id, email: user.email, name: user.name }
  end
end
```

### Inertia Controllers

```ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def create
    result = Users::Signup.call(
      email: params.dig(:user, :email),
      name: params.dig(:user, :name),
      password: params.dig(:user, :password)
    )

    if result.success?
      start_new_session_for(result.user)
      redirect_to root_path, notice: I18n.t("auth.signup_success")
    else
      redirect_back fallback_location: sign_up_path,
                     inertia: { errors: result.errors },
                     alert: result.errors.first
    end
  end
end
```

---

## Testing Interactors

```ruby
RSpec.describe Users::ValidateSignupParams, type: :interactor do
  subject(:context) { described_class.call(params) }

  describe "with valid params" do
    let(:params) { { email: "user@example.com", name: "Jane", password: "password123" } }

    it { is_expected.to be_a_success }
  end

  describe "with missing email" do
    let(:params) { { email: "", name: "Jane", password: "password123" } }

    it { is_expected.to be_a_failure }

    it "returns email error" do
      expect(context.errors).to include(I18n.t("errors.email_required"))
    end
  end
end

RSpec.describe Users::Signup, type: :interactor do
  subject(:context) { described_class.call(params) }

  let(:params) { { email: "user@example.com", name: "Jane", password: "password123" } }

  it "creates a user" do
    expect { context }.to change(User, :count).by(1)
  end

  it "sends a welcome email" do
    expect { context }.to have_enqueued_mail(UserMailer, :welcome)
  end

  context "with invalid email" do
    let(:params) { { email: "", name: "Jane", password: "password123" } }

    it "fails without creating a user" do
      expect { context }.not_to change(User, :count)
      expect(context).to be_a_failure
    end
  end
end
```

---

## Common Patterns

### Passing Context Between Steps

Each step adds to the context. Subsequent steps can read what previous steps set:

```ruby
# Step 1: ValidateParams sets nothing (just validates)
# Step 2: CreateUser sets context.user
# Step 3: SendWelcomeEmail reads context.user

class Users::SendWelcomeEmail
  include Interactor

  delegate :user, to: :context

  def call
    UserMailer.welcome(user).deliver_later
  end
end
```

### Authorization in Interactors

```ruby
class Teams::ValidateInviteParams
  include Interactor

  delegate :current_user, :team, :email, to: :context

  def call
    unless team.owner?(current_user)
      context.fail!(error: I18n.t("errors.not_authorized"))
    end

    context.fail!(error: I18n.t("errors.email_required")) if email.blank?
    context.fail!(error: I18n.t("errors.already_member")) if team.member?(email)
  end
end
```

### Conditional Steps

```ruby
class Orders::Process
  include Interactor::Organizer

  organize Orders::ValidateParams,
           Orders::CreateOrder,
           Orders::ChargePayment,
           Orders::SendConfirmation

  # Skip email if user opted out
  around do |interactor|
    interactor.call
    # Conditional logic after all steps
  end
end
```
