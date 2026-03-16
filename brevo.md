# Brevo — Transactional Email & SMS

> Brevo (formerly Sendinblue) for transactional emails and SMS in production. letter_opener_web for email previews in development.

---

## Overview

| Channel | Development | Production |
|---------|------------|------------|
| **Email** | letter_opener_web (no external service needed) | Brevo SMTP relay |
| **SMS** | Rails logger (console output) | Brevo Transactional SMS API |

Brevo provides both transactional email (via SMTP) and transactional SMS (via REST API) from a single account. No separate providers needed.

---

## Gemfile

```ruby
# Gemfile

# No gem needed for email — uses built-in SMTP delivery method
# SMS uses the Brevo API via HTTP

gem "faraday"  # HTTP client for SMS API (likely already in Gemfile)
```

---

## Environment Variables

```bash
# ─────────────────────────────────────────────────────────────
# Brevo — Transactional Email & SMS (BrevoConfig)
# ─────────────────────────────────────────────────────────────
# Development: email uses letter_opener_web, SMS logs to console (no config needed)

# SMTP credentials (for transactional email)
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX

# API key (for transactional SMS + optional email API)
BREVO_API_KEY=xkeysib-XXXXXXXX

# SMS sender name (max 11 chars, alphanumeric — must be registered with Brevo)
BREVO_SMS_SENDER=MyApp

# Default from address for emails
BREVO_FROM_ADDRESS=noreply@myapp.com
```

---

## Anyway Config

```ruby
# app/configs/brevo_config.rb

class BrevoConfig < ApplicationConfig
  attr_config :smtp_username,
              :smtp_password,
              :api_key,
              :sms_sender,
              :from_address,
              :sms_enabled  # Opt-in for development

  def email_configured?
    Rails.env.development? || (smtp_username.present? && smtp_password.present?)
  end

  def sms_configured?
    api_key.present? && sms_sender.present?
  end

  # Environment-aware: production always on if configured, dev opt-in, test off
  def sms_active?
    return false if Rails.env.test?
    return sms_configured? if Rails.env.production?
    sms_enabled.present? && sms_configured?  # Dev requires explicit opt-in
  end
end
```

In development, set `BREVO_SMS_ENABLED=1` to enable real SMS delivery. Otherwise, SMS sends are logged instead.

---

## Email Configuration

### Development (letter_opener_web)

```ruby
# Gemfile
gem "letter_opener_web", group: :development

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener_web
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

```ruby
# config/routes.rb
if Rails.env.development?
  mount LetterOpenerWeb::Engine, at: "/letter_opener"
end
```

View emails at: http://localhost:3000/letter_opener

### Production (Brevo SMTP)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.default_url_options = { host: ENV["APP_HOST"] }
config.action_mailer.smtp_settings = {
  address: "smtp-relay.brevo.com",
  port: 587,
  user_name: BrevoConfig.smtp_username,
  password: BrevoConfig.smtp_password,
  authentication: :plain,
  enable_starttls_auto: true
}
```

### Application Mailer

```ruby
# app/mailers/application_mailer.rb

class ApplicationMailer < ActionMailer::Base
  default from: -> { BrevoConfig.from_address }
  layout "mailer"
end
```

---

## SMS Configuration

### SMS Client

```ruby
# app/clients/brevo_sms_client.rb

class BrevoSmsClient
  BASE_URL = "https://api.brevo.com/v3"

  class << self
    def send_transactional_sms(to:, content:)
      unless BrevoConfig.sms_active?
        Rails.logger.info("[SMS] Would send to #{to}: #{content}")
        return
      end

      response = connection.post("transactionalSMS/sms") do |req|
        req.body = {
          type: "transactional",
          sender: BrevoConfig.sms_sender,
          recipient: to,
          content: content
        }.to_json
      end

      unless response.success?
        Rails.logger.error("[Brevo SMS] Failed to send to #{to}: #{response.status} #{response.body}")
        raise "Brevo SMS delivery failed: #{response.status}"
      end

      response
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["api-key"] = BrevoConfig.api_key
        f.headers["Content-Type"] = "application/json"
        f.headers["Accept"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

### SMS Job (for async delivery)

```ruby
# app/jobs/send_sms_job.rb

class SendSmsJob < ApplicationJob
  queue_as :default

  def perform(phone_number:, content:)
    BrevoSmsClient.send_transactional_sms(to: phone_number, content: content)
  end
end
```

### Usage

```ruby
# Send SMS immediately
BrevoSmsClient.send_transactional_sms(
  to: "+14155552671",
  content: "Your verification code is 123456"
)

# Send SMS via background job (preferred)
SendSmsJob.perform_later(
  phone_number: "+14155552671",
  content: "Your verification code is 123456"
)
```

---

## Phone Number Format

Brevo requires phone numbers in **E.164 format** (international): `+[country code][number]`

Examples:
- US: `+14155552671`
- UK: `+447911123456`
- FR: `+33612345678`

Store phone numbers in E.164 format in the database. Validate format before sending:

```ruby
# In a validation interactor
PHONE_REGEX = /\A\+[1-9]\d{6,14}\z/

unless context.phone_number.match?(PHONE_REGEX)
  context.fail!(error: I18n.t("errors.invalid_phone_number"))
end
```

---

## Testing

### VCR Cassettes for SMS

```ruby
# spec/clients/brevo_sms_client_spec.rb

RSpec.describe BrevoSmsClient do
  describe ".send_transactional_sms" do
    context "when SMS is not active" do
      before do
        allow(BrevoConfig).to receive(:sms_active?).and_return(false)
      end

      it "logs instead of sending" do
        expect(Rails.logger).to receive(:info).with(/Would send to/)

        BrevoSmsClient.send_transactional_sms(
          to: "+14155552671",
          content: "Test message"
        )
      end
    end

    context "when SMS is active", :vcr do
      it "sends the SMS via Brevo API" do
        response = BrevoSmsClient.send_transactional_sms(
          to: "+14155552671",
          content: "Your code is 123456"
        )

        expect(response.success?).to be true
      end
    end
  end
end
```

### VCR Configuration for Brevo

```ruby
# spec/support/vcr.rb (add to existing VCR config)

VCR.configure do |config|
  config.filter_sensitive_data("<BREVO_API_KEY>") { BrevoConfig.api_key }
  config.filter_sensitive_data("<BREVO_SMTP_PASSWORD>") { BrevoConfig.smtp_password }
end
```

### Stubbing SMS in Feature Specs

```ruby
# spec/support/brevo.rb

RSpec.configure do |config|
  config.before do
    allow(BrevoSmsClient).to receive(:send_transactional_sms)
  end
end
```

---

## Brevo Account Setup

### Email Setup

1. Log into [Brevo](https://app.brevo.com)
2. Go to **Senders, Domains & Dedicated IPs** → **Domains**
3. Add your sending domain
4. Add the DNS records Brevo provides:
   - **DKIM** record (TXT)
   - **Brevo code** record (TXT)
   - **SPF** — add `include:spf.brevo.com` to your existing SPF record (or create one)
   - **DMARC** — add a DMARC record if you don't have one: `v=DMARC1; p=none;`
5. Verify the domain in Brevo dashboard
6. Go to **SMTP & API** → copy SMTP credentials
7. Set `BREVO_SMTP_USERNAME` and `BREVO_SMTP_PASSWORD` in your env

### SMS Setup

1. In Brevo dashboard, go to **Transactional** → **SMS**
2. Register your **sender name** (alphanumeric, max 11 chars — e.g. your app name)
3. Note: sender name approval may take 24-48h depending on country
4. Go to **SMTP & API** → copy your **API key** (v3)
5. Set `BREVO_API_KEY` and `BREVO_SMS_SENDER` in your env

### Country-Specific Notes

- **US/Canada:** SMS sender must be a registered phone number (not alphanumeric sender name). You'll need to register a number through Brevo.
- **EU/UK:** Alphanumeric sender names are supported (e.g. "MyApp")
- **Some countries** require pre-registration of SMS templates. Check [Brevo docs](https://developers.brevo.com/docs/send-a-transactional-sms) for your target countries.

---

## Production Checklist

### Email

- [ ] Add and **verify your sending domain** in Brevo (DNS records: DKIM, SPF, DMARC)
- [ ] Copy **SMTP credentials** from Brevo dashboard
- [ ] Set `BREVO_SMTP_USERNAME` and `BREVO_SMTP_PASSWORD` in `.kamal/secrets`
- [ ] Set `BREVO_FROM_ADDRESS` (e.g. `noreply@yourdomain.com`)
- [ ] Send a test email to confirm delivery
- [ ] Check deliverability — verify emails land in inbox, not spam

### SMS

- [ ] Register **sender name** in Brevo (or phone number for US/Canada)
- [ ] Copy **API key** (v3) from Brevo dashboard
- [ ] Set `BREVO_API_KEY` and `BREVO_SMS_SENDER` in `.kamal/secrets`
- [ ] Send a test SMS to confirm delivery
- [ ] Verify phone number format handling (E.164)

### Secrets

Add to `.kamal/secrets`:
```
BREVO_SMTP_USERNAME=your-smtp-login@smtp-brevo.com
BREVO_SMTP_PASSWORD=xsmtpsib-XXXXXXXX
BREVO_API_KEY=xkeysib-XXXXXXXX
BREVO_SMS_SENDER=MyApp
BREVO_FROM_ADDRESS=noreply@yourdomain.com
```

Add to GitHub repository secrets:
```bash
gh secret set BREVO_SMTP_USERNAME
gh secret set BREVO_SMTP_PASSWORD
gh secret set BREVO_API_KEY
gh secret set BREVO_SMS_SENDER
gh secret set BREVO_FROM_ADDRESS
```
