# Stripe Payments

> Stripe CLI workflow, Pay gem setup, and webhook handling for subscriptions, one-time payments, and metered billing.

---

## Non-Negotiables

1. **Use Stripe CLI** for creating products, prices, and testing webhooks - never the dashboard
2. **Use Pay gem** for Rails integration - don't build custom Stripe logic
3. **Use PlansService** for centralized plan configuration
4. **Environment-specific price IDs** - different IDs for dev/test/prod
5. **Always use `ENV["X"]`** for Stripe keys - never hardcode

---

## Pricing Models

Determine the pricing model during the [interview](PLAYBOOK.md#step-1-interview-me). The setup varies significantly:

| Model | Stripe Mode | Use When |
|-------|-------------|----------|
| **Subscription** | `mode: "subscription"` | Recurring access (monthly/annual plans) |
| **One-time** | `mode: "payment"` | Lifetime access, digital products, credits |
| **Metered** | `mode: "subscription"` + usage records | Pay per API call, token, message, etc. |
| **Hybrid** | Mix of above | Subscription base + usage overage |

### Subscription

Recurring billing on a fixed interval. Most common for SaaS.

- User subscribes to a plan (Free / Pro / Max)
- Billed monthly or annually
- Can upgrade/downgrade via Stripe Billing Portal
- Access gated by active subscription status

### One-Time Payment

Single charge, permanent access or consumable credits.

- Lifetime plans, course purchases, credit packs
- No recurring billing — user pays once
- Access gated by checking for a successful payment record
- Credits/tokens tracked in your own DB (not Stripe)

### Metered / Usage-Based

User subscribes but is billed based on actual usage.

- Base subscription (can be $0) + usage charges
- Report usage to Stripe via `Stripe::SubscriptionItem.create_usage_record`
- Billed at end of billing period based on usage
- Requires tracking usage in your own DB and syncing to Stripe

---

## Initial Setup

### 1. Install Stripe CLI

```bash
# macOS
brew install stripe/stripe-cli/stripe

# Login
stripe login
```

### 2. Add Gems

```ruby
# Gemfile
gem 'pay'
gem 'stripe'
```

### 3. Install Pay

```bash
bundle install
bin/rails pay:install:migrations
bin/rails db:migrate
```

### 4. Add to User Model

```ruby
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe
  # ... rest of model
end
```

---

## Creating Products & Prices (Stripe CLI)

**Always use CLI, not dashboard:**

### Create a Product

```bash
stripe products create \
  --name="Pro Plan" \
  --description="Full access to all features"
```

### Create a Price

```bash
# Monthly subscription
stripe prices create \
  --product="prod_XXX" \
  --unit-amount=2000 \
  --currency=usd \
  --recurring[interval]=month \
  --lookup-key="pro_monthly"

# Annual subscription
stripe prices create \
  --product="prod_XXX" \
  --unit-amount=20000 \
  --currency=usd \
  --recurring[interval]=year \
  --lookup-key="pro_annual"

# One-time price
stripe prices create \
  --product="prod_XXX" \
  --unit-amount=9900 \
  --currency=usd \
  --lookup-key="lifetime"

# Metered price (per unit, billed at end of period)
stripe prices create \
  --product="prod_XXX" \
  --currency=usd \
  --recurring[interval]=month \
  --recurring[usage-type]=metered \
  --unit-amount=10 \
  --lookup-key="api_calls"
```

### List Products/Prices

```bash
stripe products list
stripe prices list
```

---

## PlansService Pattern

Centralized plan configuration - single source of truth:

```ruby
# app/services/plans_service.rb

class PlansService
  # Environment-specific price IDs
  PRICE_IDS = {
    test: {
      pro: "price_test_pro",
      max: "price_test_max",
      lifetime: "price_test_lifetime"
    },
    development: {
      pro: "price_dev_pro",
      max: "price_dev_max",
      lifetime: "price_dev_lifetime"
    },
    production: {
      pro: ENV["STRIPE_PRICE_PRO"],
      max: ENV["STRIPE_PRICE_MAX"],
      lifetime: ENV["STRIPE_PRICE_LIFETIME"]
    }
  }.freeze

  class << self
    def current_price_ids
      env = Rails.env.to_sym
      PRICE_IDS[env] || PRICE_IDS[:development]
    end

    def plan_config
      price_ids = current_price_ids

      {
        "free" => {
          name: "Free",
          price: 0,
          stripe_price_id: nil,
          mode: nil,               # No checkout for free
          popular: false,
          features: [
            "Basic features",
            "Email support"
          ]
        },
        price_ids[:pro] => {
          name: "Pro",
          price: 20,
          stripe_price_id: price_ids[:pro],
          mode: "subscription",    # Recurring
          popular: true,
          features: [
            "All free features",
            "Advanced features",
            "Priority support"
          ]
        },
        price_ids[:max] => {
          name: "Max",
          price: 50,
          stripe_price_id: price_ids[:max],
          mode: "subscription",    # Recurring
          popular: false,
          features: [
            "All Pro features",
            "Premium features",
            "Dedicated support"
          ]
        },
        price_ids[:lifetime] => {
          name: "Lifetime",
          price: 299,
          stripe_price_id: price_ids[:lifetime],
          mode: "payment",         # One-time
          popular: false,
          features: [
            "All Pro features forever",
            "No recurring billing"
          ]
        }
      }
    end

    def all_plans
      plan_config.map { |id, config| { id: id, **config } }
    end

    def paid_plans
      all_plans.reject { |plan| plan[:id] == "free" }
    end

    def subscription_plans
      paid_plans.select { |plan| plan[:mode] == "subscription" }
    end

    def one_time_plans
      paid_plans.select { |plan| plan[:mode] == "payment" }
    end

    def find_plan(id)
      config = plan_config[id.to_s]
      return nil unless config
      { id: id, **config }
    end

    def plan_name(plan_id)
      find_plan(plan_id)&.dig(:name) || "Free"
    end

    def for_frontend
      all_plans.map do |plan|
        {
          id: plan[:id],
          name: plan[:name],
          price: plan[:price],
          mode: plan[:mode],
          popular: plan[:popular],
          features: plan[:features]
        }
      end
    end
  end
end
```

> **Adapt to your pricing model:** Remove the plan types you don't need. If you're subscription-only, drop the lifetime entry. If you're one-time-only, drop the recurring plans. The `mode` field drives checkout behavior.

---

## Billing Controller

```ruby
# app/controllers/billing_controller.rb

class BillingController < ApplicationController
  allow_unauthenticated_access only: :pricing

  def pricing
    render inertia: 'Pricing', props: {
      plans: PlansService.for_frontend
    }
  end

  def subscribe
    price_id = params[:price_id]
    plan = PlansService.find_plan(price_id)

    return redirect_to pricing_path, alert: I18n.t("billing.invalid_plan") unless plan

    checkout_params = {
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: root_url,
      cancel_url: pricing_url
    }

    # Determine checkout mode from plan config
    checkout_params[:mode] = plan[:mode] || "subscription"

    checkout = Current.user.payment_processor.checkout(**checkout_params)
    redirect_to checkout.url, allow_other_host: true
  end

  def portal
    portal_session = Current.user.payment_processor.billing_portal(
      return_url: settings_url
    )
    redirect_to portal_session.url, allow_other_host: true
  end
end
```

---

## Webhook Handling

### Routes

```ruby
# config/routes.rb
post '/webhooks/stripe', to: 'webhooks#stripe'
```

### Controller

```ruby
# app/controllers/webhooks_controller.rb

class WebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    event = Stripe::Webhook.construct_event(
      payload,
      sig_header,
      ENV['STRIPE_WEBHOOK_SECRET']
    )

    Pay::Webhooks::Stripe.new.call(event)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end
end
```

### Pay Initializer with Custom Handlers

```ruby
# config/initializers/pay.rb

Pay.setup do |config|
  config.emails.receipt = true
  config.emails.payment_failed = true
end

# Custom webhook handlers
ActiveSupport.on_load(:pay) do
  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.created" do |event|
    # Handle subscription created
    Rails.logger.info "Subscription created: #{event.data.object.id}"
  end

  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.deleted" do |event|
    # Handle subscription cancelled
    Rails.logger.info "Subscription deleted: #{event.data.object.id}"
  end
end
```

---

## Testing Webhooks Locally

```bash
# Forward webhooks to local server
stripe listen --forward-to localhost:3000/webhooks/stripe

# In another terminal, trigger test events
stripe trigger customer.subscription.created
stripe trigger invoice.payment_succeeded
```

---

## User Helpers

```ruby
# app/models/user.rb

class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe

  def plan_name
    # Check active subscription first
    sub = pay_subscriptions.active.last
    return PlansService.plan_name(sub.processor_plan) if sub

    # Check one-time purchases
    charge = pay_charges.where(refunded: false).last
    return PlansService.plan_name(charge.line_items.first&.dig("price_id")) if charge&.line_items&.any?

    "Free"
  end

  def subscription_active?
    pay_subscriptions.active.any?
  end

  def lifetime_access?
    pay_charges.where(refunded: false).joins(:line_items)
      .where("line_items.price_id IN (?)", PlansService.one_time_plans.map { |p| p[:id] })
      .exists?
  end

  def free_plan?
    !subscription_active? && !lifetime_access?
  end

  def paid_plan?
    !free_plan?
  end
end
```

---

## One-Time Payments

For lifetime access, credit packs, or digital product purchases.

### How It Works

1. User clicks "Buy" on a one-time plan
2. Checkout session created with `mode: "payment"` (PlansService handles this via the `mode` field)
3. Stripe processes payment
4. Webhook receives `checkout.session.completed`
5. Access granted based on pay_charges record

### Checking Access

```ruby
# Simple: user has any successful charge for this price
def purchased?(price_id)
  pay_charges.where(refunded: false).any? { |c|
    c.line_items&.any? { |li| li["price_id"] == price_id }
  }
end
```

### Credit / Token System

If selling consumable credits (e.g. AI tokens, message packs):

```ruby
# Migration
add_column :users, :credits, :integer, default: 0, null: false

# After purchase webhook
Pay::Webhooks.delegator.subscribe "stripe.checkout.session.completed" do |event|
  session = event.data.object
  next unless session.mode == "payment"

  user = Pay::Customer.find_by(processor_id: session.customer)&.owner
  next unless user

  # Map price to credits (define in PlansService)
  credits = PlansService.credits_for_price(session.line_items.data.first.price.id)
  user.increment!(:credits, credits) if credits
end
```

---

## Metered / Usage-Based Billing

For pay-per-use models where users are billed based on actual consumption.

### Stripe CLI Setup

```bash
# Create metered price
stripe prices create \
  --product="prod_XXX" \
  --currency=usd \
  --recurring[interval]=month \
  --recurring[usage-type]=metered \
  --unit-amount=10 \
  --lookup-key="api_calls"
```

### Reporting Usage

```ruby
# app/interactors/billing/report_usage.rb

class Billing::ReportUsage
  include Interactor

  delegate :user, :quantity, :description, to: :context

  def call
    subscription = user.pay_subscriptions.active.last
    context.fail!(error: I18n.t("billing.no_active_subscription")) unless subscription

    subscription_item_id = subscription.processor_subscription.items.data.first.id

    Stripe::SubscriptionItem.create_usage_record(
      subscription_item_id,
      quantity: quantity,
      timestamp: Time.current.to_i,
      action: "increment"
    )
  end
end
```

### Tracking Usage Locally

```ruby
# Migration
create_table :usage_records do |t|
  t.references :user, null: false, foreign_key: true
  t.string :metric, null: false          # e.g. "api_calls", "messages"
  t.integer :quantity, null: false
  t.boolean :synced_to_stripe, default: false
  t.timestamps
end

# Track usage on every API call / message / action
UsageRecord.create!(user: Current.user, metric: "api_calls", quantity: 1)

# Periodic job syncs to Stripe
class SyncUsageToStripeJob < ApplicationJob
  def perform
    UsageRecord.where(synced_to_stripe: false).group_by(&:user).each do |user, records|
      total = records.sum(&:quantity)
      Billing::ReportUsage.call(user: user, quantity: total)
      records.each { |r| r.update!(synced_to_stripe: true) }
    end
  end
end
```

---

## Frontend Integration

```jsx
// Pricing page
import { usePage, router } from "@inertiajs/react";

function Pricing({ plans }) {
  const { routes, auth } = usePage().props;

  const handleSubscribe = (planId) => {
    if (!auth.authenticated) {
      router.visit(routes.signup + `?plan=${planId}`);
    } else {
      router.get(routes.subscribe, { price_id: planId });
    }
  };

  return (
    <div className="grid md:grid-cols-3 gap-6">
      {plans.map(plan => (
        <PlanCard
          key={plan.id}
          plan={plan}
          onSelect={() => handleSubscribe(plan.id)}
        />
      ))}
    </div>
  );
}
```

---

## Environment Variables

```bash
# .env
STRIPE_PUBLIC_KEY=pk_test_XXX
STRIPE_SECRET_KEY=sk_test_XXX
STRIPE_WEBHOOK_SECRET=whsec_XXX
STRIPE_PRICE_PRO=price_XXX      # Production only
STRIPE_PRICE_MAX=price_XXX      # Production only
STRIPE_PRICE_LIFETIME=price_XXX # Production only (one-time, if used)
```

---

## Stripe CLI Cheatsheet

```bash
# Auth
stripe login
stripe logout

# Products
stripe products create --name="Name" --description="Desc"
stripe products list
stripe products retrieve prod_XXX

# Prices
stripe prices create --product=prod_XXX --unit-amount=2000 --currency=usd --recurring[interval]=month
stripe prices create --product=prod_XXX --unit-amount=9900 --currency=usd  # One-time
stripe prices create --product=prod_XXX --currency=usd --recurring[interval]=month --recurring[usage-type]=metered --unit-amount=10  # Metered
stripe prices list
stripe prices retrieve price_XXX

# Customers
stripe customers list
stripe customers retrieve cus_XXX

# Subscriptions
stripe subscriptions list
stripe subscriptions retrieve sub_XXX

# Webhooks
stripe listen --forward-to localhost:3000/webhooks/stripe
stripe trigger customer.subscription.created
stripe trigger invoice.payment_succeeded
stripe trigger invoice.payment_failed

# Logs
stripe logs tail
```
