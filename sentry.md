# Sentry Error Tracking

> Setup and configuration for Sentry error tracking in Rails + React apps.

---

## Overview

Use Sentry for production error and exception tracking. Configure both the Ruby backend and the JavaScript frontend to report errors to the same Sentry project.

---

## Backend Setup (Rails)

### Gemfile

```ruby
gem "sentry-ruby"
gem "sentry-rails"
```

### Initializer

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = SentryConfig.dsn
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  config.enabled_environments = SentryConfig.enabled_environments

  # Performance monitoring (adjust sample rate as needed)
  config.traces_sample_rate = SentryConfig.traces_sample_rate

  # Filter sensitive data
  config.before_send = lambda do |event, _hint|
    event.request.data&.delete("password")
    event.request.data&.delete("password_confirmation")
    event.request.data&.delete("token")
    event
  end

  # Set release version
  config.release = ENV.fetch("APP_VERSION", "unknown")
end
```

See [anyway-config.md](anyway-config.md) for the `SentryConfig` class definition.

### User Context

Set the current user on every request so errors are attributable:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_sentry_context

  private

  def set_sentry_context
    return unless Current.user

    Sentry.set_user(
      id: Current.user.id,
      email: Current.user.email_address,
      username: Current.user.handle
    )
  end
end
```

### Manual Error Reporting

```ruby
# Capture an exception with extra context
begin
  risky_operation
rescue StandardError => e
  Sentry.capture_exception(e, extra: { user_id: user.id, action: "risky_operation" })
end

# Capture a message (not an exception)
Sentry.capture_message("Unexpected state: order #{order.id} has no items", level: :warning)
```

### Background Jobs (Solid Queue)

Sentry automatically captures errors from Active Job / Solid Queue. No extra config needed — `sentry-rails` hooks into the job processor.

---

## Logs Module

A thin wrapper around `Rails.logger` that adds **structured tags** and optional **Sentry context** to every log call. Use `Logs` everywhere instead of calling `Rails.logger` directly.

### Why

- **Consistent tagging** — every message is prefixed with a source tag (e.g. `[Payments]`, `[ReferenceData]`), making it trivial to grep production logs.
- **Sentry in one place** — errors and warnings can automatically push context or capture messages/exceptions to Sentry without sprinkling `Sentry.*` calls throughout the codebase.
- **Single interface** — swap the underlying logger, add JSON formatting, or route to a log drain later without touching application code.

### Implementation

```ruby
# app/models/logs.rb
#
# Thin, backend-wide logging façade.
#
#   Logs.info("Payments", "Charge succeeded", charge_id: "ch_123")
#   Logs.error("Mailer", error, user_id: user.id)
#
# Every method accepts:
#   tag     – short string used as a log prefix, e.g. "Payments"
#   message – a String description  **or**  an Exception
#   context – optional keyword args attached as Sentry extra data
#
class Logs
  LEVELS = %i[debug info warn error fatal].freeze

  class << self
    LEVELS.each do |level|
      # Logs.info("Tag", "message", key: "val")
      # Logs.error("Tag", exception, key: "val")
      define_method(level) do |tag, message, **context|
        dispatch(level, tag, message, **context)
      end
    end

    private

    def dispatch(level, tag, message, **context)
      is_exception = message.is_a?(Exception)
      text = is_exception ? "#{message.class}: #{message.message}" : message.to_s

      # ── Rails logger ──
      Rails.logger.tagged(tag) { Rails.logger.public_send(level, text) }

      # ── Sentry (only when available and initialized) ──
      return unless defined?(Sentry) && Sentry.initialized?

      extra = context.merge(_tag: tag)

      if is_exception
        Sentry.capture_exception(message, extra: extra) if capture_level?(level)
      elsif capture_level?(level)
        Sentry.capture_message("[#{tag}] #{text}", level: level, extra: extra)
      else
        Sentry.configure_scope do |scope|
          scope.set_context("logs", extra.merge(message: text))
        end
      end
    end

    # Only push to Sentry for warn / error / fatal
    def capture_level?(level)
      %i[warn error fatal].include?(level)
    end
  end
end
```

### Usage

```ruby
# Simple info — logged and tagged, no Sentry event
Logs.info("Payments", "Charge succeeded", charge_id: charge.id)

# Warning — logged + Sentry message
Logs.warn("ReferenceData", "Skipped — database not ready")

# Error with exception — logged + Sentry.capture_exception
begin
  risky_operation
rescue StandardError => e
  Logs.error("Checkout", e, user_id: user.id, cart_total: cart.total)
end

# Debug — logged only, never hits Sentry
Logs.debug("Cache", "Warm-up complete", keys: 42)
```

### Testing

```ruby
RSpec.describe Logs do
  it "delegates to Rails.logger" do
    expect(Rails.logger).to receive(:info).with("Charge OK")
    Logs.info("Pay", "Charge OK")
  end

  it "captures exceptions to Sentry" do
    error = StandardError.new("boom")
    expect(Sentry).to receive(:capture_exception).with(error, extra: hash_including(_tag: "Pay"))
    Logs.error("Pay", error)
  end

  it "does not send debug/info to Sentry" do
    expect(Sentry).not_to receive(:capture_message)
    expect(Sentry).not_to receive(:capture_exception)
    Logs.info("Tag", "just a message")
  end
end
```

---

## Frontend Setup (React)

### Installation

```bash
bun add @sentry/react
```

### Initialization

```jsx
// app/frontend/lib/sentry.js
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: window.__SENTRY_DSN__,  // Injected from Rails
  environment: window.__RAILS_ENV__ || "development",
  enabled: window.__RAILS_ENV__ === "production",

  // Performance monitoring
  tracesSampleRate: 0.1,

  // Filter out noisy errors
  ignoreErrors: [
    "ResizeObserver loop",
    "Network request failed",
    "Load failed",
  ],
});

export default Sentry;
```

### Inject DSN from Rails

```erb
<!-- app/views/layouts/application.html.erb -->
<script>
  window.__SENTRY_DSN__ = "<%= ENV['SENTRY_DSN'] %>";
  window.__RAILS_ENV__ = "<%= Rails.env %>";
</script>
```

### Error Boundary

```jsx
// app/frontend/components/error-boundary.jsx
import * as Sentry from "@sentry/react";
import { useTranslation } from "react-i18next";

function FallbackComponent() {
  const { t } = useTranslation();

  return (
    <div className="flex items-center justify-center min-h-[400px]">
      <div className="text-center">
        <h2 className="text-xl font-semibold mb-2">{t("errors.something_went_wrong")}</h2>
        <p className="text-muted-foreground">{t("errors.try_refreshing")}</p>
      </div>
    </div>
  );
}

export default Sentry.withErrorBoundary(({ children }) => children, {
  fallback: FallbackComponent,
});
```

### Set User Context (Frontend)

```jsx
// In your Inertia app setup or layout
import * as Sentry from "@sentry/react";
import { usePage } from "@inertiajs/react";
import { useEffect } from "react";

function useSetSentryUser() {
  const { auth } = usePage().props;

  useEffect(() => {
    if (auth?.user) {
      Sentry.setUser({ id: auth.user.id, email: auth.user.email, username: auth.user.handle });
    } else {
      Sentry.setUser(null);
    }
  }, [auth?.user?.id]);
}
```

---

## Environment Variables

```bash
# .env.example
SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
APP_VERSION=1.0.0
```

---

## Testing

Sentry is **disabled in test and development** by default (`enabled_environments`). Tests should never hit Sentry.

If you need to verify that exceptions are captured:

```ruby
RSpec.describe "Sentry integration" do
  it "captures the exception" do
    expect(Sentry).to receive(:capture_exception).with(instance_of(StandardError))

    # trigger the error
  end
end
```

---

## Conventions

1. **Never swallow errors silently.** If you rescue an exception, either handle it meaningfully or report it to Sentry.
2. **Add context.** Use `Sentry.set_extras` or pass `extra:` when capturing — include IDs, state, and any info that helps debug.
3. **Use breadcrumbs.** Sentry auto-collects Rails logs and HTTP requests as breadcrumbs. Add custom ones for important business events.
4. **Filter PII.** Never send passwords, tokens, or full credit card numbers to Sentry.
5. **Set releases.** Tag deploys with `APP_VERSION` so you can track which release introduced a regression.
