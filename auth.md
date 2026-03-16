# Authentication - Rails + OmniAuth

> Rails authentication generator + OmniAuth for social login.

---

## Overview

Rails includes a built-in authentication generator that provides:
- Session-based authentication (no JWT)
- `has_secure_password` for email/password login
- `Current.user` pattern for accessing authenticated user
- Session model for tracking active sessions

We extend this with OmniAuth for social login (Google, OpenAI, etc.).

---

## Step 1: Generate Rails Auth

```bash
bin/rails generate authentication
```

This creates:
- `app/models/user.rb` with `has_secure_password`
- `app/models/session.rb` for session tracking
- `app/models/current.rb` for `Current.user`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/passwords_controller.rb`
- Database migrations for users and sessions

---

## Step 2: Add User Handle

Users can claim a unique, URL-friendly handle (e.g. `@janedoe`). The handle is optional at signup and can be claimed later from settings.

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_handle_to_users.rb

class AddHandleToUsers < ActiveRecord::Migration[x.x]
  def change
    add_column :users, :handle, :string
    add_index :users, :handle, unique: true
  end
end
```

### Handle Rules

- **Format:** lowercase letters, numbers, hyphens, underscores. Must start and end with a letter or number.
- **Length:** 3–30 characters
- **Uniqueness:** enforced at DB level (unique index) and application level
- **Normalization:** auto-downcased and stripped
- **Reserved words:** block handles like `admin`, `staff`, `api`, `settings`, `app`, `billing`, `login`, `signup`, `contact`, `support`, `help`, etc. to prevent route collisions

### Reserved Handle Check

```ruby
# In a validation interactor
RESERVED_HANDLES = %w[
  admin staff api app settings billing login signup logout
  contact support help pricing about terms privacy
  new edit delete create update destroy
].freeze

def call
  if RESERVED_HANDLES.include?(context.handle)
    context.fail!(error: I18n.t("errors.handle_reserved"))
  end
end
```

### Handle Availability Endpoint

Provide a lightweight endpoint for real-time availability checking:

```ruby
# app/controllers/api/v1/handles_controller.rb
class Api::V1::HandlesController < ApplicationController
  allow_unauthenticated_access

  def check
    handle = params[:handle]&.strip&.downcase
    available = handle.present? &&
                handle.match?(/\A[a-z0-9][a-z0-9_-]*[a-z0-9]\z/) &&
                handle.length.between?(3, 30) &&
                !RESERVED_HANDLES.include?(handle) &&
                !User.exists?(handle: handle)

    render json: { available: }
  end
end
```

---

## Step 3: Extend User Model for OAuth

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password validations: false  # Optional password for OAuth users
  has_many :sessions, dependent: :destroy

  # OAuth UIDs
  attribute :google_uid, :string
  attribute :openai_uid, :string

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :handle, with: ->(h) { h.strip.downcase.gsub(/[^a-z0-9_-]/, "") }

  # Token-based email verification (Rails 7.1+)
  generates_token_for :email_verification, expires_in: 24.hours do
    email_verified_at
  end

  def full_name
    [first_name, last_name].compact.join(" ").presence || email_address.split("@").first
  end

  def initials
    full_name.split.map(&:first).join.upcase[0, 2]
  end

  # Auth predicates
  def oauth_user? = google_uid.present?
  def password_user? = password_digest.present?
  def email_verified? = email_verified_at.present?

  # Find or create from OAuth
  def self.find_or_create_from_oauth(auth)
    provider = auth.provider
    uid = auth.uid

    # Find by provider UID first
    user = case provider
    when 'google_oauth2'
      find_by(google_uid: uid)
    when 'openai'
      find_by(openai_uid: uid)
    end

    # Then by email
    user ||= find_by(email_address: auth.info.email)

    if user
      # Link OAuth account if not already linked
      uid_column = "#{provider == 'google_oauth2' ? 'google' : provider}_uid"
      user.update!(uid_column => uid) if user.send(uid_column).blank?
    else
      # Create new user (no password required for OAuth)
      user = create!(
        email_address: auth.info.email,
        first_name: auth.info.name&.split&.first,
        last_name: auth.info.name&.split&.drop(1)&.join(' '),
        "#{provider == 'google_oauth2' ? 'google' : provider}_uid" => uid,
        email_verified_at: Time.current  # OAuth emails are pre-verified
      )
    end

    user
  end
end
```

---

## Step 4: Add OmniAuth

```ruby
# Gemfile
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# For OpenAI OAuth (custom strategy needed)
gem 'omniauth-oauth2'
```

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    OAuthConfig.google_client_id,
    OAuthConfig.google_client_secret,
    {
      scope: 'email,profile',
      prompt: 'select_account'
    }

  # Add OpenAI if needed (requires custom strategy)
  # provider :openai, OAuthConfig.openai_client_id, OAuthConfig.openai_client_secret
end

OmniAuth.config.allowed_request_methods = [:post]
```

See [anyway-config.md](anyway-config.md) for the `OAuthConfig` class definition.

---

## Step 5: OAuth Controller

Use an interactor to encapsulate the OAuth login logic:

```ruby
# app/interactors/users/oauth_login.rb
class Users::OauthLogin
  include Interactor

  def call
    context.user = User.find_or_create_from_oauth(context.auth)
  end
end
```

```ruby
# app/controllers/oauth_controller.rb
class OauthController < ApplicationController
  allow_unauthenticated_access

  def callback
    result = Users::OauthLogin.call(auth: request.env["omniauth.auth"])
    user = result.user

    start_new_session_for(user)
    set_last_login_method(result.auth.provider)
    redirect_to after_login_path, notice: "Welcome, #{user.first_name}!"
  end

  def failure
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end

  private

  def after_login_path
    stored_location || app_path
  end

  def stored_location
    session.delete(:return_to)
  end
end
```

```ruby
# config/routes.rb
# OAuth callbacks
get '/auth/:provider/callback', to: 'oauth#callback'
get '/auth/failure', to: 'oauth#failure'
```

---

## Step 6: Authentication Concern

The generated `Authentication` concern provides helper methods. Extend if needed:

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.session.present?
  end

  def current_user
    Current.user
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    if session_id = cookies.signed[:session_id]
      if session = Session.find_by(id: session_id)
        Current.session = session
        return true
      end
    end
    false
  end

  def request_authentication
    session[:return_to] = request.fullpath
    redirect_to login_path, alert: "Please log in to continue."
  end

  def start_new_session_for(user)
    session = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    Current.session = session
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    Current.session = nil
  end
end
```

---

## Step 7: Current Model

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

---

## Key Points

1. **No JWT** — Rails uses cookie-based sessions
2. **Optional password** — OAuth users don't need a password
3. **`Current.user`** — Access authenticated user anywhere
4. **Session tracking** — Each login creates a Session record
5. **`allow_unauthenticated_access`** — Explicitly mark public actions
6. **Rate limiting** — Protect auth endpoints from brute force

---

## Registration Flow (Interactor Organizer)

Use an organizer to orchestrate multi-step registration:

```ruby
# app/interactors/users/register.rb
class Users::Register
  include Interactor::Organizer

  around do |interactor|
    ActiveRecord::Base.transaction do
      interactor.call
    rescue Interactor::Failure
      raise ActiveRecord::Rollback
    end
  end

  organize Users::ValidateRegistration,
           Users::CreateUser,
           Users::SendVerification
end
```

```ruby
# app/interactors/users/validate_registration.rb
class Users::ValidateRegistration
  include Interactor

  def call
    validate_email_format
    validate_email_unique
    validate_password_strength
  end

  private

  def validate_email_format
    unless context.email.to_s.match?(URI::MailTo::EMAIL_REGEXP)
      context.fail!(error: I18n.t("errors.invalid_email"))
    end
  end

  def validate_email_unique
    if User.exists?(email_address: context.email.downcase)
      context.fail!(error: I18n.t("errors.email_taken"))
    end
  end

  def validate_password_strength
    if context.password.to_s.length < 8
      context.fail!(error: I18n.t("errors.password_too_short"))
    end
  end
end
```

```ruby
# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def create
    result = Users::Register.call(
      email: params[:email],
      password: params[:password],
      first_name: params[:first_name],
      last_name: params[:last_name]
    )

    if result.success?
      start_new_session_for(result.user)
      set_last_login_method("password")
      redirect_to after_signup_path
    else
      redirect_to signup_path, inertia: { errors: { base: result.error } }
    end
  end
end
```

---

## "Last Used" Login Method (OAuth only)

When the app has OAuth, show a "Last used" badge on the login form so returning users instantly see which method they used last time. The indicator is stored in a long-lived, non-sensitive cookie — **only implement this when OAuth is enabled** (it's pointless with email/password only).

### Authentication Concern

Add a helper to set the cookie on every successful login (both password and OAuth):

```ruby
# app/controllers/concerns/authentication.rb (add to existing)

LAST_LOGIN_METHOD_COOKIE = :last_login_method

private

def set_last_login_method(method)
  # method: "password", "google_oauth2", "openai", etc.
  cookies.permanent[LAST_LOGIN_METHOD_COOKIE] = {
    value: method,
    httponly: true,
    same_site: :lax
  }
end

def last_login_method
  cookies[LAST_LOGIN_METHOD_COOKIE]
end
```

### Set on Password Login

```ruby
# app/controllers/sessions_controller.rb

def create
  user = User.authenticate_by(
    email_address: params[:email],
    password: params[:password]
  )

  if user
    start_new_session_for(user)
    set_last_login_method("password")  # Track login method
    redirect_to after_login_path
  else
    redirect_to login_path, alert: I18n.t("auth.invalid_credentials")
  end
end
```

### Pass to Login Page

```ruby
# app/controllers/sessions_controller.rb

def new
  render inertia: "Auth/Login", props: {
    last_login_method: last_login_method,  # nil, "password", "google_oauth2", etc.
    oauth_providers: enabled_oauth_providers
  }
end

private

def enabled_oauth_providers
  providers = []
  providers << { key: "google_oauth2", name: "Google" } if OAuthConfig.google_client_id.present?
  # providers << { key: "openai", name: "OpenAI" } if OAuthConfig.openai_client_id.present?
  providers
end
```

### Login Page with "Last Used" Badge

```jsx
// app/frontend/pages/auth/login.jsx

import { Head, useForm, usePage } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

function LastUsedBadge({ method, current }) {
  const { t } = useTranslation();
  if (method !== current) return null;

  return (
    <Badge variant="secondary" className="ml-2 text-xs font-normal">
      {t("auth.last_used")}
    </Badge>
  );
}

export default function Login({ last_login_method, oauth_providers }) {
  const { t } = useTranslation();
  const { routes } = usePage().props;
  const { data, setData, post, processing } = useForm({
    email: "",
    password: "",
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    post(routes.login);
  };

  return (
    <>
      <Head title={t("auth.login_title")} />

      <div className="max-w-sm mx-auto py-12 px-4">
        <h1 className="text-2xl font-bold text-center mb-6">
          {t("auth.login_title")}
        </h1>

        {/* OAuth buttons */}
        {oauth_providers.length > 0 && (
          <div className="space-y-2 mb-6">
            {oauth_providers.map((provider) => (
              <form
                key={provider.key}
                action={`/auth/${provider.key}`}
                method="post"
                className="w-full"
              >
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={document.querySelector('meta[name="csrf-token"]')?.content}
                />
                <Button
                  type="submit"
                  variant="outline"
                  className="w-full justify-center"
                >
                  {t(`auth.continue_with`, { provider: provider.name })}
                  <LastUsedBadge
                    method={last_login_method}
                    current={provider.key}
                  />
                </Button>
              </form>
            ))}

            <div className="relative my-4">
              <Separator />
              <span className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-background text-muted-foreground text-xs px-2">
                {t("auth.or")}
              </span>
            </div>
          </div>
        )}

        {/* Email/password form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <div className="flex items-center">
              <Label htmlFor="email">{t("auth.email")}</Label>
              <LastUsedBadge method={last_login_method} current="password" />
            </div>
            <Input
              id="email"
              type="email"
              value={data.email}
              onChange={(e) => setData("email", e.target.value)}
              autoComplete="email"
              autoFocus={last_login_method === "password" || !last_login_method}
            />
          </div>

          <div>
            <Label htmlFor="password">{t("auth.password")}</Label>
            <Input
              id="password"
              type="password"
              value={data.password}
              onChange={(e) => setData("password", e.target.value)}
              autoComplete="current-password"
            />
          </div>

          <Button type="submit" disabled={processing} className="w-full">
            {t("auth.login")}
          </Button>
        </form>
      </div>
    </>
  );
}
```

### i18n Keys

```yaml
# app/frontend/locales/en/auth.yml (merge with existing)
auth:
  last_used: Last used
  continue_with: "Continue with {{provider}}"
  or: or
```

### Notes

1. **Cookie is `httponly`** — not accessible via JavaScript, only the server reads it and passes it as a prop.
2. **Cookie is permanent** — survives browser restarts. Non-sensitive (just a method name like `"google_oauth2"`).
3. **`autoFocus` hint** — the email input auto-focuses when the last method was password (or first visit). When the last method was OAuth, the OAuth button is visually highlighted with the badge instead.
4. **Skip entirely without OAuth** — if `oauth_providers` is empty, the separator, "or" divider, and "Last used" badge logic are all irrelevant and hidden.

---

## Common Patterns

### Require auth except for certain actions
```ruby
class PagesController < ApplicationController
  allow_unauthenticated_access only: [:home, :pricing, :about]
end
```

### Store location for redirect after login
```ruby
def request_authentication
  session[:return_to] = request.fullpath
  redirect_to login_path
end

# After login:
redirect_to session.delete(:return_to) || app_path
```

### Rate Limiting Auth Endpoints

Protect login and registration from brute force attacks:

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { 
    redirect_to login_path, alert: I18n.t("auth.too_many_attempts") 
  }

  # ...
end

# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.minute, only: :create, with: -> {
    redirect_to signup_path, alert: I18n.t("auth.too_many_attempts")
  }

  # ...
end
```

```yaml
# app/frontend/locales/en/auth.yml
auth:
  too_many_attempts: Too many attempts. Please wait a few minutes and try again.
```

### Check authentication in views
```jsx
const { auth } = usePage().props;

{auth.authenticated ? (
  <p>Welcome, {auth.user.first_name}!</p>
) : (
  <Link href={routes.login}>Log in</Link>
)}
```
