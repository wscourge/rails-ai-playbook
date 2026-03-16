# Contact Page

> Contact form that stores messages in the database and surfaces them in the staff panel.

---

## Overview

Contact form submissions are stored in a `contact_requests` table — not emailed. Staff view and manage them from the staff panel. An optional email notification can be sent when a new request arrives.

---

## Database

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_contact_requests.rb

class CreateContactRequests < ActiveRecord::Migration[x.x]
  def change
    create_table :contact_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.integer :status, null: false, default: 0
      t.text :staff_notes
      t.references :user, foreign_key: true  # nullable — guest submissions
      t.references :resolved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :contact_requests, :status
    add_index :contact_requests, :created_at
  end
end
```

### Model

```ruby
# app/models/contact_request.rb

class ContactRequest < ApplicationRecord
  enum :status, { new_request: 0, in_progress: 1, resolved: 2, archived: 3 }

  belongs_to :user, optional: true            # submitter (if logged in)
  belongs_to :resolved_by, class_name: "User", optional: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :unresolved, -> { where(status: [:new_request, :in_progress]) }
  scope :by_status, ->(status) { status.present? ? where(status: status) : all }
end
```

---

## Interactors

### Validate Contact Request

```ruby
# app/interactors/contact_requests/validate.rb

module ContactRequests
  class Validate
    include Interactor

    def call
      if context.name.blank?
        context.fail!(error: I18n.t("contact.errors.name_required"))
      end

      unless context.email.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
        context.fail!(error: I18n.t("contact.errors.email_invalid"))
      end

      if context.message.blank? || context.message.length < 10
        context.fail!(error: I18n.t("contact.errors.message_too_short"))
      end

      if context.message.length > 5000
        context.fail!(error: I18n.t("contact.errors.message_too_long"))
      end
    end
  end
end
```

### Create Contact Request

```ruby
# app/interactors/contact_requests/create.rb

module ContactRequests
  class Create
    include Interactor::Organizer

    organize ContactRequests::Validate,
             ContactRequests::Persist,
             ContactRequests::NotifyStaff
  end
end
```

```ruby
# app/interactors/contact_requests/persist.rb

module ContactRequests
  class Persist
    include Interactor

    def call
      context.contact_request = ContactRequest.create!(
        name: context.name.strip,
        email: context.email.strip.downcase,
        message: context.message.strip,
        user: context.current_user  # nil for guests
      )
    end
  end
end
```

```ruby
# app/interactors/contact_requests/notify_staff.rb

module ContactRequests
  class NotifyStaff
    include Interactor

    def call
      request = context.contact_request

      # Optional: email notification to staff
      # ContactMailer.new_request(request).deliver_later

      # Telegram notifications — send to all staff with a telegram_chat_id
      if ENV["TELEGRAM_API_KEY"].present?
        Staff.with_telegram.find_each do |staff|
          TelegramNotifier.send_message(
            chat_id: staff.telegram_chat_id,
            text: telegram_message(request)
          )
        end
      end
    end

    private

    def telegram_message(request)
      <<~MSG.strip
        📩 New contact request
        From: #{request.name} (#{request.email})
        Message: #{request.message.truncate(500)}
      MSG
    end
  end
end
```

### TelegramNotifier

```ruby
# app/services/telegram_notifier.rb

class TelegramNotifier
  BASE_URL = "https://api.telegram.org"

  class << self
    def send_message(chat_id:, text:, parse_mode: nil)
      return unless api_key.present?

      uri = URI("#{BASE_URL}/bot#{api_key}/sendMessage")
      body = { chat_id: chat_id, text: text }
      body[:parse_mode] = parse_mode if parse_mode

      response = Net::HTTP.post_form(uri, body)

      unless response.is_a?(Net::HTTPSuccess)
        Logs.error("TelegramNotifier", "Failed to send message: #{response.body}")
      end

      response
    rescue StandardError => e
      Logs.error("TelegramNotifier", e)
      nil
    end

    private

    def api_key
      ENV["TELEGRAM_API_KEY"]
    end
  end
end
```

### Resolve Contact Request (Staff)

```ruby
# app/interactors/contact_requests/resolve.rb

module ContactRequests
  class Resolve
    include Interactor

    def call
      request = context.contact_request
      request.update!(
        status: context.status,
        staff_notes: context.staff_notes,
        resolved_by: context.staff_user
      )
    end
  end
end
```

---

## Controller (Public)

```ruby
# app/controllers/contact_controller.rb

class ContactController < ApplicationController
  allow_unauthenticated_access

  def new
    render inertia: "Contact/New"
  end

  def create
    # Honeypot check
    return head :ok if params[:website].present?

    result = ContactRequests::Create.call(
      name: params[:name],
      email: params[:email],
      message: params[:message],
      current_user: Current.user
    )

    if result.success?
      redirect_to root_path, notice: I18n.t("contact.success")
    else
      redirect_back fallback_location: contact_new_path,
                    alert: result.error
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
resources :contact, only: [:new, :create]
```

---

## Frontend Validation (Zod)

```js
// app/frontend/lib/validators/contactSchema.js

import { z } from "zod";

export const contactSchema = z.object({
  name: z.string().min(1, "contact.errors.name_required"),
  email: z.string().email("contact.errors.email_invalid"),
  message: z
    .string()
    .min(10, "contact.errors.message_too_short")
    .max(5000, "contact.errors.message_too_long"),
});
```

### Jest Test

```js
// app/frontend/lib/validators/__tests__/contactSchema.test.js

import { contactSchema } from "../contactSchema";

describe("contactSchema", () => {
  it("validates a valid submission", () => {
    const result = contactSchema.safeParse({
      name: "Jane Doe",
      email: "jane@example.com",
      message: "Hello, I have a question about your product.",
    });
    expect(result.success).toBe(true);
  });

  it("rejects empty name", () => {
    const result = contactSchema.safeParse({
      name: "",
      email: "jane@example.com",
      message: "Hello, I have a question.",
    });
    expect(result.success).toBe(false);
  });

  it("rejects short messages", () => {
    const result = contactSchema.safeParse({
      name: "Jane",
      email: "jane@example.com",
      message: "Hi",
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid email", () => {
    const result = contactSchema.safeParse({
      name: "Jane",
      email: "not-an-email",
      message: "Hello, I have a question about your product.",
    });
    expect(result.success).toBe(false);
  });
});
```

---

## React Page (Public)

```jsx
// app/frontend/pages/contact/new.jsx

import { Head, useForm, usePage } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { contactSchema } from "@/lib/validators/contactSchema";
import { useState } from "react";

export default function ContactNew() {
  const { t } = useTranslation();
  const { auth } = usePage().props;
  const [validationErrors, setValidationErrors] = useState({});

  const { data, setData, post, processing } = useForm({
    name: auth?.user?.full_name || "",
    email: auth?.user?.email || "",
    message: "",
    website: "", // honeypot
  });

  const handleSubmit = (e) => {
    e.preventDefault();

    const result = contactSchema.safeParse(data);
    if (!result.success) {
      const errors = {};
      result.error.issues.forEach((issue) => {
        errors[issue.path[0]] = t(issue.message);
      });
      setValidationErrors(errors);
      return;
    }

    setValidationErrors({});
    post("/contact");
  };

  return (
    <>
      <Head title={t("contact.title")} />

      <div className="max-w-lg mx-auto py-8 sm:py-12 px-4">
        <h1 className="text-xl sm:text-2xl font-bold mb-2">
          {t("contact.title")}
        </h1>
        <p className="text-muted-foreground mb-6">
          {t("contact.subtitle")}
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Honeypot — hidden from humans, bots fill it */}
          <input
            type="text"
            name="website"
            value={data.website}
            onChange={(e) => setData("website", e.target.value)}
            className="hidden"
            tabIndex={-1}
            autoComplete="off"
          />

          <div>
            <Label htmlFor="name">{t("contact.fields.name")}</Label>
            <Input
              id="name"
              value={data.name}
              onChange={(e) => setData("name", e.target.value)}
            />
            {validationErrors.name && (
              <p className="text-sm text-destructive mt-1">{validationErrors.name}</p>
            )}
          </div>

          <div>
            <Label htmlFor="email">{t("contact.fields.email")}</Label>
            <Input
              id="email"
              type="email"
              value={data.email}
              onChange={(e) => setData("email", e.target.value)}
            />
            {validationErrors.email && (
              <p className="text-sm text-destructive mt-1">{validationErrors.email}</p>
            )}
          </div>

          <div>
            <Label htmlFor="message">{t("contact.fields.message")}</Label>
            <Textarea
              id="message"
              rows={5}
              value={data.message}
              onChange={(e) => setData("message", e.target.value)}
            />
            {validationErrors.message && (
              <p className="text-sm text-destructive mt-1">{validationErrors.message}</p>
            )}
          </div>

          <Button type="submit" disabled={processing} className="w-full sm:w-auto">
            {t("contact.submit")}
          </Button>
        </form>
      </div>
    </>
  );
}
```

---

## Staff Panel: Contact Requests

### Staff Controller

```ruby
# app/controllers/staff/contact_requests_controller.rb

module Staff
  class ContactRequestsController < BaseController
    def index
      requests = ContactRequest
        .by_status(params[:status])
        .newest_first
        .page(params[:page])  # if using pagination (e.g., Pagy)

      render inertia: "Staff/ContactRequests/Index", props: {
        contact_requests: requests.map { |r|
          {
            id: r.id,
            name: r.name,
            email: r.email,
            message: r.message.truncate(200),
            status: r.status,
            staff_notes: r.staff_notes,
            formatted_date: r.created_at.strftime("%b %-d, %Y"),
            resolved_by: r.resolved_by&.full_name,
          }
        },
        filters: { status: params[:status] },
        counts: {
          all: ContactRequest.count,
          new_request: ContactRequest.new_request.count,
          in_progress: ContactRequest.in_progress.count,
          resolved: ContactRequest.resolved.count,
        },
      }
    end

    def show
      request = ContactRequest.find_by_slug!(params[:slug])

      render inertia: "Staff/ContactRequests/Show", props: {
        contact_request: {
          slug: request.slug,
          name: request.name,
          email: request.email,
          message: request.message,
          status: request.status,
          staff_notes: request.staff_notes,
          user_id: request.user_id,
          formatted_date: request.created_at.strftime("%b %-d, %Y %l:%M %p"),
          resolved_by: request.resolved_by&.full_name,
          resolved_at: request.updated_at.iso8601,
        },
      }
    end

    def update
      request = ContactRequest.find_by_slug!(params[:slug])

      result = ContactRequests::Resolve.call(
        contact_request: request,
        status: params[:status],
        staff_notes: params[:staff_notes],
        staff_user: Current.user
      )

      if result.success?
        redirect_to staff_contact_request_path(request),
                    notice: I18n.t("staff.contact_requests.updated")
      else
        redirect_back fallback_location: staff_contact_requests_path,
                      alert: result.error
      end
    end
  end
end
```

### Staff Routes

```ruby
# config/routes.rb (inside the staff namespace)

namespace :staff do
  get "/", to: "dashboard#show"
  resources :users, only: [:index, :show]
  resources :members, only: [:index]
  resources :contact_requests, only: [:index, :show, :update]
end
```

### Staff Frontend: Contact Requests List

```jsx
// app/frontend/pages/staff/contact-requests/index.jsx

import StaffLayout from "@/layout/staff-layout";
import { Link } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table, TableBody, TableCell, TableHead,
  TableHeader, TableRow,
} from "@/components/ui/table";

const STATUS_VARIANT = {
  new: "default",
  in_progress: "secondary",
  resolved: "outline",
  archived: "outline",
};

export default function ContactRequestsIndex({ contact_requests, filters, counts }) {
  const { t } = useTranslation();

  return (
    <StaffLayout>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h1 className="text-2xl font-bold">
          {t("staff.contact_requests.title")}
        </h1>
      </div>

      {/* Status filter tabs */}
      <div className="flex gap-2 mb-4 flex-wrap">
        {["all", "new", "in_progress", "resolved"].map((status) => (
          <Link
            key={status}
            href={status === "all" ? "/staff/contact_requests" : `/staff/contact_requests?status=${status}`}
            className={`px-3 py-1 rounded-md text-sm transition-colors ${
              (filters.status || "all") === status
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:text-foreground"
            }`}
          >
            {t(`staff.contact_requests.status.${status}`)}
            <span className="ml-1 opacity-70">({counts[status] ?? counts.all})</span>
          </Link>
        ))}
      </div>

      {/* Table */}
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t("staff.contact_requests.fields.name")}</TableHead>
              <TableHead className="hidden md:table-cell">
                {t("staff.contact_requests.fields.email")}
              </TableHead>
              <TableHead className="hidden lg:table-cell">
                {t("staff.contact_requests.fields.message")}
              </TableHead>
              <TableHead>{t("staff.contact_requests.fields.status")}</TableHead>
              <TableHead className="hidden sm:table-cell">
                {t("staff.contact_requests.fields.date")}
              </TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {contact_requests.map((req) => (
              <TableRow key={req.id}>
                <TableCell className="font-medium">{req.name}</TableCell>
                <TableCell className="hidden md:table-cell">{req.email}</TableCell>
                <TableCell className="hidden lg:table-cell text-muted-foreground max-w-xs truncate">
                  {req.message}
                </TableCell>
                <TableCell>
                  <Badge variant={STATUS_VARIANT[req.status]}>
                    {t(`staff.contact_requests.status.${req.status}`)}
                  </Badge>
                </TableCell>
                <TableCell className="hidden sm:table-cell text-muted-foreground text-sm">
                  {req.formatted_date}
                </TableCell>
                <TableCell>
                  <Link href={`/staff/contact_requests/${req.id}`}>
                    <Button variant="ghost" size="sm">
                      {t("common.view")}
                    </Button>
                  </Link>
                </TableCell>
              </TableRow>
            ))}
            {contact_requests.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                  {t("staff.contact_requests.empty")}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </StaffLayout>
  );
}
```

### Staff Frontend: Contact Request Detail

```jsx
// app/frontend/pages/staff/contact-requests/show.jsx

import StaffLayout from "@/layout/staff-layout";
import { useForm } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select, SelectContent, SelectItem,
  SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function ContactRequestShow({ contact_request }) {
  const { t } = useTranslation();
  const { data, setData, patch, processing } = useForm({
    status: contact_request.status,
    staff_notes: contact_request.staff_notes || "",
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    patch(`/staff/contact_requests/${contact_request.id}`);
  };

  return (
    <StaffLayout>
      <div className="max-w-2xl">
        <h1 className="text-2xl font-bold mb-6">
          {t("staff.contact_requests.detail_title")}
        </h1>

        {/* Submission details */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="text-lg">{contact_request.name}</CardTitle>
            <p className="text-sm text-muted-foreground">
              {contact_request.email} &middot;{" "}
              {contact_request.formatted_date}
            </p>
          </CardHeader>
          <CardContent>
            <p className="whitespace-pre-wrap">{contact_request.message}</p>
          </CardContent>
        </Card>

        {/* Staff actions */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">
              {t("staff.contact_requests.actions")}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <Label>{t("staff.contact_requests.fields.status")}</Label>
                <Select value={data.status} onValueChange={(v) => setData("status", v)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {["new", "in_progress", "resolved", "archived"].map((s) => (
                      <SelectItem key={s} value={s}>
                        {t(`staff.contact_requests.status.${s}`)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label>{t("staff.contact_requests.fields.staff_notes")}</Label>
                <Textarea
                  rows={4}
                  value={data.staff_notes}
                  onChange={(e) => setData("staff_notes", e.target.value)}
                  placeholder={t("staff.contact_requests.notes_placeholder")}
                />
              </div>

              <Button type="submit" disabled={processing}>
                {t("staff.contact_requests.save")}
              </Button>
            </form>
          </CardContent>
        </Card>

        {contact_request.resolved_by && (
          <p className="text-sm text-muted-foreground mt-4">
            {t("staff.contact_requests.resolved_by", {
              name: contact_request.resolved_by,
            })}
          </p>
        )}
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
  contact:
    success: "Message sent! We'll get back to you soon."
    errors:
      name_required: "Name is required"
      email_invalid: "Please enter a valid email address"
      message_too_short: "Message must be at least 10 characters"
      message_too_long: "Message must be under 5,000 characters"
  staff:
    contact_requests:
      updated: "Contact request updated"
```

### Frontend

```yaml
# app/frontend/locales/en/contact.yml
contact:
  title: Contact Us
  subtitle: Have a question or feedback? Send us a message.
  fields:
    name: Name
    email: Email
    message: Message
  submit: Send Message
  errors:
    name_required: Name is required
    email_invalid: Please enter a valid email address
    message_too_short: Message must be at least 10 characters
    message_too_long: Message must be under 5,000 characters

# Merge into app/frontend/locales/en/staff.yml
staff:
  contact_requests:
    title: Contact Requests
    detail_title: Contact Request
    empty: No contact requests found
    actions: Staff Actions
    save: Update
    notes_placeholder: Internal notes...
    resolved_by: "Resolved by {{name}}"
    status:
      all: All
      new: New
      in_progress: In Progress
      resolved: Resolved
      archived: Archived
    fields:
      name: Name
      email: Email
      message: Message
      status: Status
      date: Date
      staff_notes: Staff Notes
```

---

## Spam Prevention

1. **Honeypot field** — hidden input that bots fill out; controller rejects if present
2. **Rate limiting** — use Rack::Attack to limit submissions per IP
3. **Message length** — minimum 10 chars, maximum 5,000 via Zod + interactor
4. **reCAPTCHA** — add later if spam becomes a problem

---

## Testing

### Factory

```ruby
# spec/support/factories/contact_requests.rb

FactoryBot.define do
  factory :contact_request do
    name { "Jane Doe" }
    email { "jane@example.com" }
    message { "I have a question about your product and would love some help." }
    status { "new" }

    trait :in_progress do
      status { "in_progress" }
    end

    trait :resolved do
      status { "resolved" }
      association :resolved_by, factory: :user
      staff_notes { "Issue addressed via email" }
    end
  end
end
```

### Interactor Specs

```ruby
# spec/interactors/contact_requests/create_spec.rb

RSpec.describe ContactRequests::Create do
  it "creates a contact request" do
    result = described_class.call(
      name: "Jane Doe",
      email: "jane@example.com",
      message: "I have a question about your product."
    )

    expect(result).to be_success
    expect(result.contact_request).to be_persisted
    expect(result.contact_request.status).to eq("new")
  end

  it "fails with invalid email" do
    result = described_class.call(
      name: "Jane",
      email: "not-valid",
      message: "I have a question about your product."
    )

    expect(result).to be_failure
  end

  it "fails with short message" do
    result = described_class.call(
      name: "Jane",
      email: "jane@example.com",
      message: "Hi"
    )

    expect(result).to be_failure
  end
end
```

### TelegramNotifier Spec

```ruby
# spec/services/telegram_notifier_spec.rb

RSpec.describe TelegramNotifier do
  describe ".send_message" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_API_KEY").and_return("fake_key")
    end

    it "sends a message via Telegram API" do
      stub = stub_request(:post, "https://api.telegram.org/botfake_key/sendMessage")
        .with(body: { chat_id: "123", text: "Hello" })
        .to_return(status: 200, body: '{"ok":true}')

      described_class.send_message(chat_id: "123", text: "Hello")
      expect(stub).to have_been_requested
    end

    it "logs errors on failure" do
      stub_request(:post, "https://api.telegram.org/botfake_key/sendMessage")
        .to_return(status: 400, body: '{"ok":false}')

      expect(Rails.logger).to receive(:error).with(/Failed to send message/)
      described_class.send_message(chat_id: "123", text: "Hello")
    end

    it "does nothing when API key is missing" do
      allow(ENV).to receive(:[]).with("TELEGRAM_API_KEY").and_return(nil)

      expect(Net::HTTP).not_to receive(:post_form)
      described_class.send_message(chat_id: "123", text: "Hello")
    end
  end
end
```

### NotifyStaff Interactor Spec

```ruby
# spec/interactors/contact_requests/notify_staff_spec.rb

RSpec.describe ContactRequests::NotifyStaff do
  let(:contact_request) { create(:contact_request) }

  context "when TELEGRAM_API_KEY is set" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_API_KEY").and_return("fake_key")
    end

    it "sends Telegram message to staff with telegram_chat_id" do
      create(:staff, :with_telegram, telegram_chat_id: "111")
      create(:staff, :with_telegram, telegram_chat_id: "222")
      create(:staff)  # no telegram — should not receive

      expect(TelegramNotifier).to receive(:send_message)
        .with(hash_including(chat_id: "111")).once
      expect(TelegramNotifier).to receive(:send_message)
        .with(hash_including(chat_id: "222")).once

      described_class.call(contact_request: contact_request)
    end
  end

  context "when TELEGRAM_API_KEY is not set" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_API_KEY").and_return(nil)
    end

    it "does not send Telegram messages" do
      create(:staff, :with_telegram)

      expect(TelegramNotifier).not_to receive(:send_message)
      described_class.call(contact_request: contact_request)
    end
  end
end
```

### Request Specs

```ruby
# spec/requests/contact_spec.rb

RSpec.describe "Contact", type: :request do
  describe "GET /contact/new" do
    it "renders the contact page" do
      get "/contact/new"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /contact" do
    it "creates a contact request" do
      expect {
        post "/contact", params: {
          name: "Jane Doe",
          email: "jane@example.com",
          message: "I have a question about your product."
        }
      }.to change(ContactRequest, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "rejects honeypot submissions" do
      expect {
        post "/contact", params: {
          name: "Bot", email: "bot@spam.com",
          message: "Buy cheap stuff", website: "http://spam.com"
        }
      }.not_to change(ContactRequest, :count)

      expect(response).to have_http_status(:ok)
    end
  end
end

# spec/requests/staff/contact_requests_spec.rb

RSpec.describe "Staff::ContactRequests", type: :request do
  let(:staff_user) { create(:user) }
  let!(:staff) { create(:staff, user: staff_user) }

  before { sign_in(staff_user) }

  describe "GET /staff/contact_requests" do
    let!(:request1) { create(:contact_request) }
    let!(:request2) { create(:contact_request, :resolved) }

    it "lists contact requests" do
      get "/staff/contact_requests"
      expect(response).to have_http_status(:ok)
    end

    it "filters by status" do
      get "/staff/contact_requests", params: { status: "new_request" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /staff/contact_requests/:slug" do
    let!(:contact_request) { create(:contact_request) }

    it "updates the status" do
      patch "/staff/contact_requests/#{contact_request.slug}", params: {
        status: "resolved",
        staff_notes: "Handled via email"
      }

      expect(contact_request.reload).to be_resolved
      expect(contact_request.resolved_by).to eq(staff_user)
    end
  end

  context "when user is not staff" do
    let(:regular_user) { create(:user) }

    before { sign_in(regular_user) }

    it "returns 404" do
      get "/staff/contact_requests"
      expect(response).to have_http_status(:not_found)
    end
  end
end
```
