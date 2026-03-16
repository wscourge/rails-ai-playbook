# Staff Admin Panel

> Internal staff/admin panel setup: database table, access control, rake task, and frontend scaffold.

---

## Overview

Every app needs an internal staff panel for admin operations. There are two common patterns:

1. **Separate `staffs` table** (default below) — Staff join table with user, more flexible for extending staff-specific attributes
2. **Staff columns on User** — Simpler, add `staff` boolean + `staff_role` enum directly to users table

Choose based on complexity. For most apps, the separate table is cleaner.

---

## Pattern A: Separate Staff Table (Default)

### Database

#### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_staffs.rb

class CreateStaffs < ActiveRecord::Migration[x.x]
  def change
    create_table :staffs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :role, null: false, default: 0
      t.string :telegram_chat_id  # optional — enables Telegram notifications

      t.timestamps
    end
  end
end
```

### Model

```ruby
# app/models/staff.rb

class Staff < ApplicationRecord
  enum :role, { staff: 0, admin: 1, super_admin: 2 }

  belongs_to :user

  class << self
    def with_telegram
      where.not(telegram_chat_id: [nil, ""])
    end
  end

  # Rails enum auto-generates: staff?, admin?, super_admin?
  # Use this helper when "admin or above" is needed
  def at_least_admin?
    admin? || super_admin?
  end

  def telegram?
    telegram_chat_id.present?
  end
end
```

### User Association

```ruby
# app/models/user.rb (add to existing model)

has_one :staff, dependent: :destroy

def staff?
  staff.present?
end

def staff_role
  staff&.role
end
```

---

## Rake Task

Add a rake task to promote a user to staff by email:

```ruby
# lib/tasks/staff.rake

namespace :staff do
  desc "Add a staff member by email. Usage: rake staff:add[user@example.com] or rake staff:add[user@example.com,admin]"
  task :add, [:email, :role] => :environment do |_t, args|
    email = args[:email]
    role = args[:role] || "staff"

    abort "Usage: rake staff:add[email@example.com,role]" if email.blank?
    abort "Invalid role: #{role}. Valid roles: #{Staff.roles.keys.join(', ')}" unless Staff.roles.key?(role)

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" unless user

    if user.staff?
      puts "#{email} is already a staff member (role: #{user.staff_role})"
      if user.staff_role != role
        user.staff.update!(role: role)
        puts "Updated role to: #{role}"
      end
    else
      Staff.create!(user: user, role: role)
      puts "Added #{email} as staff (role: #{role})"
    end
  end

  desc "Remove a staff member by email. Usage: rake staff:remove[user@example.com]"
  task :remove, [:email] => :environment do |_t, args|
    email = args[:email]
    abort "Usage: rake staff:remove[email@example.com]" if email.blank?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" unless user
    abort "#{email} is not a staff member" unless user.staff?

    user.staff.destroy!
    puts "Removed #{email} from staff"
  end

  desc "List all staff members"
  task list: :environment do
    staffs = Staff.includes(:user).order(:role, :created_at)

    if staffs.empty?
      puts "No staff members found"
    else
      puts "Staff members:"
      puts "-" * 50
      staffs.each do |s|
        tg = s.telegram? ? " [TG: #{s.telegram_chat_id}]" : ""
        puts "  #{s.user.email_address} (#{s.role})#{tg} — since #{s.created_at.strftime('%Y-%m-%d')}"
      end
      puts "-" * 50
      puts "Total: #{staffs.count}"
    end
  end

  desc "Set Telegram chat ID for a staff member. Usage: rake staff:telegram[user@example.com,CHAT_ID]"
  task :telegram, [:email, :chat_id] => :environment do |_t, args|
    email = args[:email]
    chat_id = args[:chat_id]

    abort "Usage: rake staff:telegram[email@example.com,CHAT_ID]" if email.blank? || chat_id.blank?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" unless user
    abort "#{email} is not a staff member" unless user.staff?

    user.staff.update!(telegram_chat_id: chat_id)
    puts "Set Telegram chat ID for #{email}: #{chat_id}"
  end
end
```

### Usage

```bash
# Add staff member (default role: staff)
rake "staff:add[user@example.com]"

# Add with specific role
rake "staff:add[user@example.com,admin]"

# Remove staff member
rake "staff:remove[user@example.com]"

# List all staff
rake staff:list

# Set Telegram chat ID for notifications
rake "staff:telegram[user@example.com,123456789]"
```

---

## Pattern B: Staff Columns on User (Simpler)

For simpler apps, skip the separate table and add columns directly to users:

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_staff_to_users.rb
class AddStaffToUsers < ActiveRecord::Migration[x.x]
  def change
    add_column :users, :staff, :boolean, default: false, null: false
    add_column :users, :staff_role, :integer
  end
end
```

### Model

```ruby
# app/models/user.rb (add to existing)
enum :staff_role, { staff: 0, admin: 1, super_admin: 2 }

def staff?
  staff
end

def at_least_admin?
  admin? || super_admin?
end
```

### Staff Access Concern (Simpler)

```ruby
# app/controllers/concerns/staff_access.rb
module StaffAccess
  extend ActiveSupport::Concern

  included do
    before_action :require_staff_access
  end

  class_methods do
    def require_admin_access
      before_action :require_admin
    end

    def require_super_admin_access
      before_action :require_super_admin
    end
  end

  private

  def require_staff_access
    head :not_found unless Current.user&.staff?  # 404 hides panel existence
  end

  def require_admin
    head :not_found unless Current.user&.at_least_admin?
  end

  def require_super_admin
    head :not_found unless Current.user&.super_admin?
  end
end
```

---

## Backend Access Control (Pattern A)

### Staff Authentication Concern

```ruby
# app/controllers/concerns/staff_access.rb

module StaffAccess
  extend ActiveSupport::Concern

  included do
    before_action :require_staff
  end

  private

  def require_staff
    return head :not_found unless Current.user&.staff?
  end

  def require_admin
    return head :not_found unless Current.user&.staff&.at_least_admin?
  end

  def require_super_admin
    return head :not_found unless Current.user&.staff&.super_admin?
  end
end
```

### Staff Base Controller

```ruby
# app/controllers/staff/base_controller.rb

module Staff
  class BaseController < ApplicationController
    include StaffAccess

    inertia_share staff_nav: -> {
      {
        current_role: Current.user.staff_role,
        sections: staff_nav_sections
      }
    }

    private

    def staff_nav_sections
      sections = [
        { key: "dashboard", href: "/staff", icon: "LayoutDashboard" },
        { key: "users", href: "/staff/users", icon: "Users" },
        { key: "announcements", href: "/staff/announcements", icon: "Megaphone" },
        { key: "contact_requests", href: "/staff/contact_requests", icon: "Mail" },
      ]

      if Current.user.staff.at_least_admin?
        sections += [
          { key: "staff_members", href: "/staff/members", icon: "Shield" },
          { key: "settings", href: "/staff/settings", icon: "Settings" },
        ]
      end

      sections
    end
  end
end
```

### Example Staff Controller

See the [External Dashboard Links](#external-dashboard-links) section below for the full dashboard controller with stats and external links.

### Routes

```ruby
# config/routes.rb

namespace :staff do
  get "/", to: "dashboard#show"
  resources :users, param: :slug, only: [:index, :show] do
    member do
      patch :toggle_comp
      patch :toggle_suspend
      post :send_password_reset
      patch :verify_email
      get :payment_history
      get :export_data
    end
  end
  resources :announcements, param: :slug, except: [:show]
  resources :contact_requests, param: :slug, only: [:index, :show, :update]
  resources :members, only: [:index]  # Staff management (admin only)
end
```

---

## Comped Access

Staff can grant or revoke free paid access to individual users directly from the staff panel. This is backed by a `comped` boolean on the user — see [stripe-payments.md](stripe-payments.md#comped-gifted-access) for the migration and user model changes.

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb

module Staff
  class UsersController < BaseController
    def index
      # ... existing user listing
    end

    def show
      user = User.find_by_slug!(params[:slug])
      render inertia: "Staff/Users/Show", props: {
        user: serialize_user(user)
      }
    end

    def toggle_comp
      user = User.find_by_slug!(params[:slug])
      user.update!(comped: !user.comped?)

      redirect_back fallback_location: staff_user_path(user),
        notice: user.comped? ? I18n.t("staff.users.comped") : I18n.t("staff.users.uncomped")
    end

    private

    def serialize_user(user)
      {
        slug: user.slug,
        email: user.email_address,
        plan_name: user.plan_name,
        comped: user.comped?,
        suspended: user.suspended?,
        suspended_reason: user.suspended_reason,
        verified: user.verified?,
        created_at: user.created_at.iso8601
      }
    end
  end
end
```

### Frontend: Comp Toggle Button

Add a comp toggle to the staff user detail page:

```jsx
// In app/frontend/pages/staff/users/show.jsx

import { router, usePage } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

function CompToggle({ user }) {
  const { t } = useTranslation();
  const { routes } = usePage().props;

  const handleToggle = () => {
    router.patch(routes.staff_toggle_comp_user(user.slug), {}, {
      preserveScroll: true,
    });
  };

  return (
    <div className="flex items-center gap-3">
      {user.comped && (
        <Badge variant="secondary">{t("staff.users.comped_badge")}</Badge>
      )}
      <Button
        variant={user.comped ? "destructive" : "default"}
        size="sm"
        onClick={handleToggle}
      >
        {user.comped
          ? t("staff.users.revoke_comp")
          : t("staff.users.grant_comp")}
      </Button>
    </div>
  );
}
```

### i18n Keys

```yaml
# Add to app/frontend/locales/en/staff.yml
staff:
  users:
    comped: Comped access granted
    uncomped: Comped access revoked
    comped_badge: Comped
    grant_comp: Grant free access
    revoke_comp: Revoke free access
```

---

## Suspend / Unsuspend User

Soft-disable a user's account without deleting it. Suspended users are blocked at login and see a "suspended" message.

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_suspended_at_to_users.rb

class AddSuspendedAtToUsers < ActiveRecord::Migration[x.x]
  def change
    add_column :users, :suspended_at, :datetime
    add_column :users, :suspended_reason, :string
  end
end
```

### User Model

```ruby
# app/models/user.rb (add to existing model)

class << self
  def active
    where(suspended_at: nil)
  end
end

def suspended?
  suspended_at.present?
end

def suspend!(reason: nil)
  update!(suspended_at: Time.current, suspended_reason: reason)
end

def unsuspend!
  update!(suspended_at: nil, suspended_reason: nil)
end
```

### Block Login for Suspended Users

```ruby
# app/controllers/sessions_controller.rb (in the create action, after authentication)

if user.suspended?
  redirect_to new_session_path, alert: I18n.t("auth.account_suspended")
  return
end
```

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb (add to existing controller)

def toggle_suspend
  user = User.find_by_slug!(params[:slug])

  if user.suspended?
    user.unsuspend!
    notice = I18n.t("staff.users.unsuspended")
  else
    user.suspend!(reason: params[:reason])
    notice = I18n.t("staff.users.suspended")
  end

  redirect_back fallback_location: staff_user_path(user), notice: notice
end
```

---

## Reset User Password

Send a password reset email on behalf of a user from the staff panel.

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb (add to existing controller)

def send_password_reset
  user = User.find_by_slug!(params[:slug])
  PasswordMailer.reset(user).deliver_later

  redirect_back fallback_location: staff_user_path(user),
    notice: I18n.t("staff.users.password_reset_sent")
end
```

---

## Force Email Verification

Manually mark a user's email as verified — useful when email delivery fails or for test accounts.

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb (add to existing controller)

def verify_email
  user = User.find_by_slug!(params[:slug])
  user.update!(verified: true)

  redirect_back fallback_location: staff_user_path(user),
    notice: I18n.t("staff.users.email_verified")
end
```

> Adapt the column name (`verified`, `email_verified_at`, etc.) to match your auth setup. If using Rails 8 authentication generator, check the column name in your schema.

---

## User Activity Log

Track key user actions (login, password change, plan change, etc.) for support and audit purposes.

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_user_activities.rb

class CreateUserActivities < ActiveRecord::Migration[x.x]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false          # e.g. "login", "password_change", "plan_upgrade"
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, default: {}         # flexible data per action type
      t.datetime :created_at, null: false     # no updated_at needed — activities are immutable
    end

    add_index :user_activities, [:user_id, :created_at]
    add_index :user_activities, :action
  end
end
```

### Model

```ruby
# app/models/user_activity.rb

class UserActivity < ApplicationRecord
  belongs_to :user

  ACTIONS = %w[
    login
    logout
    password_change
    email_change
    plan_upgrade
    plan_downgrade
    account_suspended
    account_unsuspended
    comped
    uncomped
    data_export_requested
  ].freeze

  class << self
    def log(user:, action:, request: nil, metadata: {})
      create!(
        user: user,
        action: action,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent&.truncate(500),
        metadata: metadata
      )
    end
  end
end
```

### Recording Activities

Sprinkle `UserActivity.log` calls in the relevant places:

```ruby
# In SessionsController#create (after successful login)
UserActivity.log(user: user, action: "login", request: request)

# In PasswordsController#update
UserActivity.log(user: Current.user, action: "password_change", request: request)

# In Staff::UsersController#toggle_suspend
UserActivity.log(
  user: user,
  action: user.suspended? ? "account_suspended" : "account_unsuspended",
  request: request,
  metadata: { staff_id: Current.user.id }
)

# In Staff::UsersController#toggle_comp
UserActivity.log(
  user: user,
  action: user.comped? ? "comped" : "uncomped",
  request: request,
  metadata: { staff_id: Current.user.id }
)
```

### Staff View

```ruby
# app/controllers/staff/users_controller.rb (in show action, add to props)

def show
  user = User.find_by_slug!(params[:slug])
  activities = user.user_activities.order(created_at: :desc).limit(50)

  render inertia: "Staff/Users/Show", props: {
    user: serialize_user(user),
    activities: activities.map { |a|
      {
        id: a.id,
        action: a.action,
        ip_address: a.ip_address,
        metadata: a.metadata,
        created_at: a.created_at.iso8601
      }
    }
  }
end
```

---

## Announcements / Banners

Site-wide notices that appear as a banner at the top of the app. Staff can create, schedule, and dismiss them.

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_announcements.rb

class CreateAnnouncements < ActiveRecord::Migration[x.x]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body
      t.integer :style, null: false, default: 0  # info, warning, success, error
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean :dismissible, null: false, default: true
      t.boolean :active, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :announcements, [:active, :starts_at, :ends_at]
  end
end
```

### Model

```ruby
# app/models/announcement.rb

class Announcement < ApplicationRecord
  enum :style, { info: 0, warning: 1, success: 2, error: 3 }

  belongs_to :created_by, class_name: "User"

  class << self
    def current
      now = Time.current
      where(active: true)
        .where("starts_at <= ?", now)
        .where("ends_at IS NULL OR ends_at > ?", now)
        .order(created_at: :desc)
    end
  end
end
```

### Share with Frontend

```ruby
# In ApplicationController inertia_share block:

inertia_share announcements: -> {
  Announcement.current.map do |a|
    {
      slug: a.slug,
      title: a.title,
      body: a.body,
      style: a.style,
      dismissible: a.dismissible
    }
  end
}
```

### Staff Controller

```ruby
# app/controllers/staff/announcements_controller.rb

module Staff
  class AnnouncementsController < BaseController
    def index
      announcements = Announcement.order(created_at: :desc).limit(50)
      render inertia: "Staff/Announcements/Index", props: {
        announcements: announcements.map { |a| serialize_announcement(a) }
      }
    end

    def create
      announcement = Announcement.create!(
        **announcement_params,
        created_by: Current.user
      )
      redirect_to staff_announcements_path, notice: I18n.t("staff.announcements.created")
    end

    def update
      announcement = Announcement.find_by_slug!(params[:slug])
      announcement.update!(announcement_params)
      redirect_to staff_announcements_path, notice: I18n.t("staff.announcements.updated")
    end

    def destroy
      Announcement.find_by_slug!(params[:slug]).destroy!
      redirect_to staff_announcements_path, notice: I18n.t("staff.announcements.deleted")
    end

    private

    def announcement_params
      params.require(:announcement).permit(:title, :body, :style, :starts_at, :ends_at, :dismissible, :active)
    end

    def serialize_announcement(a)
      {
        slug: a.slug,
        title: a.title,
        body: a.body,
        style: a.style,
        starts_at: a.starts_at&.iso8601,
        ends_at: a.ends_at&.iso8601,
        dismissible: a.dismissible,
        active: a.active,
        created_at: a.created_at.iso8601
      }
    end
  end
end
```

### Frontend Banner Component

```jsx
// app/frontend/components/announcement-banner.jsx

import { usePage } from "@inertiajs/react";
import { useState } from "react";
import { IconX } from "@/components/icons/x";
import { cn } from "@/lib/utils";

const STYLE_CLASSES = {
  info: "bg-blue-50 text-blue-900 border-blue-200 dark:bg-blue-950 dark:text-blue-100 dark:border-blue-800",
  warning: "bg-yellow-50 text-yellow-900 border-yellow-200 dark:bg-yellow-950 dark:text-yellow-100 dark:border-yellow-800",
  success: "bg-green-50 text-green-900 border-green-200 dark:bg-green-950 dark:text-green-100 dark:border-green-800",
  error: "bg-red-50 text-red-900 border-red-200 dark:bg-red-950 dark:text-red-100 dark:border-red-800",
};

export default function AnnouncementBanner() {
  const { announcements } = usePage().props;
  const [dismissed, setDismissed] = useState(() => {
    const stored = localStorage.getItem("dismissed_announcements");
    return stored ? JSON.parse(stored) : [];
  });

  const visible = (announcements || []).filter((a) => !dismissed.includes(a.slug));
  if (visible.length === 0) return null;

  const dismiss = (slug) => {
    const updated = [...dismissed, slug];
    setDismissed(updated);
    localStorage.setItem("dismissed_announcements", JSON.stringify(updated));
  };

  return (
    <div className="space-y-0">
      {visible.map((a) => (
        <div
          key={a.slug}
          className={cn("border-b px-4 py-2 text-sm flex items-center justify-between", STYLE_CLASSES[a.style])}
        >
          <div>
            <strong>{a.title}</strong>
            {a.body && <span className="ml-2">{a.body}</span>}
          </div>
          {a.dismissible && (
            <button onClick={() => dismiss(a.slug)} className="ml-4 opacity-60 hover:opacity-100">
              <IconX className="h-4 w-4" />
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
```

Place `<AnnouncementBanner />` at the top of your app layout, above the main content.

---

## Payment History (Staff View)

View a user's Stripe invoices, charges, and refunds from the staff panel — with CSV export.

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb (add to existing controller)

def payment_history
  user = User.find_by_slug!(params[:slug])
  charges = user.pay_charges.order(created_at: :desc)

  respond_to do |format|
    format.html do
      render inertia: "Staff/Users/PaymentHistory", props: {
        user: { slug: user.slug, email: user.email_address },
        charges: charges.map { |c| serialize_charge(c) }
      }
    end
    format.csv do
      csv = generate_charges_csv(user, charges)
      send_data csv, filename: "payments_#{user.slug}_#{Date.current}.csv", type: "text/csv"
    end
  end
end

private

def serialize_charge(charge)
  {
    id: charge.id,
    amount: charge.amount,
    currency: charge.currency,
    created_at: charge.created_at.iso8601,
    processor_id: charge.processor_id,
    refunded: charge.amount_refunded.to_i > 0,
    amount_refunded: charge.amount_refunded
  }
end

def generate_charges_csv(user, charges)
  require "csv"

  CSV.generate(headers: true) do |csv|
    csv << ["Date", "Amount", "Currency", "Stripe ID", "Refunded", "Amount Refunded"]
    charges.each do |c|
      csv << [
        c.created_at.strftime("%Y-%m-%d %H:%M"),
        c.amount.to_f / 100,
        c.currency.upcase,
        c.processor_id,
        c.amount_refunded.to_i > 0 ? "Yes" : "No",
        c.amount_refunded.to_f / 100
      ]
    end
  end
end
```

---

## GDPR Data Export

Export all data for a user as a JSON file. Triggered by staff (or the user via settings).

### Interactor

```ruby
# app/interactors/users/export_data.rb

class Users::ExportData
  include Interactor

  delegate :user, to: :context

  def call
    context.data = {
      user: user_data,
      activities: activities_data,
      payments: payments_data,
      exported_at: Time.current.iso8601
    }
  end

  private

  def user_data
    {
      id: user.id,
      email: user.email_address,
      created_at: user.created_at.iso8601,
      updated_at: user.updated_at.iso8601
      # Add all user columns relevant to GDPR
    }
  end

  def activities_data
    user.user_activities.order(:created_at).map do |a|
      {
        action: a.action,
        ip_address: a.ip_address,
        created_at: a.created_at.iso8601,
        metadata: a.metadata
      }
    end
  end

  def payments_data
    user.pay_charges.order(:created_at).map do |c|
      {
        amount: c.amount,
        currency: c.currency,
        created_at: c.created_at.iso8601,
        processor_id: c.processor_id
      }
    end
  end
end
```

### Staff Controller Action

```ruby
# app/controllers/staff/users_controller.rb (add to existing controller)

def export_data
  user = User.find_by_slug!(params[:slug])
  result = Users::ExportData.call(user: user)

  UserActivity.log(
    user: user,
    action: "data_export_requested",
    request: request,
    metadata: { staff_id: Current.user.id }
  )

  send_data result.data.to_json,
    filename: "user_#{user.slug}_export_#{Date.current}.json",
    type: "application/json"
end
```

---

## Dashboard Tiles

The staff dashboard displays quick-access tiles (external service links, internal tools, etc.) that staff users can manage. Tiles are stored in the database and seeded with sensible defaults.

### Migration

```ruby
# db/migrate/XXXXXXXX_create_dashboard_tiles.rb

class CreateDashboardTiles < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboard_tiles do |t|
      t.string :title, null: false
      t.string :description
      t.string :url, null: false
      t.string :icon                    # Lucide icon name (e.g. "CreditCard", "Bug")
      t.string :emoji                   # Alternative to icon (e.g. "💳", "🐛")
      t.boolean :external, default: true, null: false  # Opens in new tab?
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.timestamps
    end

    add_index :dashboard_tiles, :position
    add_index :dashboard_tiles, :visible
  end
end
```

### Model

```ruby
# app/models/dashboard_tile.rb

class DashboardTile < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :title) }

  class << self
    def for_dashboard
      visible.ordered
    end
  end
end
```

### Seeds (Reference Data)

```yaml
# db/reference_data/dashboard_tiles.yml
# Default tiles — seeded on every deploy, staff can add more via UI

- key: stripe
  title: Stripe
  description: Payments, subscriptions, and invoices
  url: "{{STRIPE_DASHBOARD_URL}}"
  icon: CreditCard
  external: true
  position: 1

- key: sentry
  title: Sentry
  description: Error tracking and performance
  url: "{{SENTRY_PROJECT_URL}}"
  icon: Bug
  external: true
  position: 2

- key: analytics
  title: Google Analytics
  description: Traffic and user behavior
  url: "{{GA_PROPERTY_URL}}"
  icon: BarChart
  external: true
  position: 3

- key: search_console
  title: Search Console
  description: Search performance and indexing
  url: "{{SEARCH_CONSOLE_URL}}"
  icon: Search
  external: true
  position: 4

- key: solid_queue
  title: Solid Queue
  description: Background jobs and failed executions
  url: /staff/jobs
  icon: ListTodo
  external: false
  position: 5
```

```ruby
# db/seeds/03_dashboard_tiles.rb

require "yaml"

tiles_path = Rails.root.join("db/reference_data/dashboard_tiles.yml")
tiles = YAML.safe_load(tiles_path.read)

tiles.each do |tile_data|
  # Replace {{ENV_VAR}} placeholders with actual values
  url = tile_data["url"].gsub(/\{\{(\w+)\}\}/) { ENV.fetch(Regexp.last_match(1), "") }

  # Skip tiles with unresolved ENV vars (service not configured)
  next if url.blank? || url.include?("{{")

  DashboardTile.find_or_initialize_by(title: tile_data["title"]).tap do |tile|
    tile.assign_attributes(
      description: tile_data["description"],
      url: url,
      icon: tile_data["icon"],
      external: tile_data["external"],
      position: tile_data["position"],
      visible: true
    )
    tile.save!
  end
end
```

### Environment Variables

```bash
# .env (add to existing — tiles with missing URLs are skipped during seed)
STRIPE_DASHBOARD_URL=https://dashboard.stripe.com
SENTRY_PROJECT_URL=https://sentry.io/organizations/your-org/issues/?project=your-project-id
GA_PROPERTY_URL=https://analytics.google.com/analytics/web/#/p123456789/reports/dashboard
SEARCH_CONSOLE_URL=https://search.google.com/search-console?resource_id=sc-domain:yourdomain.com
```

### Staff Dashboard Controller

```ruby
# app/controllers/staff/dashboard_controller.rb

module Staff
  class DashboardController < BaseController
    def show
      render inertia: "Staff/Dashboard", props: {
        stats: {
          total_users: User.count,
          new_users_today: User.where("created_at >= ?", Time.current.beginning_of_day).count,
          active_subscriptions: Pay::Subscription.active.count,
          comped_users: User.where(comped: true).count,
          suspended_users: User.where.not(suspended_at: nil).count,
          failed_jobs: SolidQueue::FailedExecution.count
        },
        tiles: DashboardTile.for_dashboard.map { |tile|
          {
            id: tile.id,
            title: tile.title,
            description: tile.description,
            url: tile.url,
            icon: tile.icon,
            emoji: tile.emoji,
            external: tile.external
          }
        }
      }
    end
  end
end
```

### Frontend Dashboard with Links

```jsx
// In app/frontend/pages/staff/dashboard.jsx — add below the stats cards:

function DashboardTiles({ tiles }) {
  const { t } = useTranslation();

  if (!tiles || tiles.length === 0) return null;

  return (
    <div className="mt-8">
      <h2 className="text-lg font-semibold mb-4">{t("staff.dashboard.tiles")}</h2>
      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
        {tiles.map((tile) => (
          <a
            key={tile.id}
            href={tile.url}
            target={tile.external ? "_blank" : "_self"}
            rel="noopener noreferrer"
            className="flex items-center gap-3 p-4 rounded-lg border bg-card hover:bg-accent transition-colors"
          >
            {tile.emoji && (
              <span className="text-lg">{tile.emoji}</span>
            )}
            <div className="flex-1 min-w-0">
              <span className="text-sm font-medium">{tile.title}</span>
              {tile.description && (
                <p className="text-xs text-muted-foreground truncate">{tile.description}</p>
              )}
            </div>
            {tile.external && (
              <IconExternalLink className="h-3 w-3 flex-shrink-0 text-muted-foreground" />
            )}
          </a>
        ))}
      </div>
    </div>
  );
}
```

---

## External Services Registry

Track all third-party services the app integrates with. This gives staff visibility into what services are configured and provides useful dashboard links.

### Migration

```ruby
# db/migrate/XXXXXXXX_create_external_services.rb

class CreateExternalServices < ActiveRecord::Migration[8.0]
  def change
    create_table :external_services do |t|
      t.string :key, null: false               # Unique identifier (e.g., "stripe_live")
      t.string :name, null: false              # Display name (e.g., "Stripe (Live)")
      t.string :category, null: false          # payments, email, sms, auth, analytics, errors, ai, deployment
      t.string :environment, null: false       # development, production, all
      t.string :description
      t.string :dashboard_url                  # Link to service dashboard
      t.string :icon                           # Lucide icon name
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :external_services, :key, unique: true
    add_index :external_services, :category
    add_index :external_services, :environment
    add_index :external_services, :active
  end
end
```

### Model

```ruby
# app/models/external_service.rb

class ExternalService < ApplicationRecord
  ENVIRONMENTS = %w[development production all].freeze
  CATEGORIES = %w[payments email sms auth analytics errors ai deployment notifications].freeze

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :environment, presence: true, inclusion: { in: ENVIRONMENTS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:category, :position, :name) }
  scope :for_environment, ->(env) { where(environment: [env, "all"]) }
  scope :by_category, ->(cat) { where(category: cat) }

  class << self
    def for_dashboard(environment: Rails.env)
      env = environment.to_s == "production" ? "production" : "development"
      active.for_environment(env).ordered
    end

    def grouped_for_dashboard(environment: Rails.env)
      for_dashboard(environment: environment).group_by(&:category)
    end
  end
end
```

### Seeds (Reference Data)

```yaml
# db/reference_data/external_services.yml
# Comprehensive list of all third-party services for the stack
# Run: bin/rails reference_data:seed

# ─────────────────────────────────────────────────────────────
# PAYMENTS
# ─────────────────────────────────────────────────────────────
- key: stripe_sandbox
  name: Stripe (Sandbox)
  category: payments
  environment: development
  description: Test payments, subscriptions, and invoices
  dashboard_url: https://dashboard.stripe.com/test
  icon: CreditCard
  position: 1

- key: stripe_live
  name: Stripe (Live)
  category: payments
  environment: production
  description: Live payments, subscriptions, and invoices
  dashboard_url: https://dashboard.stripe.com
  icon: CreditCard
  position: 2

# ─────────────────────────────────────────────────────────────
# EMAIL
# ─────────────────────────────────────────────────────────────
- key: letter_opener
  name: Letter Opener
  category: email
  environment: development
  description: Preview sent emails in the browser
  dashboard_url: /letter_opener
  icon: Mail
  position: 1

- key: brevo_smtp
  name: Brevo SMTP
  category: email
  environment: production
  description: Transactional email delivery
  dashboard_url: https://app.brevo.com/settings/smtp
  icon: Send
  position: 2

# ─────────────────────────────────────────────────────────────
# SMS
# ─────────────────────────────────────────────────────────────
- key: sms_console
  name: Console (SMS)
  category: sms
  environment: development
  description: SMS logged to Rails console
  dashboard_url:
  icon: Terminal
  position: 1

- key: brevo_sms
  name: Brevo SMS
  category: sms
  environment: production
  description: Transactional SMS delivery
  dashboard_url: https://app.brevo.com/sms
  icon: MessageSquare
  position: 2

# ─────────────────────────────────────────────────────────────
# AUTHENTICATION
# ─────────────────────────────────────────────────────────────
- key: google_oauth_dev
  name: Google OAuth (Dev)
  category: auth
  environment: development
  description: Google sign-in (test credentials)
  dashboard_url: https://console.cloud.google.com/apis/credentials
  icon: Key
  position: 1

- key: google_oauth_prod
  name: Google OAuth (Prod)
  category: auth
  environment: production
  description: Google sign-in (production)
  dashboard_url: https://console.cloud.google.com/apis/credentials
  icon: Key
  position: 2

# ─────────────────────────────────────────────────────────────
# ANALYTICS & SEO
# ─────────────────────────────────────────────────────────────
- key: google_analytics
  name: Google Analytics
  category: analytics
  environment: production
  description: Traffic and user behavior analytics
  dashboard_url: https://analytics.google.com
  icon: BarChart
  position: 1

- key: google_search_console
  name: Google Search Console
  category: analytics
  environment: production
  description: Search performance and indexing
  dashboard_url: https://search.google.com/search-console
  icon: Search
  position: 2

- key: ahrefs
  name: Ahrefs
  category: analytics
  environment: production
  description: SEO analysis and backlink monitoring
  dashboard_url: https://ahrefs.com/site-explorer
  icon: Link
  position: 3

# ─────────────────────────────────────────────────────────────
# ERROR TRACKING
# ─────────────────────────────────────────────────────────────
- key: sentry
  name: Sentry
  category: errors
  environment: production
  description: Error tracking and performance monitoring
  dashboard_url: https://sentry.io
  icon: Bug
  position: 1

# ─────────────────────────────────────────────────────────────
# AI / LLM
# ─────────────────────────────────────────────────────────────
- key: openai
  name: OpenAI
  category: ai
  environment: all
  description: GPT models via ruby_llm gem
  dashboard_url: https://platform.openai.com/usage
  icon: Sparkles
  position: 1

- key: anthropic
  name: Anthropic
  category: ai
  environment: all
  description: Claude models via ruby_llm gem
  dashboard_url: https://console.anthropic.com
  icon: Sparkles
  position: 2

# ─────────────────────────────────────────────────────────────
# DEPLOYMENT
# ─────────────────────────────────────────────────────────────
- key: docker_hub
  name: Docker Hub
  category: deployment
  environment: production
  description: Container registry for Kamal deployments
  dashboard_url: https://hub.docker.com
  icon: Container
  position: 1

- key: github_actions
  name: GitHub Actions
  category: deployment
  environment: production
  description: CI/CD pipeline
  dashboard_url: "{{GITHUB_REPO_URL}}/actions"
  icon: GitBranch
  position: 2

# ─────────────────────────────────────────────────────────────
# NOTIFICATIONS (STAFF ALERTS)
# ─────────────────────────────────────────────────────────────
- key: telegram
  name: Telegram
  category: notifications
  environment: production
  description: Staff alert notifications via bot
  dashboard_url: https://t.me/BotFather
  icon: Send
  position: 1
```

### Seeder

```ruby
# app/services/seeding/seed_external_services.rb

module Seeding
  class SeedExternalServices
    YAML_PATH = Rails.root.join("db/reference_data/external_services.yml")

    def self.call
      new.call
    end

    def call
      return unless YAML_PATH.exist?

      services = YAML.safe_load(YAML_PATH.read, permitted_classes: [], aliases: true)

      services.each_with_index do |data, index|
        # Expand {{ENV_VAR}} placeholders
        dashboard_url = data["dashboard_url"]&.gsub(/\{\{(\w+)\}\}/) do
          ENV.fetch(Regexp.last_match(1), "")
        end

        # Skip if URL has unresolved placeholders
        dashboard_url = nil if dashboard_url&.include?("{{")

        ExternalService.find_or_initialize_by(key: data["key"]).tap do |service|
          service.assign_attributes(
            name: data["name"],
            category: data["category"],
            environment: data["environment"],
            description: data["description"],
            dashboard_url: dashboard_url.presence,
            icon: data["icon"],
            position: data["position"] || index,
            active: true
          )
          service.save!
        end
      end

      Rails.logger.info "[Seed] External services: #{ExternalService.count} total"
    end
  end
end
```

### Add to Reference Data Seed

```ruby
# db/seeds/reference_data.rb (add to existing)

Seeding::SeedExternalServices.call
```

### Staff Dashboard Integration

Update the dashboard controller to include external services:

```ruby
# app/controllers/staff/dashboard_controller.rb

def show
  render inertia: "Staff/Dashboard", props: {
    stats: { ... },
    tiles: DashboardTile.for_dashboard.map { ... },
    external_services: ExternalService.grouped_for_dashboard.transform_values do |services|
      services.map do |s|
        {
          key: s.key,
          name: s.name,
          description: s.description,
          dashboard_url: s.dashboard_url,
          icon: s.icon,
          environment: s.environment
        }
      end
    end
  }
end
```

### Frontend Component

```jsx
// app/frontend/components/staff/external-services-panel.jsx

import { useTranslation } from "react-i18next";
import { Badge } from "@/components/ui/badge";
import { IconExternalLink } from "@/components/icons/external-link";

const CATEGORY_LABELS = {
  payments: "Payments",
  email: "Email",
  sms: "SMS",
  auth: "Authentication",
  analytics: "Analytics & SEO",
  errors: "Error Tracking",
  ai: "AI / LLM",
  deployment: "Deployment",
  notifications: "Notifications",
};

export function ExternalServicesPanel({ services }) {
  if (!services || Object.keys(services).length === 0) return null;

  return (
    <div className="space-y-6">
      {Object.entries(services).map(([category, items]) => (
        <div key={category}>
          <h3 className="text-sm font-medium text-muted-foreground mb-2">
            {CATEGORY_LABELS[category] || category}
          </h3>
          <div className="grid gap-2 md:grid-cols-2">
            {items.map((service) => (
              <ServiceCard key={service.key} service={service} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function ServiceCard({ service }) {
  const content = (
    <div className="flex items-center gap-3 p-3 rounded-lg border bg-card hover:bg-accent transition-colors">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{service.name}</span>
          <Badge variant="outline" className="text-[10px]">
            {service.environment === "all" ? "dev + prod" : service.environment.slice(0, 3)}
          </Badge>
        </div>
        {service.description && (
          <p className="text-xs text-muted-foreground truncate">{service.description}</p>
        )}
      </div>
      {service.dashboard_url && (
        <IconExternalLink className="h-3 w-3 flex-shrink-0 text-muted-foreground" />
      )}
    </div>
  );

  if (service.dashboard_url) {
    const isExternal = service.dashboard_url.startsWith("http");
    return (
      <a
        href={service.dashboard_url}
        target={isExternal ? "_blank" : "_self"}
        rel="noopener noreferrer"
      >
        {content}
      </a>
    );
  }

  return content;
}
```

### Environment-Specific Display

Show different services based on current environment:

```ruby
# In development.rb
Rails.application.config.external_services_environment = :development

# In production.rb
Rails.application.config.external_services_environment = :production
```

```ruby
# In controller
ExternalService.for_dashboard(
  environment: Rails.configuration.external_services_environment
)
```

---

## Frontend

### Directory Structure

```
app/frontend/pages/staff/
├── dashboard.jsx
├── users/
│   ├── index.jsx
│   ├── show.jsx
│   └── payment-history.jsx
├── announcements/
│   └── index.jsx
├── contact-requests/
│   ├── index.jsx
│   └── show.jsx
└── members/
    └── index.jsx

app/frontend/components/
└── announcement-banner.jsx

app/frontend/layout/
└── staff-layout.jsx
```

### Staff Layout with Sidenav

```jsx
// app/frontend/layout/staff-layout.jsx

import { Link, usePage } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { IconLayoutDashboard } from "@/components/icons/layout-dashboard";
import { IconUsers } from "@/components/icons/users";
import { IconMail } from "@/components/icons/mail";
import { IconShield } from "@/components/icons/shield";
import { IconSettings } from "@/components/icons/settings";
import { IconArrowLeft } from "@/components/icons/arrow-left";
import { cn } from "@/lib/utils";

const ICON_MAP = {
  LayoutDashboard: IconLayoutDashboard,
  Users: IconUsers,
  Megaphone: IconMegaphone,
  Mail: IconMail,
  Shield: IconShield,
  Settings: IconSettings,
};

export default function StaffLayout({ children }) {
  const { staff_nav, routes } = usePage().props;
  const { t } = useTranslation();
  const currentPath = window.location.pathname;

  return (
    <div className="min-h-screen flex">
      {/* Sidenav */}
      <aside className="w-64 border-r bg-muted/30 flex flex-col">
        <div className="p-4 border-b">
          <Link
            href={routes.app || "/"}
            className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            <IconArrowLeft className="h-4 w-4" />
            {t("staff.back_to_app")}
          </Link>
          <h2 className="mt-3 font-semibold text-lg">{t("staff.title")}</h2>
          <p className="text-xs text-muted-foreground capitalize">
            {staff_nav.current_role}
          </p>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          {staff_nav.sections.map((section) => {
            const Icon = ICON_MAP[section.icon];
            const isActive = currentPath === section.href;

            return (
              <Link
                key={section.key}
                href={section.href}
                className={cn(
                  "flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors",
                  isActive
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:text-foreground hover:bg-muted"
                )}
              >
                {Icon && <Icon className="h-4 w-4" />}
                {t(`staff.nav.${section.key}`)}
              </Link>
            );
          })}
        </nav>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-8">{children}</div>
      </main>
    </div>
  );
}
```

### Staff Dashboard Page

```jsx
// app/frontend/pages/staff/dashboard.jsx

import StaffLayout from "@/layout/staff-layout";
import { useTranslation } from "react-i18next";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { IconUsers } from "@/components/icons/users";
import { IconUserPlus } from "@/components/icons/user-plus";
import { IconCreditCard } from "@/components/icons/credit-card";
import { IconGift } from "@/components/icons/gift";
import { IconBan } from "@/components/icons/ban";
import { IconAlertTriangle } from "@/components/icons/alert-triangle";
import { IconExternalLink } from "@/components/icons/external-link";

const STAT_ICONS = {
  total_users: IconUsers,
  new_users_today: IconUserPlus,
  active_subscriptions: IconCreditCard,
  comped_users: IconGift,
  suspended_users: IconBan,
  failed_jobs: IconAlertTriangle,
};

export default function StaffDashboard({ stats, tiles }) {
  const { t } = useTranslation();

  return (
    <StaffLayout>
      <h1 className="text-2xl font-bold mb-6">{t("staff.dashboard.title")}</h1>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {Object.entries(stats).map(([key, value]) => {
          const Icon = STAT_ICONS[key];
          return (
            <Card key={key}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium">
                  {t(`staff.dashboard.${key}`)}
                </CardTitle>
                {Icon && <Icon className="h-4 w-4 text-muted-foreground" />}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{value}</div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {tiles && tiles.length > 0 && (
        <div className="mt-8">
          <h2 className="text-lg font-semibold mb-4">
            {t("staff.dashboard.tiles")}
          </h2>
          <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
            {tiles.map((tile) => (
              <a
                key={tile.id}
                href={tile.url}
                target={tile.external ? "_blank" : "_self"}
                rel="noopener noreferrer"
                className="flex items-center gap-3 p-4 rounded-lg border bg-card hover:bg-accent transition-colors"
              >
                {tile.emoji && (
                  <span className="text-lg">{tile.emoji}</span>
                )}
                <div className="flex-1 min-w-0">
                  <span className="text-sm font-medium">{tile.title}</span>
                  {tile.description && (
                    <p className="text-xs text-muted-foreground truncate">{tile.description}</p>
                  )}
                </div>
                {tile.external && (
                  <IconExternalLink className="h-3 w-3 flex-shrink-0 text-muted-foreground" />
                )}
              </a>
            ))}
          </div>
        </div>
      )}
    </StaffLayout>
  );
}
```

---

## i18n Keys

### Backend

```yaml
# config/locales/controllers/en.yml (add to existing)
en:
  staff:
    access_denied: "Access denied"
```

### Frontend

```yaml
# app/frontend/locales/en/staff.yml
staff:
  title: Staff Panel
  back_to_app: Back to app
  nav:
    dashboard: Dashboard
    users: Users
    announcements: Announcements
    contact_requests: Contact Requests
    staff_members: Staff Members
    settings: Settings
  dashboard:
    title: Dashboard
    total_users: Total Users
    new_today: New Today
    active_subscriptions: Active Subscriptions
    comped_users: Comped Users
    suspended_users: Suspended Users
    failed_jobs: Failed Jobs
    external_links: External Dashboards
    tiles: Dashboard Tiles
  users:
    title: Users
    search_placeholder: Search users...
    suspended: User suspended
    unsuspended: User unsuspended
    suspend: Suspend user
    unsuspend: Unsuspend user
    suspended_badge: Suspended
    password_reset_sent: Password reset email sent
    send_password_reset: Send password reset
    email_verified: Email marked as verified
    verify_email: Verify email
    payment_history: Payment History
    export_data: Export user data
    export_payments_csv: Export CSV
    activity_log: Activity Log
  announcements:
    title: Announcements
    create: Create Announcement
    created: Announcement created
    updated: Announcement updated
    deleted: Announcement deleted
    style_info: Info
    style_warning: Warning
    style_success: Success
    style_error: Error
  members:
    title: Staff Members
```

---

## Inertia Shared Routes

Add staff routes to the shared routes in `ApplicationController`:

```ruby
# In inertia_share routes block, add:
staff: Current.user&.staff? ? "/staff" : nil,
```

---

## Testing

### Factory

```ruby
# spec/support/factories/staffs.rb

FactoryBot.define do
  factory :staff do
    user
    role { "staff" }

    trait :admin do
      role { "admin" }
    end

    trait :super_admin do
      role { "super_admin" }
    end

    trait :with_telegram do
      telegram_chat_id { "123456789" }
    end
  end
end
```

### Request Specs

```ruby
# spec/requests/staff/dashboard_spec.rb

RSpec.describe "Staff Dashboard", type: :request do
  describe "GET /staff" do
    context "when user is staff" do
      let(:user) { create(:user) }
      let!(:staff) { create(:staff, user: user) }

      before { sign_in(user) }

      it "renders the dashboard" do
        get "/staff"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not staff" do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it "returns 404" do
        get "/staff"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get "/staff"
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
```

### Rake Task Specs

```ruby
# spec/tasks/staff_spec.rb

RSpec.describe "staff:add" do
  include_context "rake"

  let!(:user) { create(:user, email_address: "admin@example.com") }

  it "adds a user as staff" do
    expect {
      Rake::Task["staff:add"].invoke("admin@example.com")
    }.to change(Staff, :count).by(1)

    expect(user.reload.staff).to be_present
    expect(user.staff.role).to eq("staff")
  end

  it "accepts a role argument" do
    Rake::Task["staff:add"].invoke("admin@example.com", "admin")
    expect(user.reload.staff.role).to eq("admin")
  end
end
```

---

## Security Notes

1. **Staff routes return 404 (not 403)** — don't reveal the panel exists to non-staff users.
2. **Staff access is checked via `staffs` table** — not a column on users. This keeps the domain model clean.
3. **Staff members are managed via rake tasks** — no self-service promotion. Only someone with server access can grant staff roles.
4. **Use `require_admin` for sensitive operations** — basic staff can view data, admins can modify it.
5. **Log all staff actions on users** — every comp toggle, suspend, password reset, email verification, and data export is recorded in `user_activities` with the `staff_id` in metadata.
6. **GDPR data exports include staff activity** — so the user can see what actions were taken on their account.
