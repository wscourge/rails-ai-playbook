# Settings Page

> User account settings pattern for Rails + Inertia apps.

---

## Interview First

Before building the settings page, ask the user:

1. **What settings do users need to manage?**
   - Profile info (name, email, avatar)?
   - Password change?
   - Email preferences/notifications?
   - Subscription/billing management?
   - Connected accounts (Google, etc.)?
   - Delete account?

2. **Any app-specific settings?**
   - Theme preference (dark/light)?
   - Timezone?
   - Language?
   - Custom app preferences?

3. **Subscription management?**
   - Show current plan?
   - Upgrade/downgrade?
   - Cancel subscription?
   - View invoices?

---

## Standard Settings Structure

### Controller

```ruby
# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  def show
    user = Current.user

    render inertia: "Settings/Show", props: {
      user: {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        email_address: user.email_address,
        handle: user.handle,
      },
      subscription: subscription_props,
      connected_accounts: connected_accounts_props,
    }
  end

  def update
    result = Users::UpdateProfile.call(
      user: Current.user,
      params: user_params.to_h,
    )

    if result.success?
      redirect_to settings_path, notice: I18n.t("settings.profile_updated")
    else
      redirect_to settings_path, alert: result.error
    end
  end

  def update_password
    result = Users::UpdatePassword.call(
      user: Current.user,
      params: password_params.to_h,
    )

    if result.success?
      redirect_to settings_path, notice: I18n.t("settings.password_updated")
    else
      redirect_to settings_path, alert: result.error
    end
  end

  def destroy
    result = Users::DeleteAccount.call(user: Current.user)

    if result.success?
      terminate_session
      redirect_to root_path, notice: I18n.t("settings.account_deleted")
    else
      redirect_to settings_path, alert: result.error
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address, :handle)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def subscription_props
    return nil unless Current.user.payment_processor

    sub = Current.user.payment_processor.subscription
    return nil unless sub

    {
      plan: sub.processor_plan,
      status: sub.status,
      current_period_end: sub.current_period_end,
      cancel_at_period_end: sub.ends_at.present?,
    }
  end

  def connected_accounts_props
    # Return connected OAuth accounts if using OmniAuth
    []
  end
end
```

### Interactors

```ruby
# app/interactors/users/update_profile.rb
module Users
  class UpdateProfile
    include Interactor

    def call
      user = context.user
      params = context.params

      unless user.update(params)
        context.fail!(error: user.errors.full_messages.first)
      end
    end
  end
end
```

```ruby
# app/interactors/users/update_password.rb
module Users
  class UpdatePassword
    include Interactor

    def call
      user = context.user
      params = context.params

      if params[:password].blank?
        context.fail!(error: I18n.t("settings.password_blank"))
      end

      unless user.update(params)
        context.fail!(error: user.errors.full_messages.first)
      end
    end
  end
end
```

```ruby
# app/interactors/users/delete_account.rb
module Users
  class DeleteAccount
    include Interactor

    def call
      context.user.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      context.fail!(error: I18n.t("settings.delete_failed"))
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
resource :settings, only: [:show, :update] do
  patch :update_password
  delete :destroy, as: :delete_account
end
```

### React Page

```jsx
// app/frontend/pages/Settings/Show.jsx
import { Head, useForm, usePage } from "@inertiajs/react"
import { useTranslation } from "react-i18next"
import { z } from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"

const profileSchema = z.object({
  first_name: z.string().min(1),
  last_name: z.string().min(1),
  email_address: z.string().email(),
  handle: z
    .string()
    .min(3)
    .max(30)
    .regex(/^[a-z0-9][a-z0-9_-]*[a-z0-9]$/)
    .optional()
    .or(z.literal("")),
})

const passwordSchema = z
  .object({
    password: z.string().min(8),
    password_confirmation: z.string().min(8),
  })
  .refine((data) => data.password === data.password_confirmation, {
    path: ["password_confirmation"],
  })

export default function SettingsShow() {
  const { t } = useTranslation()
  const { user, subscription, routes } = usePage().props

  const profileForm = useForm({
    first_name: user.first_name || "",
    last_name: user.last_name || "",
    email_address: user.email_address || "",
    handle: user.handle || "",
  })

  const passwordForm = useForm({
    password: "",
    password_confirmation: "",
  })

  const handleProfileSubmit = (e) => {
    e.preventDefault()
    const result = profileSchema.safeParse(profileForm.data)
    if (!result.success) {
      const fieldErrors = result.error.flatten().fieldErrors
      Object.entries(fieldErrors).forEach(([key, msgs]) => {
        profileForm.setError(key, msgs[0])
      })
      return
    }
    profileForm.patch(routes.settings)
  }

  const handlePasswordSubmit = (e) => {
    e.preventDefault()
    const result = passwordSchema.safeParse(passwordForm.data)
    if (!result.success) {
      const fieldErrors = result.error.flatten().fieldErrors
      Object.entries(fieldErrors).forEach(([key, msgs]) => {
        passwordForm.setError(key, msgs[0])
      })
      return
    }
    passwordForm.patch(routes.settings_update_password, {
      onSuccess: () => passwordForm.reset(),
    })
  }

  const handleDeleteAccount = () => {
    if (window.confirm(t("settings.delete_confirm"))) {
      profileForm.delete(routes.settings_delete_account)
    }
  }

  return (
    <>
      <Head title={t("settings.title")} />

      <div className="max-w-2xl mx-auto py-8 px-4 space-y-6">
        <h1 className="text-2xl font-bold">{t("settings.title")}</h1>

        {/* Profile Section */}
        <Card>
          <CardHeader>
            <CardTitle>{t("settings.profile.title")}</CardTitle>
            <CardDescription>{t("settings.profile.description")}</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleProfileSubmit} className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <Label htmlFor="first_name">{t("settings.profile.first_name")}</Label>
                  <Input
                    id="first_name"
                    value={profileForm.data.first_name}
                    onChange={(e) => profileForm.setData("first_name", e.target.value)}
                  />
                  {profileForm.errors.first_name && (
                    <p className="text-sm text-destructive mt-1">{profileForm.errors.first_name}</p>
                  )}
                </div>
                <div>
                  <Label htmlFor="last_name">{t("settings.profile.last_name")}</Label>
                  <Input
                    id="last_name"
                    value={profileForm.data.last_name}
                    onChange={(e) => profileForm.setData("last_name", e.target.value)}
                  />
                  {profileForm.errors.last_name && (
                    <p className="text-sm text-destructive mt-1">{profileForm.errors.last_name}</p>
                  )}
                </div>
              </div>
              <div>
                <Label htmlFor="email_address">{t("settings.profile.email")}</Label>
                <Input
                  id="email_address"
                  type="email"
                  value={profileForm.data.email_address}
                  onChange={(e) => profileForm.setData("email_address", e.target.value)}
                />
                {profileForm.errors.email_address && (
                  <p className="text-sm text-destructive mt-1">{profileForm.errors.email_address}</p>
                )}
              </div>
              <div>
                <Label htmlFor="handle">{t("settings.profile.handle")}</Label>
                <Input
                  id="handle"
                  value={profileForm.data.handle}
                  onChange={(e) => profileForm.setData("handle", e.target.value)}
                  placeholder={t("settings.profile.handle_placeholder")}
                />
                {profileForm.errors.handle && (
                  <p className="text-sm text-destructive mt-1">{profileForm.errors.handle}</p>
                )}
              </div>
              <Button type="submit" disabled={profileForm.processing}>
                {t("settings.save")}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Password Section */}
        <Card>
          <CardHeader>
            <CardTitle>{t("settings.password.title")}</CardTitle>
            <CardDescription>{t("settings.password.description")}</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handlePasswordSubmit} className="space-y-4">
              <div>
                <Label htmlFor="password">{t("settings.password.new_password")}</Label>
                <Input
                  id="password"
                  type="password"
                  value={passwordForm.data.password}
                  onChange={(e) => passwordForm.setData("password", e.target.value)}
                />
                {passwordForm.errors.password && (
                  <p className="text-sm text-destructive mt-1">{passwordForm.errors.password}</p>
                )}
              </div>
              <div>
                <Label htmlFor="password_confirmation">{t("settings.password.confirm")}</Label>
                <Input
                  id="password_confirmation"
                  type="password"
                  value={passwordForm.data.password_confirmation}
                  onChange={(e) => passwordForm.setData("password_confirmation", e.target.value)}
                />
                {passwordForm.errors.password_confirmation && (
                  <p className="text-sm text-destructive mt-1">{passwordForm.errors.password_confirmation}</p>
                )}
              </div>
              <Button type="submit" disabled={passwordForm.processing}>
                {t("settings.password.update")}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Subscription Section (if applicable) */}
        {subscription && (
          <Card>
            <CardHeader>
              <CardTitle>{t("settings.subscription.title")}</CardTitle>
              <CardDescription>{t("settings.subscription.description")}</CardDescription>
            </CardHeader>
            <CardContent>
              <p>
                {t("settings.subscription.current_plan")}: <strong>{subscription.plan}</strong>
              </p>
              <p>{t("settings.subscription.status")}: {subscription.status}</p>
              {/* Add billing portal link via Stripe */}
            </CardContent>
          </Card>
        )}

        {/* Danger Zone */}
        <Card className="border-destructive">
          <CardHeader>
            <CardTitle className="text-destructive">{t("settings.danger.title")}</CardTitle>
            <CardDescription>{t("settings.danger.description")}</CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="destructive" onClick={handleDeleteAccount}>
              {t("settings.danger.delete_account")}
            </Button>
          </CardContent>
        </Card>
      </div>
    </>
  )
}
```

---

## Billing Portal (Stripe)

For subscription management, use Stripe's Customer Portal:

```ruby
# app/controllers/billing_controller.rb
class BillingController < ApplicationController
  def portal
    session = Current.user.payment_processor.billing_portal(
      return_url: settings_url
    )
    redirect_to session.url, allow_other_host: true
  end
end

# routes.rb
get "billing/portal", to: "billing#portal"
```

This lets users manage subscriptions, payment methods, and invoices without you building UI.

---

## i18n Keys

```yaml
# app/frontend/locales/en/settings.yml
settings:
  title: Settings
  save: Save Changes
  profile_updated: Profile updated
  password_updated: Password updated
  password_blank: Password cannot be blank
  account_deleted: Account deleted
  delete_failed: Failed to delete account
  delete_confirm: Are you sure? This action cannot be undone.
  profile:
    title: Profile
    description: Update your account information
    first_name: First Name
    last_name: Last Name
    email: Email
    handle: Handle
    handle_placeholder: janedoe
  password:
    title: Password
    description: Change your password
    new_password: New Password
    confirm: Confirm Password
    update: Update Password
  subscription:
    title: Subscription
    description: Manage your subscription
    current_plan: Current plan
    status: Status
  danger:
    title: Danger Zone
    description: Irreversible actions
    delete_account: Delete Account
```

```yaml
# config/locales/en/settings.yml
en:
  settings:
    profile_updated: Profile updated
    password_updated: Password updated
    password_blank: Password cannot be blank
    account_deleted: Account deleted
    delete_failed: Failed to delete account
```
