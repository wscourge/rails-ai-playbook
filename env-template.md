# Environment Variables Template

> All required ENV vars for Rails apps. Copy to `.env` and `.env.example`.

---

## .env.example

```bash
# ─────────────────────────────────────────────────────────────
# App Configuration
# ─────────────────────────────────────────────────────────────
APP_NAME="My App"
APP_HOST="localhost:3000"
APP_URL="http://localhost:3000"

# ─────────────────────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────────────────────
# Development uses database.yml defaults
# Production: set these in .kamal/secrets
# DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_production
# QUEUE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_queue_production
# CACHE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_cache_production
# CABLE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_cable_production

# ─────────────────────────────────────────────────────────────
# Rails
# ─────────────────────────────────────────────────────────────
RAILS_ENV=development
# RAILS_MASTER_KEY=  # Only needed in production
RAILS_MAX_THREADS=5
# RAILS_SERVE_STATIC_FILES=true  # Production only

# ─────────────────────────────────────────────────────────────
# Stripe
# ─────────────────────────────────────────────────────────────
STRIPE_PUBLIC_KEY=pk_test_XXX
STRIPE_SECRET_KEY=sk_test_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX

# Production price IDs (create via Stripe CLI)
# STRIPE_PRICE_PRO=price_XXX
# STRIPE_PRICE_MAX=price_XXX
# STRIPE_PRICE_LIFETIME=price_XXX  # One-time (if used)

# ─────────────────────────────────────────────────────────────
# Brevo — Transactional Email & SMS
# ─────────────────────────────────────────────────────────────
# Development: email uses letter_opener_web, SMS logs to console (no config needed)
# Production: Brevo SMTP (email) + Brevo API (SMS)
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX
BREVO_API_KEY=xkeysib-XXXXXXXX
BREVO_SMS_SENDER=MyApp
BREVO_FROM_ADDRESS=noreply@myapp.com

# ─────────────────────────────────────────────────────────────
# OAuth (Optional)
# ─────────────────────────────────────────────────────────────
GOOGLE_OAUTH_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-XXX

# ─────────────────────────────────────────────────────────────
# Analytics (Optional)
# ─────────────────────────────────────────────────────────────
ANALYTICS_GA_MEASUREMENT_ID=G-XXX
ANALYTICS_AHREFS_VERIFICATION=ahrefs-site-verification_xxxxxxxxxxxx

# ─────────────────────────────────────────────────────────────
# Error Tracking (Sentry)
# ─────────────────────────────────────────────────────────────
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
APP_VERSION=1.0.0

# ─────────────────────────────────────────────────────────────
# VCR Cassette Re-recording
# ─────────────────────────────────────────────────────────────
# These are ONLY needed when re-recording VCR cassettes (not for
# normal test runs). The cassette files committed to git already
# contain recorded responses with secrets filtered out.
# Uncomment the services you need to re-record:
#
# Stripe:     STRIPE_SECRET_KEY and STRIPE_PUBLIC_KEY (above) — use test mode
# Google:     GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET (above)
# Brevo:      BREVO_API_KEY (above)
# Sentry:     SENTRY_DSN (above)
# OpenAI:     OPENAI_API_KEY (below)
# Anthropic:  ANTHROPIC_API_KEY (below)
#
# After re-recording, verify no real secrets leaked into cassettes:
#   grep -rn "sk_test_\|sk-ant-\|xkeysib-\|xsmtpsib-\|whsec_" spec/support/cassettes/

# ─────────────────────────────────────────────────────────────
# Telegram (Optional — staff notifications)
# ─────────────────────────────────────────────────────────────
# TELEGRAM_API_KEY=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11

# ─────────────────────────────────────────────────────────────
# External APIs (Add as needed)
# ─────────────────────────────────────────────────────────────
# OPENAI_API_KEY=sk-XXX
# ANTHROPIC_API_KEY=sk-ant-XXX

# ─────────────────────────────────────────────────────────────
# Mobile App (Capacitor — if shipping to stores)
# ─────────────────────────────────────────────────────────────
# iPhone & iPad (App Store)
# APP_STORE_URL=https://apps.apple.com/app/id123456789
# APP_STORE_ID=123456789
# Android (Play Store)
# ANDROID_PACKAGE=com.example.myapp
# ANDROID_APP_NAME=MyApp
# ANDROID_APP_URL=https://play.google.com/store/apps/details?id=com.example.myapp
```

---

## Usage in Rails

Always use `ENV["KEY"]` or `ENV.fetch("KEY")`:

```ruby
# Simple access (returns nil if missing)
api_key = ENV["STRIPE_SECRET_KEY"]

# With default value
app_name = ENV.fetch("APP_NAME", "My App")

# Required (raises if missing)
secret = StripeConfig.secret_key

# Boolean check
if GoogleOAuthConfig.client_id.present?
  # Google OAuth enabled
end
```

---

## Setting Up

### Development

1. Copy template to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in development values

3. Add `dotenv-rails` gem:
   ```ruby
   # Gemfile
   gem 'dotenv-rails', groups: [:development, :test]
   ```

4. Add `.env` to `.gitignore`:
   ```
   # .gitignore
   .env
   .env.local
   ```

### Production (Kamal)

Production secrets are stored in `.kamal/secrets` (never committed):

```bash
# Edit secrets
vim .kamal/secrets

# Push env changes to servers without redeploying
kamal env push

# Clear env vars (redeploy needed)
kamal env clear
```

Clear (non-secret) env vars go in `config/deploy.yml` under `env.clear`.

### Production (GitHub Actions)

When using GitHub Actions for automated deployment, mirror all `.kamal/secrets` values as GitHub repository secrets:

```bash
# Add/update a secret
gh secret set SECRET_NAME

# List all secrets
gh secret list

# Delete a secret
gh secret delete SECRET_NAME
```

See [kamal-deploy.md](kamal-deploy.md#automated-deployment-github-actions) for the full CI/CD setup.

---

## Security Rules

1. **Never commit `.env` files** - add to `.gitignore`
2. **Always commit `.env.example`** - documents required vars
3. **Use different keys per environment** - dev/staging/prod
4. **Rotate secrets periodically** - especially after team changes
5. **Don't log ENV values** - mask in error reporters

---

## Configuration Layer

Never access `ENV` directly in application code. Use **Anyway Config** (backend) and **Zod schemas** (frontend) as abstraction layers.

### Backend: Anyway Config

Add the gem:

```ruby
# Gemfile
gem "anyway_config"
```

#### Directory Structure

```
app/
└── configs/
    ├── application_config.rb    # Base class
    ├── app_config.rb            # APP_NAME, APP_URL, etc.
    ├── stripe_config.rb         # Stripe keys and settings
    ├── google_oauth_config.rb   # Google OAuth credentials
    ├── email_config.rb          # Brevo, SMTP settings
    ├── brevo_config.rb           # Brevo email + SMS
    ├── sentry_config.rb         # Error tracking
    ├── analytics_config.rb      # GA, Ahrefs
    └── llm_config.rb            # OpenAI, Anthropic
```

#### Base Config Class

```ruby
# app/configs/application_config.rb
#
# Base class for all config classes. Provides common behavior.

class ApplicationConfig < Anyway::Config
  class << self
    # Shorthand accessor: AppConfig.app_name instead of AppConfig.new.app_name
    def method_missing(name, ...)
      return super unless instance_methods.include?(name)
      instance.public_send(name, ...)
    end

    def respond_to_missing?(name, include_private = false)
      instance_methods.include?(name) || super
    end

    def instance
      @instance ||= new
    end
  end
end
```

#### Config Classes

```ruby
# app/configs/app_config.rb

class AppConfig < ApplicationConfig
  attr_config :name,
              :host,
              :url

  required :name, :url

  def frontend_config
    {
      name: name,
      url: url
    }
  end
end
```

```ruby
# app/configs/stripe_config.rb

class StripeConfig < ApplicationConfig
  attr_config :public_key,
              :secret_key,
              :webhook_secret,
              price_ids: {}   # { pro: "price_xxx", lifetime: "price_yyy" }

  required :public_key, :secret_key

  # Only required in production
  on_load do
    if Rails.env.production? && webhook_secret.blank?
      raise_validation_error("webhook_secret is required in production")
    end
  end

  def configured?
    public_key.present? && secret_key.present?
  end

  def frontend_config
    {
      publicKey: public_key
    }
  end
end
```

```ruby
# app/configs/google_oauth_config.rb

class GoogleOAuthConfig < ApplicationConfig
  attr_config :client_id,
              :client_secret

  def enabled?
    client_id.present? && client_secret.present?
  end

  def frontend_config
    {
      enabled: enabled?
    }
  end
end
```

```ruby
# app/configs/brevo_config.rb

class BrevoConfig < ApplicationConfig
  attr_config :smtp_username,
              :smtp_password,
              :api_key,
              :sms_sender,
              :from_address

  def email_configured?
    Rails.env.development? || (smtp_username.present? && smtp_password.present?)
  end

  def sms_configured?
    api_key.present? && sms_sender.present?
  end
end
```

```ruby
# app/configs/sentry_config.rb

class SentryConfig < ApplicationConfig
  attr_config :dsn,
              :app_version

  def enabled?
    dsn.present?
  end

  def frontend_config
    {
      dsn: dsn,
      enabled: enabled?
    }
  end
end
```

```ruby
# app/configs/analytics_config.rb

class AnalyticsConfig < ApplicationConfig
  attr_config :ga_measurement_id,
              :ahrefs_verification

  def ga_enabled?
    ga_measurement_id.present?
  end

  def frontend_config
    {
      gaMeasurementId: ga_measurement_id
    }
  end
end
```

```ruby
# app/configs/llm_config.rb

class LlmConfig < ApplicationConfig
  attr_config :openai_api_key,
              :anthropic_api_key,
              default_provider: "openai"

  def openai_enabled?
    openai_api_key.present?
  end

  def anthropic_enabled?
    anthropic_api_key.present?
  end
end
```

#### ENV Mapping

Anyway Config automatically maps `SCREAMING_SNAKE_CASE` env vars to config attributes. The prefix is the config class name:

| Config class | ENV prefix | Example |
|--------------|------------|---------|
| `AppConfig` | `APP_` | `APP_NAME`, `APP_URL` |
| `StripeConfig` | `STRIPE_` | `STRIPE_PUBLIC_KEY`, `STRIPE_SECRET_KEY` |
| `GoogleOAuthConfig` | `GOOGLE_OAUTH_` | `GOOGLE_OAUTH_CLIENT_ID` |
| `BrevoConfig` | `BREVO_` | `BREVO_SMTP_USERNAME`, `BREVO_API_KEY` |
| `SentryConfig` | `SENTRY_` | `SENTRY_DSN` |
| `AnalyticsConfig` | `ANALYTICS_` | `ANALYTICS_GA_MEASUREMENT_ID` |
| `LlmConfig` | `LLM_` | `LLM_OPENAI_API_KEY` |

You can also use YAML files for non-secret defaults:

```yaml
# config/configs/app.yml
name: "My App"
url: "http://localhost:3000"

production:
  url: "https://myapp.com"
```

#### Usage in Code

```ruby
# ❌ WRONG — direct ENV access
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")

# ✅ CORRECT — via config class
Stripe.api_key = StripeConfig.secret_key

# Check if a feature is enabled
if GoogleOAuthConfig.enabled?
  # Set up OmniAuth
end

# Access nested config
price_id = StripeConfig.price_ids[:pro]
```

### Frontend: Zod Schema

Share config to the frontend via `inertia_share`, then validate with Zod.

#### Share Config from Rails

```ruby
# app/controllers/application_controller.rb

class ApplicationController < ActionController::Base
  include InertiaRails::Controller

  inertia_share config: -> { frontend_config }

  private

  def frontend_config
    {
      app: AppConfig.frontend_config,
      stripe: StripeConfig.frontend_config,
      googleOAuth: GoogleOAuthConfig.frontend_config,
      sentry: SentryConfig.frontend_config,
      analytics: AnalyticsConfig.frontend_config
    }
  end
end
```

#### Zod Schema for Config

```javascript
// app/frontend/lib/config.js
import { z } from "zod";

// Schema definition — validates config structure from server
const ConfigSchema = z.object({
  app: z.object({
    name: z.string(),
    url: z.string().url(),
  }),
  stripe: z.object({
    publicKey: z.string().startsWith("pk_"),
  }),
  googleOAuth: z.object({
    enabled: z.boolean(),
  }),
  sentry: z.object({
    dsn: z.string().nullable(),
    enabled: z.boolean(),
  }),
  analytics: z.object({
    gaMeasurementId: z.string().nullable(),
  }),
});

// Parse and validate — throws if invalid
let _config = null;

export function initConfig(rawConfig) {
  _config = ConfigSchema.parse(rawConfig);
  return _config;
}

// Accessor — throws if not initialized
export function getConfig() {
  if (!_config) {
    throw new Error("Config not initialized. Call initConfig() first.");
  }
  return _config;
}

// Convenience accessors
export const config = {
  get app() { return getConfig().app; },
  get stripe() { return getConfig().stripe; },
  get googleOAuth() { return getConfig().googleOAuth; },
  get sentry() { return getConfig().sentry; },
  get analytics() { return getConfig().analytics; },
};
```

#### Initialize on App Mount

```javascript
// app/frontend/entrypoints/inertia.jsx
import { createInertiaApp } from "@inertiajs/react";
import { initConfig } from "@/lib/config";

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob("../pages/**/*.jsx", { eager: true });
    return pages[`../pages/${name}.jsx`];
  },
  setup({ el, App, props }) {
    // Initialize config from server-provided props
    initConfig(props.initialPage.props.config);

    createRoot(el).render(<App {...props} />);
  },
});
```

#### Usage in Components

```javascript
// app/frontend/components/stripe-checkout.jsx
import { config } from "@/lib/config";
import { loadStripe } from "@stripe/stripe-js";

export function StripeCheckout() {
  const stripePromise = loadStripe(config.stripe.publicKey);
  // ...
}

// app/frontend/components/google-sign-in.jsx
import { config } from "@/lib/config";

export function GoogleSignIn() {
  if (!config.googleOAuth.enabled) {
    return null;
  }
  // ...
}

// app/frontend/components/analytics.jsx
import { config } from "@/lib/config";

export function Analytics() {
  const { gaMeasurementId } = config.analytics;
  if (!gaMeasurementId) return null;
  // Initialize GA4...
}
```

### Rules

- **Never access `ENV` in application code.** Always go through a config class.
- **One config class per domain.** Don't lump everything into one giant config.
- **Secrets stay on the backend.** Only share public keys and feature flags to frontend.
- **Validate early.** Anyway Config validates on boot; Zod validates on app mount.
- **Use `frontend_config` methods.** Each config class exposes only what the frontend needs.
- **Match the schema to the server.** If Rails adds a new config field, update the Zod schema.

---

## .env Variable Reference

Updated `.env.example` using the new config prefixes:

```bash
# ─────────────────────────────────────────────────────────────
# App Configuration
# ─────────────────────────────────────────────────────────────
APP_NAME="My App"
APP_HOST="localhost:3000"
APP_URL="http://localhost:3000"

# ─────────────────────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────────────────────
# Development uses database.yml defaults
# Production: set these in .kamal/secrets
# DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_production
# QUEUE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_queue_production
# CACHE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_cache_production
# CABLE_DATABASE_URL=postgres://user:pass@<db-private-ip>:5432/myapp_cable_production

# ─────────────────────────────────────────────────────────────
# Rails
# ─────────────────────────────────────────────────────────────
RAILS_ENV=development
# RAILS_MASTER_KEY=  # Only needed in production
RAILS_MAX_THREADS=5

# ─────────────────────────────────────────────────────────────
# Stripe (StripeConfig)
# ─────────────────────────────────────────────────────────────
STRIPE_PUBLIC_KEY=pk_test_XXX
STRIPE_SECRET_KEY=sk_test_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX
# Nested config via JSON or separate vars:
# STRIPE_PRICE_IDS='{"pro":"price_XXX","lifetime":"price_YYY"}'

# ─────────────────────────────────────────────────────────────
# Brevo — Email & SMS (BrevoConfig)
# ─────────────────────────────────────────────────────────────
# Development: email uses letter_opener_web, SMS logs to console (no config needed)
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX
BREVO_API_KEY=xkeysib-XXXXXXXX
BREVO_SMS_SENDER=MyApp
BREVO_FROM_ADDRESS=noreply@myapp.com

# ─────────────────────────────────────────────────────────────
# Google OAuth (GoogleOAuthConfig)
# ─────────────────────────────────────────────────────────────
GOOGLE_OAUTH_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=GOCSPX-XXX

# ─────────────────────────────────────────────────────────────
# Analytics (AnalyticsConfig)
# ─────────────────────────────────────────────────────────────
ANALYTICS_GA_MEASUREMENT_ID=G-XXX
ANALYTICS_AHREFS_VERIFICATION=ahrefs-site-verification_XXX

# ─────────────────────────────────────────────────────────────
# Error Tracking (SentryConfig)
# ─────────────────────────────────────────────────────────────
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
SENTRY_APP_VERSION=1.0.0

# ─────────────────────────────────────────────────────────────
# LLM APIs (LlmConfig)
# ─────────────────────────────────────────────────────────────
# LLM_OPENAI_API_KEY=sk-XXX
# LLM_ANTHROPIC_API_KEY=sk-ant-XXX
# LLM_DEFAULT_PROVIDER=openai

# ─────────────────────────────────────────────────────────────
# VCR Cassette Re-recording
# ─────────────────────────────────────────────────────────────
# These are ONLY needed when re-recording VCR cassettes (not for
# normal test runs). See testing-guidelines.md for details.
```
