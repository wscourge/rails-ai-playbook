# Legal Pages (Privacy Policy & Terms of Service)

> Privacy policy and terms of service for Rails apps.

---

## Interview First

Ask the user:

1. **What data do you collect?**
   - Account info (name, email)?
   - Payment info (via Stripe)?
   - Usage data (analytics)?
   - Cookies?

2. **Do you use third-party services?**
   - Stripe (payments)
   - Google Analytics
   - Error tracking (Sentry, etc.)
   - Email & SMS service (Brevo)

3. **Any special considerations?**
   - GDPR compliance (EU users)?
   - CCPA (California users)?
   - Data export/deletion requirements?

4. **Business details for ToS:**
   - Company name or personal name?
   - Jurisdiction (which state/country)?
   - Refund policy?

---

## Setup

### Routes

```ruby
# config/routes.rb
get "privacy", to: "pages#privacy"
get "terms", to: "pages#terms"
```

### Controller

```ruby
# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  allow_unauthenticated_access

  def privacy
    render inertia: "Pages/Privacy"
  end

  def terms
    render inertia: "Pages/Terms"
  end
end
```

---

## Privacy Policy Template

```jsx
// app/frontend/pages/pages/privacy.jsx
import { Head } from "@inertiajs/react"

export default function Privacy() {
  return (
    <>
      <Head title="Privacy Policy" />

      <div className="max-w-3xl mx-auto py-12 px-4 prose prose-neutral dark:prose-invert">
        <h1>Privacy Policy</h1>
        <p className="text-muted-foreground">Last updated: [DATE]</p>

        <h2>Information We Collect</h2>
        <p>
          When you create an account, we collect your name and email address.
          If you subscribe to a paid plan, payment processing is handled by
          Stripe—we do not store your credit card information.
        </p>

        <h2>How We Use Your Information</h2>
        <ul>
          <li>To provide and maintain our service</li>
          <li>To process payments and send receipts</li>
          <li>To send important updates about your account</li>
          <li>To respond to support requests</li>
        </ul>

        <h2>Third-Party Services</h2>
        <p>We use the following third-party services:</p>
        <ul>
          <li><strong>Stripe</strong> - Payment processing</li>
          <li><strong>Google Analytics</strong> - Usage analytics</li>
          <li><strong>[Email Service]</strong> - Transactional emails</li>
        </ul>

        <h2>Cookies</h2>
        <p>
          We use essential cookies to keep you logged in. We also use analytics
          cookies to understand how people use our service.
        </p>

        <h2>Data Retention</h2>
        <p>
          We retain your account data for as long as your account is active.
          You can delete your account at any time from Settings.
        </p>

        <h2>Your Rights</h2>
        <p>You have the right to:</p>
        <ul>
          <li>Access your personal data</li>
          <li>Correct inaccurate data</li>
          <li>Delete your account and data</li>
          <li>Export your data</li>
        </ul>

        <h2>Contact Us</h2>
        <p>
          Questions about this policy? Email us at{" "}
          <a href="mailto:privacy@[DOMAIN]">privacy@[DOMAIN]</a>
        </p>
      </div>
    </>
  )
}
```

---

## Terms of Service Template

```jsx
// app/frontend/pages/pages/terms.jsx
import { Head } from "@inertiajs/react"

export default function Terms() {
  return (
    <>
      <Head title="Terms of Service" />

      <div className="max-w-3xl mx-auto py-12 px-4 prose prose-neutral dark:prose-invert">
        <h1>Terms of Service</h1>
        <p className="text-muted-foreground">Last updated: [DATE]</p>

        <h2>1. Acceptance of Terms</h2>
        <p>
          By accessing or using [APP NAME], you agree to be bound by these
          Terms of Service. If you disagree with any part of the terms, you
          may not access the service.
        </p>

        <h2>2. Description of Service</h2>
        <p>
          [APP NAME] provides [BRIEF DESCRIPTION OF WHAT THE APP DOES].
        </p>

        <h2>3. User Accounts</h2>
        <p>
          You are responsible for maintaining the confidentiality of your
          account credentials. You agree to notify us immediately of any
          unauthorized use of your account.
        </p>

        <h2>4. Payment Terms</h2>
        <p>
          Paid subscriptions are billed [monthly/annually] in advance.
          All payments are processed securely through Stripe.
        </p>

        <h3>Refunds</h3>
        <p>
          [DEFINE REFUND POLICY - e.g., "We offer a 14-day money-back
          guarantee for new subscriptions."]
        </p>

        <h3>Cancellation</h3>
        <p>
          You may cancel your subscription at any time. Your access will
          continue until the end of your current billing period.
        </p>

        <h2>5. Acceptable Use</h2>
        <p>You agree not to:</p>
        <ul>
          <li>Use the service for any illegal purpose</li>
          <li>Attempt to gain unauthorized access to our systems</li>
          <li>Interfere with or disrupt the service</li>
          <li>Resell or redistribute the service without permission</li>
        </ul>

        <h2>6. Intellectual Property</h2>
        <p>
          The service and its original content, features, and functionality
          are owned by [COMPANY/YOUR NAME] and are protected by copyright,
          trademark, and other intellectual property laws.
        </p>

        <h2>7. Limitation of Liability</h2>
        <p>
          [APP NAME] shall not be liable for any indirect, incidental,
          special, consequential, or punitive damages resulting from your
          use of or inability to use the service.
        </p>

        <h2>8. Changes to Terms</h2>
        <p>
          We reserve the right to modify these terms at any time. We will
          notify users of significant changes via email.
        </p>

        <h2>9. Governing Law</h2>
        <p>
          These terms shall be governed by the laws of [STATE/COUNTRY],
          without regard to its conflict of law provisions.
        </p>

        <h2>10. Contact</h2>
        <p>
          Questions about these terms? Email us at{" "}
          <a href="mailto:legal@[DOMAIN]">legal@[DOMAIN]</a>
        </p>
      </div>
    </>
  )
}
```

---

## Footer Links

Add to your footer component:

```jsx
<div className="flex gap-4 text-sm text-muted-foreground">
  <Link href="/privacy">Privacy Policy</Link>
  <Link href="/terms">Terms of Service</Link>
</div>
```

---

## Important Notes

1. **These are templates** - Have a lawyer review for your specific situation
2. **Update [PLACEHOLDERS]** - Replace with actual company info
3. **Keep updated** - Review annually or when adding new features/services
4. **GDPR/CCPA** - If serving EU/California users, may need additional clauses
