# Anyway Config — Structured Configuration

> Type-safe configuration management using the `anyway_config` gem.

---

## Overview

Instead of scattering `ENV.fetch("STRIPE_SECRET_KEY")` calls throughout the codebase, use **Anyway Config** to centralize configuration into typed config classes.

**Benefits:**
- Type-safe access to configuration values
- Default values and validation
- Multiple sources: ENV vars, YAML files, Rails credentials
- Easy testing with config stubs
- Self-documenting configuration

---

## Installation

```ruby
# Gemfile
gem "anyway_config"
```

```bash
bundle install
```

---

## Directory Structure

```
app/
└── configs/
    ├── application_config.rb   # App-wide settings (name, host, etc.)
    ├── stripe_config.rb        # Stripe API keys and price IDs
    ├── sentry_config.rb        # Sentry DSN and sample rates
    ├── oauth_config.rb         # Google/GitHub OAuth credentials
    ├── email_config.rb         # SMTP settings
    └── sms_config.rb           # SMS provider settings

config/
├── stripe.yml                  # Per-environment Stripe settings
├── sentry.yml                  # Per-environment Sentry settings
├── oauth.yml                   # Per-environment OAuth settings
└── ...
```

---

## Config Class Pattern

### Basic Structure

```ruby
# app/configs/stripe_config.rb
# frozen_string_literal: true

# Stripe payment configuration
# Loaded from environment variables and config/stripe.yml
#
# @example
#   StripeConfig.public_key           # => "pk_test_..."
#   StripeConfig.secret_key           # => "sk_test_..."
#   StripeConfig.price_id(:pro_monthly) # => "price_..."
#
class StripeConfig < Anyway::Config
  config_name :stripe

  # ENV vars will be prefixed with STRIPE_
  # STRIPE_PUBLIC_KEY, STRIPE_SECRET_KEY, etc.
  env_prefix :stripe

  # Required attributes (no defaults)
  attr_config :public_key,
              :secret_key,
              :webhook_secret

  # Optional attributes with defaults
  attr_config price_pro_monthly: nil,
              price_pro_annual: nil

  # Check if configured
  def configured?
    public_key.present? && secret_key.present?
  end

  # Validate in production
  def validate!
    return unless Rails.env.production?

    raise "Stripe public key not configured" if public_key.blank?
    raise "Stripe secret key not configured" if secret_key.blank?
  end
end
```

### YAML Config File

```yaml
# config/stripe.yml
# Values can be overridden by environment variables prefixed with STRIPE_
#
# ENV mapping:
#   STRIPE_PUBLIC_KEY         -> public_key
#   STRIPE_SECRET_KEY         -> secret_key
#   STRIPE_WEBHOOK_SECRET     -> webhook_secret

default: &default
  # API keys - set via environment variables in production
  # public_key: pk_test_...
  # secret_key: sk_test_...

development:
  <<: *default

test:
  <<: *default
  public_key: pk_test_mock
  secret_key: sk_test_mock
  webhook_secret: whsec_mock

production:
  <<: *default
  # All values MUST be set via environment variables
```

---

## Common Config Classes

### Application Config

```ruby
# app/configs/application_config.rb
class ApplicationConfig < Anyway::Config
  config_name :app
  env_prefix :app

  attr_config name: "MyApp",
              host: "localhost:3000",
              from_email: "noreply@example.com"

  def base_url
    Rails.env.production? ? "https://#{host}" : "http://#{host}"
  end
end
```

### Sentry Config

```ruby
# app/configs/sentry_config.rb
class SentryConfig < Anyway::Config
  config_name :sentry
  env_prefix :sentry

  attr_config dsn: nil,
              traces_sample_rate: 0.1,
              enabled_environments: %w[production]

  def configured?
    dsn.present?
  end

  def enabled?
    configured? && enabled_environments.include?(Rails.env)
  end

  # Safe to expose to frontend
  def frontend_config
    {
      dsn: dsn,
      environment: Rails.env,
      enabled: enabled?,
    }
  end

  def configure_sentry!
    return unless enabled?

    Sentry.init do |config|
      config.dsn = dsn
      config.traces_sample_rate = traces_sample_rate
      config.enabled_environments = enabled_environments
      yield config if block_given?
    end
  end
end
```

### OAuth Config

```ruby
# app/configs/oauth_config.rb
class OAuthConfig < Anyway::Config
  config_name :oauth

  # Use empty prefix to support existing GOOGLE_CLIENT_ID env vars
  env_prefix ""

  attr_config google_client_id: nil,
              google_client_secret: nil

  def google_configured?
    google_client_id.present? && google_client_secret.present?
  end

  def google_credentials
    return nil unless google_configured?

    {
      client_id: google_client_id,
      client_secret: google_client_secret,
    }
  end

  def enabled_providers
    providers = []
    providers << :google if google_configured?
    providers
  end
end
```

### Email Config

```ruby
# app/configs/email_config.rb
class EmailConfig < Anyway::Config
  config_name :email
  env_prefix :brevo

  attr_config smtp_username: nil,
              smtp_password: nil,
              from_address: "noreply@example.com",
              from_name: "MyApp"

  def configured?
    smtp_username.present? && smtp_password.present?
  end

  def smtp_settings
    {
      address: "smtp-relay.brevo.com",
      port: 587,
      user_name: smtp_username,
      password: smtp_password,
      authentication: :plain,
      enable_starttls_auto: true,
    }
  end
end
```

---

## Usage

### In Application Code

```ruby
# Direct access (class methods are auto-generated)
StripeConfig.secret_key
SentryConfig.frontend_config
OAuthConfig.google_configured?

# Instance access (when needed for testing)
config = StripeConfig.new
config.secret_key
```

### In Initializers

```ruby
# config/initializers/stripe.rb
Rails.application.config.after_initialize do
  StripeConfig.validate! if Rails.env.production?

  if StripeConfig.configured?
    Stripe.api_key = StripeConfig.secret_key
  end
end

# config/initializers/sentry.rb
SentryConfig.configure_sentry! do |config|
  config.breadcrumbs_logger = [:active_support_logger]
end
```

### In Controllers

```ruby
class PaymentsController < ApplicationController
  def create
    return head :service_unavailable unless StripeConfig.configured?

    # Use config...
  end
end
```

### In Views/Frontend Props

```ruby
# Pass safe config to frontend
render inertia: "Settings", props: {
  sentry: SentryConfig.frontend_config,
  oauth_providers: OAuthConfig.enabled_providers,
}
```

---

## Environment Variables

With `env_prefix :stripe`, these ENV vars map automatically:

| ENV Variable | Config Attribute |
|--------------|------------------|
| `STRIPE_PUBLIC_KEY` | `StripeConfig.public_key` |
| `STRIPE_SECRET_KEY` | `StripeConfig.secret_key` |
| `STRIPE_WEBHOOK_SECRET` | `StripeConfig.webhook_secret` |
| `STRIPE_PRICE_PRO_MONTHLY` | `StripeConfig.price_pro_monthly` |

**Naming convention:** `{ENV_PREFIX}_{ATTRIBUTE_NAME}` in SCREAMING_SNAKE_CASE.

---

## Testing

### Stubbing Config Values

```ruby
# spec/interactors/create_subscription_spec.rb
RSpec.describe CreateSubscription do
  before do
    allow(StripeConfig).to receive(:secret_key).and_return("sk_test_xxx")
    allow(StripeConfig).to receive(:configured?).and_return(true)
  end

  it "creates a subscription" do
    # ...
  end
end
```

### Test Environment Defaults

Set test defaults in the YAML file:

```yaml
# config/stripe.yml
test:
  public_key: pk_test_mock
  secret_key: sk_test_mock
  webhook_secret: whsec_mock
```

---

## Development Fallbacks

For local development without setting up every service:

```ruby
class StripeConfig < Anyway::Config
  # ...

  DEV_PRICES = {
    pro_monthly: "price_dev_pro_monthly",
    pro_annual: "price_dev_pro_annual",
  }.freeze

  def price_id(plan)
    return DEV_PRICES.fetch(plan) unless Rails.env.production?
    send("price_#{plan}") || raise("Price not configured: #{plan}")
  end
end
```

---

## Migration from Raw ENV

Before (scattered ENV calls):
```ruby
# In controller
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")

# In view
<%= ENV["STRIPE_PUBLIC_KEY"] %>

# In initializer
if ENV["STRIPE_SECRET_KEY"].present?
```

After (centralized config):
```ruby
# In initializer (once)
Stripe.api_key = StripeConfig.secret_key

# In controller
StripeConfig.secret_key

# In view props
StripeConfig.public_key

# Conditional check
if StripeConfig.configured?
```

---

## Checklist

When adding a new external service:

- [ ] Create `app/configs/{service}_config.rb`
- [ ] Create `config/{service}.yml` with environment blocks
- [ ] Add `configured?` method
- [ ] Add `validate!` method for production checks
- [ ] Add initializer to configure the service
- [ ] Document ENV vars in `.env.example`
- [ ] Add test defaults in YAML
