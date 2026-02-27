# Staff Admin Panel

> Internal staff/admin panel setup: database table, access control, rake task, and frontend scaffold.

---

## Overview

Every app needs an internal staff panel for admin operations. Staff members are regular users with an entry in the `staffs` table that grants them elevated access. This is separate from any user-facing roles in the domain model.

---

## Database

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_staffs.rb

class CreateStaffs < ActiveRecord::Migration[x.x]
  def change
    create_table :staffs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :role, null: false, default: "staff"
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
  ROLES = %w[staff admin super_admin].freeze

  belongs_to :user

  class << self
    def roles
      ROLES
    end

    def with_telegram
      where.not(telegram_chat_id: [nil, ""])
    end
  end

  def admin?
    role.in?(%w[admin super_admin])
  end

  def super_admin?
    role == "super_admin"
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
    abort "Invalid role: #{role}. Valid roles: #{Staff::ROLES.join(', ')}" unless role.in?(Staff::ROLES)

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

## Backend Access Control

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
    return head :not_found unless Current.user&.staff&.admin?
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
        { key: "contact_requests", href: "/staff/contact_requests", icon: "Mail" },
      ]

      if Current.user.staff.admin?
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

```ruby
# app/controllers/staff/dashboard_controller.rb

module Staff
  class DashboardController < BaseController
    def show
      render inertia: "Staff/Dashboard", props: {
        stats: {
          total_users: User.count,
          new_users_today: User.where("created_at >= ?", Time.current.beginning_of_day).count,
          # Add more stats as needed
        }
      }
    end
  end
end
```

### Routes

```ruby
# config/routes.rb

namespace :staff do
  get "/", to: "dashboard#show"
  resources :users, only: [:index, :show]
  resources :contact_requests, only: [:index, :show, :update]
  resources :members, only: [:index]  # Staff management (admin only)
end
```

---

## Frontend

### Directory Structure

```
app/frontend/pages/Staff/
├── Dashboard.jsx
├── Users/
│   ├── Index.jsx
│   └── Show.jsx
├── ContactRequests/
│   ├── Index.jsx
│   └── Show.jsx
└── Members/
    └── Index.jsx

app/frontend/layout/
└── StaffLayout.jsx
```

### Staff Layout with Sidenav

```jsx
// app/frontend/layout/StaffLayout.jsx

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
// app/frontend/pages/Staff/Dashboard.jsx

import StaffLayout from "@/layout/StaffLayout";
import { useTranslation } from "react-i18next";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { IconUsers } from "@/components/icons/users";
import { IconUserPlus } from "@/components/icons/user-plus";

export default function StaffDashboard({ stats }) {
  const { t } = useTranslation();

  return (
    <StaffLayout>
      <h1 className="text-2xl font-bold mb-6">{t("staff.dashboard.title")}</h1>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">
              {t("staff.dashboard.total_users")}
            </CardTitle>
            <IconUsers className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total_users}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">
              {t("staff.dashboard.new_today")}
            </CardTitle>
            <IconUserPlus className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.new_users_today}</div>
          </CardContent>
        </Card>
      </div>
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
    contact_requests: Contact Requests
    staff_members: Staff Members
    settings: Settings
  dashboard:
    title: Dashboard
    total_users: Total Users
    new_today: New Today
  users:
    title: Users
    search_placeholder: Search users...
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
# spec/factories/staffs.rb

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
