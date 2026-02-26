# Email Verification & Password Reset

> Transactional email setup for Rails authentication.

---

## Overview

Rails authentication generator includes:
- Password reset flow
- Email verification (optional)

This guide covers setting up the emails properly.

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

### Production (Resend)

```ruby
# Gemfile
gem "resend"

# config/environments/production.rb
config.action_mailer.delivery_method = :resend
config.action_mailer.default_url_options = { host: ENV["RAILS_HOST"] }

# config/initializers/resend.rb
Resend.api_key = ENV["RESEND_API_KEY"]
```

```bash
# .env
RESEND_API_KEY=re_xxxxxxxxxxxxx
RAILS_HOST=yourdomain.com
```

---

## Password Reset Flow

### Routes (from Rails generator)

```ruby
# config/routes.rb
resources :passwords, param: :token
```

### Controller

```ruby
# app/controllers/passwords_controller.rb
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]

  def new
    render inertia: "Auth/ForgotPassword"
  end

  def create
    if (user = User.find_by(email: params[:email]))
      PasswordMailer.reset(user).deliver_later
    end
    # Always show success to prevent email enumeration
    redirect_to new_session_path, notice: "Check your email for reset instructions"
  end

  def edit
    render inertia: "Auth/ResetPassword", props: { token: params[:token] }
  end

  def update
    if @user.update(password_params)
      redirect_to new_session_path, notice: "Password updated. Please sign in."
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.first
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])
    redirect_to new_password_path, alert: "Invalid or expired link" unless @user
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
```

### User Model Token

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  generates_token_for :password_reset, expires_in: 1.hour do
    password_salt&.last(10)
  end

  generates_token_for :email_verification, expires_in: 3.days do
    email
  end
end
```

### Mailer

```ruby
# app/mailers/password_mailer.rb
class PasswordMailer < ApplicationMailer
  def reset(user)
    @user = user
    @token = user.generate_token_for(:password_reset)
    @url = edit_password_url(@token)

    mail(to: user.email, subject: "Reset your password")
  end
end
```

### Email Template

```erb
<!-- app/views/password_mailer/reset.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: system-ui, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .button {
      display: inline-block;
      background: #10B981;
      color: white;
      padding: 12px 24px;
      text-decoration: none;
      border-radius: 6px;
      margin: 20px 0;
    }
    .footer { color: #666; font-size: 14px; margin-top: 30px; }
  </style>
</head>
<body>
  <div class="container">
    <h2>Reset Your Password</h2>

    <p>Hi <%= @user.name || @user.email %>,</p>

    <p>We received a request to reset your password. Click the button below to choose a new one:</p>

    <a href="<%= @url %>" class="button">Reset Password</a>

    <p>This link will expire in 1 hour.</p>

    <p>If you didn't request this, you can safely ignore this email.</p>

    <div class="footer">
      <p>— The [APP NAME] Team</p>
    </div>
  </div>
</body>
</html>
```

### React Pages

```jsx
// app/frontend/pages/Auth/ForgotPassword.jsx
import { Head, useForm } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

export default function ForgotPassword() {
  const { data, setData, post, processing } = useForm({ email: "" })

  const handleSubmit = (e) => {
    e.preventDefault()
    post("/passwords")
  }

  return (
    <>
      <Head title="Forgot Password" />

      <div className="max-w-md mx-auto py-12 px-4">
        <h1 className="text-2xl font-bold mb-6">Forgot your password?</h1>
        <p className="text-muted-foreground mb-6">
          Enter your email and we'll send you a reset link.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              value={data.email}
              onChange={(e) => setData("email", e.target.value)}
              required
            />
          </div>
          <Button type="submit" disabled={processing} className="w-full">
            Send Reset Link
          </Button>
        </form>
      </div>
    </>
  )
}
```

```jsx
// app/frontend/pages/Auth/ResetPassword.jsx
import { Head, useForm } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

export default function ResetPassword({ token }) {
  const { data, setData, patch, processing, errors } = useForm({
    password: "",
    password_confirmation: "",
  })

  const handleSubmit = (e) => {
    e.preventDefault()
    patch(`/passwords/${token}`)
  }

  return (
    <>
      <Head title="Reset Password" />

      <div className="max-w-md mx-auto py-12 px-4">
        <h1 className="text-2xl font-bold mb-6">Set a new password</h1>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="password">New Password</Label>
            <Input
              id="password"
              type="password"
              value={data.password}
              onChange={(e) => setData("password", e.target.value)}
              required
            />
          </div>
          <div>
            <Label htmlFor="password_confirmation">Confirm Password</Label>
            <Input
              id="password_confirmation"
              type="password"
              value={data.password_confirmation}
              onChange={(e) => setData("password_confirmation", e.target.value)}
              required
            />
          </div>
          <Button type="submit" disabled={processing} className="w-full">
            Update Password
          </Button>
        </form>
      </div>
    </>
  )
}
```

---

## Email Verification (Optional)

### Add to User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Add email_verified_at column via migration

  def verified?
    email_verified_at.present?
  end

  def verify!
    update!(email_verified_at: Time.current)
  end
end
```

### Migration

```ruby
# db/migrate/xxx_add_email_verification_to_users.rb
class AddEmailVerificationToUsers < ActiveRecord::Migration[x.x]
  def change
    add_column :users, :email_verified_at, :datetime
  end
end
```

### Verification Controller

```ruby
# app/controllers/email_verifications_controller.rb
class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: [:show]

  def show
    user = User.find_by_token_for(:email_verification, params[:token])

    if user
      user.verify!
      redirect_to root_path, notice: "Email verified!"
    else
      redirect_to root_path, alert: "Invalid or expired verification link"
    end
  end

  def create
    EmailVerificationMailer.verify(current_user).deliver_later
    redirect_back fallback_location: root_path, notice: "Verification email sent"
  end
end
```

### Routes

```ruby
# config/routes.rb
resources :email_verifications, only: [:show, :create]
```

### Mailer

```ruby
# app/mailers/email_verification_mailer.rb
class EmailVerificationMailer < ApplicationMailer
  def verify(user)
    @user = user
    @token = user.generate_token_for(:email_verification)
    @url = email_verification_url(@token)

    mail(to: user.email, subject: "Verify your email")
  end
end
```

---

## Send Verification on Signup

```ruby
# app/controllers/registrations_controller.rb
def create
  @user = User.new(user_params)

  if @user.save
    EmailVerificationMailer.verify(@user).deliver_later
    start_new_session_for(@user)
    redirect_to root_path, notice: "Welcome! Please check your email to verify your account."
  else
    # handle errors
  end
end
```

---

## Email Styling Tips

1. **Inline CSS** - Email clients strip `<style>` tags, so inline critical styles
2. **Simple layouts** - Use tables for reliable rendering
3. **Test everywhere** - Litmus or Email on Acid for testing
4. **Dark mode** - Add `@media (prefers-color-scheme: dark)` support
5. **Plain text version** - Always include `.text.erb` fallback
