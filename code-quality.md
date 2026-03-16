# Code Quality Guidelines

> General code quality rules for Rails apps. Copy to `docs/CODE_QUALITY.md` for new projects.
> This doc grows with the project — add project-specific rules as they emerge during development.

---

## Controllers

- **Three jobs only:** authorize, call an interactor, render. If you're writing business logic in a controller, it belongs somewhere else.
- **Never trust URL params for data access.** Always scope queries through authorization helpers. If a user shouldn't see a record, the query shouldn't return it — don't check after the fact.
- **Return 404 for unauthorized access, not 403.** Don't reveal that a record exists to someone who can't see it.
- **Strong params, always.** Whitelist every attribute explicitly. Never `.permit!`.

### Index / List Endpoints

Every paginated index action uses the **same query param names**. No aliases, no per-controller snowflakes.

| Param | Type | Purpose | Example |
|-------|------|---------|--------|
| `search` | string | Free-text search (pg_search) | `?search=acme` |
| `page` | integer | Current page (1-based) | `?page=2` |
| `per_page` | integer | Items per page (server caps max) | `?per_page=25` |
| `sort` | string | Column to sort by (snake_case) | `?sort=created_at` |
| `sort_direction` | string | `asc` or `desc` | `?sort_direction=desc` |
| `filter[<field>]` | string | Scoped filter by field name | `?filter[status]=active&filter[role]=admin` |

**Controller concern — `Indexable`:**

```ruby
# app/controllers/concerns/indexable.rb
module Indexable
  extend ActiveSupport::Concern

  private

  def index_params
    params.permit(:search, :page, :per_page, :sort, :sort_direction, filter: {})
  end

  def search_query  = index_params[:search]
  def current_page  = (index_params[:page] || 1).to_i
  def per_page      = [(index_params[:per_page] || 25).to_i, 100].min
  def sort_column   = index_params[:sort] || "created_at"
  def sort_direction = %w[asc desc].include?(index_params[:sort_direction]) ? index_params[:sort_direction] : "desc"
  def filters        = index_params[:filter]&.to_h || {}
end
```

**Usage in a controller:**

```ruby
class ArticlesController < ApplicationController
  include Indexable

  def index
    result = ListArticles.call(
      search: search_query,
      page: current_page,
      per_page: per_page,
      sort: sort_column,
      sort_direction: sort_direction,
      filters: filters
    )

    render inertia: "Articles/Index", props: {
      articles: serialize(result.articles),
      meta: pagination_meta(result.articles)
    }
  end
end
```

**JSON API response envelope** (for API-only endpoints):

```json
{
  "data": [...],
  "meta": {
    "current_page": 2,
    "per_page": 25,
    "total_pages": 8,
    "total_count": 187
  }
}
```

**Rules:**

- **1-based pages.** Page 1 is the first page, not page 0.
- **Cap `per_page`.** Never let the client request 10,000 rows. Set a server max (e.g., 100).
- **Whitelist `sort` columns.** Validate against an explicit list of allowed columns to prevent SQL injection. Reject unknown columns silently by falling back to the default.
- **Bracket-style filters.** Use `filter[status]=active`, not `status=active`. This keeps filter params namespaced and collision-free.
- **Don't sort when searching.** When `search` is present, pg_search orders by relevance rank. Adding `.order()` overrides that — skip it. See [search.md](search.md).
- **Pagination gem:** Use Kaminari (`.page(n).per(m)`).

---

## Interactors

- **All business logic lives in interactors.** Controllers are thin. Models are thin. Interactors are where the real work happens.
- **One interactor, one purpose.** If it does two unrelated things, split it. Use `Interactor::Organizer` to compose.
- **Validate params in a dedicated `Validate*` interactor.** This is the first step in every organizer. Do NOT use Rails model validations for business rules.
- **Use `context.fail!` for expected failures** — never raise exceptions for validation or business rule violations.
- **Wrap multi-write organizers in transactions.** If step 3 fails, steps 1 and 2 roll back.
- **Interactors can call other interactors** via organizers. Models should never call interactors. Keep the dependency arrow one-directional: Controller → Interactor → Model.

---

## Jobs

- **Jobs only define configuration and call an interactor.** A job class sets queue, retries, concurrency — then delegates all work to an interactor in `perform`. No business logic in the job itself.
- **One job, one interactor.** If a job needs to do multiple things, the interactor it calls should be an `Interactor::Organizer`.
- **Name jobs after what they trigger.** `ProcessPaymentJob` calls `ProcessPayment` interactor. The mapping should be obvious.

```ruby
# Good
class ProcessPaymentJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(invoice_id) { invoice_id }

  def perform(invoice_id)
    ProcessPayment.call!(invoice_id: invoice_id)
  end
end

# Bad — business logic in the job
class ProcessPaymentJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    charge = Stripe::Charge.create(amount: invoice.total, ...)
    invoice.update!(paid_at: Time.current, charge_id: charge.id)
    UserMailer.receipt(invoice).deliver_later
  end
end
```

---

## Models

- **No `validates` on models. Period.** All validation lives in interactors, right next to the write operation. Models define associations, scopes, normalizations, and helper methods — never validation rules. The database enforces data integrity (NOT NULL, unique indexes, CHECK constraints, foreign keys). Interactors enforce business rules. Models do neither.
- **Slugs, not IDs in URLs.** Every user-facing model must include the `Sluggable` concern and use its `slug` column for URL lookups. Numeric IDs are internal — never expose them in routes or links. See the [Slugs](#slugs) section below.
- **Integer-backed enums only.** Every enum column is an `integer` in the database, never a `string`. Use Rails `enum` with explicit value mapping. See the [Enums](#enums) section below.
- **Scopes for reusable queries.** If a `where` clause appears in more than one place, make it a scope. Named scopes make code readable.
- **Minimize callbacks.** Normalizing data in `before_save` is fine. Triggering jobs, sending emails, or modifying other records in `after_create` is not — that belongs in an interactor where it's explicit and testable.
- **Associations tell the domain story.** Read the model file and you should understand the relationships. Use descriptive foreign key names over generic ones.

### Slugs

**Every model that appears in a URL** must have a `slug` column and use the `Sluggable` concern. URLs show slugs, never numeric IDs.

```
/users/j4k9m2x        ← good (slug)
/users/42              ← bad  (numeric ID)
/announcements/x7p3q1  ← good
```

#### Migration

Add a `slug` column to any model that needs URL exposure:

```ruby
add_column :users, :slug, :string, null: false
add_index  :users, :slug, unique: true
```

#### Concern

```ruby
# app/models/concerns/sluggable.rb
module Sluggable
  extend ActiveSupport::Concern

  SLUG_LENGTH = 8
  SLUG_ALPHABET = ("a".."z").to_a + ("0".."9").to_a

  included do
    before_create :generate_slug, unless: :slug?

    scope :find_by_slug!, ->(slug) { find_by!(slug: slug) }
  end

  # Rails uses this for route generation:
  #   user_path(user) → "/users/j4k9m2x"
  def to_param
    slug
  end

  private

  def generate_slug
    loop do
      self.slug = Array.new(SLUG_LENGTH) { SLUG_ALPHABET.sample }.join
      break unless self.class.exists?(slug: slug)
    end
  end
end
```

#### Model usage

```ruby
class User < ApplicationRecord
  include Sluggable
  # ...
end

class Announcement < ApplicationRecord
  include Sluggable
  # ...
end
```

#### Controller lookups

**Always** use `find_by_slug!` instead of `find`:

```ruby
# Good
user = User.find_by_slug!(params[:slug])

# Bad — exposes numeric ID
user = User.find(params[:id])
```

#### Routes

Use `param: :slug` on every resource that uses slugs:

```ruby
resources :users, param: :slug, only: [:show]
resources :announcements, param: :slug
```

This makes Rails generate `params[:slug]` instead of `params[:id]`.

### Enums {#enums}

**Every enum is backed by an integer column.** String columns waste space, are slower to index, and invite typos. Rails `enum` maps symbolic names to integers automatically.

#### Migration

```ruby
# Always use :integer (the default for add_column :integer)
add_column :contact_requests, :status, :integer, null: false, default: 0
add_column :staffs, :role, :integer, null: false, default: 0
```

#### Model

```ruby
class ContactRequest < ApplicationRecord
  enum :status, { new_request: 0, in_progress: 1, resolved: 2, archived: 3 }
end
```

**Rules:**

- **Explicit integer mapping.** Always use the `{ name: N }` hash form. Never use an array — inserting a value in the middle silently shifts all subsequent mappings and corrupts existing data.
- **Never reorder or remove values.** Once a mapping is deployed, it's permanent. To deprecate a value, add a new one and migrate data — never delete or renumber.
- **Start at 0.** Follow Ruby / C convention. Use `default: 0` in the migration for the most common initial state.
- **Use `_prefix` or `_suffix` when names collide.** If two enums on the same model share a value name (e.g. `status: :active` and `tier: :active`), use `enum :status, { ... }, prefix: true` so the scope becomes `status_active` instead of `active`.
- **No string columns for enums.** If you see `t.string :status` in a migration for a field with a known set of values, change it to `t.integer :status`.

```ruby
# Good — integer column, explicit mapping
enum :role, { staff: 0, admin: 1, super_admin: 2 }

# Bad — string column, no Rails enum
ROLES = %w[staff admin super_admin].freeze
```

---

## Database

- **Use `strong_migrations` gem.** It catches unsafe migrations (e.g. adding a column with a default on a large table, removing a column still referenced in code). Add `gem 'strong_migrations'` to the Gemfile and follow its recommendations when it flags an issue.
- **Index every foreign key.** No exceptions. Also index columns you query or sort by frequently.
- **Add indexes concurrently.** Always use `algorithm: :concurrently` when adding indexes. This requires `disable_ddl_transaction!` at the top of the migration.
- **Migrations must be reversible.** Try extra hard to write reversible migrations using `change` (not `up`/`down`) whenever possible. After generating a migration, always run it and then roll it back to verify:
  ```bash
  bin/rails db:migrate && bin/rails db:rollback
  ```
  Only then move on to the next task.
- **Database constraints are the last line of defense.** `NOT NULL`, unique indexes, CHECK constraints, and foreign keys catch bugs that validations miss. Code can have bugs. Constraints can't be bypassed. Use both.
- **Pre-release: edit migrations directly.** Before the first production deploy, keep migration history clean by editing existing migration files instead of creating new ones. Reset your database after changes:
  ```bash
  bin/rails db:drop db:create db:migrate db:seed
  ```
  This keeps the initial migration set readable and minimal. Only switch to append-only after production has real data.
- **Post-release: migrations are append-only.** Once the app is in production, never edit a migration that's been run. Need to change something? Write a new migration. Production databases can't be reset.
- **Back every association with a real foreign key.** This prevents orphaned records and makes the schema self-documenting.
- **Annotate every model.** Use the `annotate` gem to keep schema comments at the top of every model, factory, spec, and route file. See the [Annotate](#annotate) section below.

### Annotate (Schema Annotations) {#annotate}

The `annotate` gem writes the current schema as a comment block at the top of model files, factories, specs, and routes. This makes it possible to see every column, index, and foreign key without opening a migration or `schema.rb`.

#### Gemfile

```ruby
group :development do
  gem "annotate"
end
```

#### Generator

Run once after installing:

```bash
bin/rails generate annotate:install
```

This creates `lib/tasks/auto_annotate_models.rake` which auto-runs annotations after every `db:migrate`. Edit the generated rake file to match these settings:

```ruby
# lib/tasks/auto_annotate_models.rake
if Rails.env.development?
  task :set_annotation_options do
    Annotate.set_defaults(
      "active_admin"                => "false",
      "additional_file_patterns"    => [],
      "routes"                      => "false",
      "models"                      => "true",
      "position_in_routes"          => "before",
      "position_in_class"           => "before",
      "position_in_test"            => "before",
      "position_in_fixture"         => "before",
      "position_in_factory"         => "before",
      "position_in_serializer"      => "before",
      "show_foreign_keys"           => "true",
      "show_complete_foreign_keys"  => "true",
      "show_indexes"                => "true",
      "simple_indexes"              => "false",
      "model_dir"                   => "app/models",
      "root_dir"                    => "",
      "include_version"             => "false",
      "require"                     => "",
      "exclude_tests"               => "false",
      "exclude_fixtures"            => "true",
      "exclude_factories"           => "false",
      "exclude_serializers"         => "true",
      "exclude_scaffolds"           => "true",
      "exclude_controllers"         => "true",
      "exclude_helpers"             => "true",
      "exclude_sti_subclasses"      => "false",
      "ignore_model_sub_dir"        => "false",
      "ignore_columns"              => nil,
      "ignore_routes"               => nil,
      "ignore_unknown_models"       => "false",
      "hide_limit_column_types"     => "integer,bigint,boolean",
      "hide_default_column_types"   => "json,jsonb,hstore",
      "classified_sort"             => "true",
      "with_comment"                => "true",
      "format_bare"                 => "true",
      "format_rdoc"                 => "false",
      "format_yard"                 => "false",
      "format_markdown"             => "false",
      "sort"                        => "false",
      "force"                       => "false",
      "frozen"                      => "false",
      "trace"                       => "false",
      "wrapper_open"                => nil,
      "wrapper_close"               => nil
    )
  end

  Annotate.load_tasks
end
```

#### Key settings

| Setting | Value | Why |
|---------|-------|-----|
| `position_in_class` | `before` | Schema at the top of the file — the first thing you see |
| `show_foreign_keys` | `true` | See FK relationships at a glance |
| `show_indexes` | `true` | Know which columns are indexed without checking migrations |
| `exclude_factories` | `false` | Keep factories annotated for reference during test writing |
| `with_comment` | `true` | Include column comments from the database |

#### Running annotations

Annotations run **automatically** after every `db:migrate` (via the rake task above). To manually re-annotate all files:

```bash
bin/rails annotate_models
```

To remove all annotations (rarely needed):

```bash
bin/rails remove_annotation
```

#### Process

1. **After every migration** — annotations update automatically. Verify the diff looks correct before committing.
2. **After pulling changes** — if a teammate ran a migration, run `bin/rails db:migrate` locally. Annotations update automatically.
3. **Commit annotations with the migration** — the migration and the updated annotations belong in the same commit. Never commit a migration without the corresponding annotation changes.
4. **Don't hand-edit annotations** — they're auto-generated. If they're wrong, fix the schema and re-run.

#### Example output

```ruby
# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  email_address   :string           not null
#  password_digest :string           not null
#  slug            :string           not null
#  verified        :boolean          default(FALSE), not null
#  comped          :boolean          default(FALSE), not null
#  suspended_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#  index_users_on_slug           (slug) UNIQUE
#
class User < ApplicationRecord
  include Sluggable
  # ...
end
```

### Seeds

Seeds must be **idempotent** — running `bin/rails db:seed` twice produces the same result. Use `find_or_create_by` on a natural key, never blind `create!`.

**Structure:** Split seeds into one file per concern under `db/seeds/`, loaded by the main `db/seeds.rb`:

```ruby
# db/seeds.rb
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |f| load f }
```

```ruby
# db/seeds/01_plans.rb
[
  { stripe_id: "price_basic", name: "Basic", amount: 900 },
  { stripe_id: "price_pro",   name: "Pro",   amount: 2900 },
].each do |attrs|
  Plan.find_or_create_by!(stripe_id: attrs[:stripe_id]) do |plan|
    plan.name   = attrs[:name]
    plan.amount = attrs[:amount]
  end
end
```

```ruby
# db/seeds/02_staff.rb (development only)
return unless Rails.env.development?

user = User.find_or_create_by!(email_address: "admin@example.com") do |u|
  u.first_name = "Admin"
  u.last_name  = "User"
  u.password   = "password123"
end

Staff.find_or_create_by!(user: user) do |s|
  s.role = "super_admin"
end
```

**Rules:**

- **Always idempotent.** `find_or_create_by` on a stable natural key (slug, stripe_id, email). Never `create!` unconditionally.
- **Numbered files.** Prefix with `01_`, `02_` for execution order since dependencies matter (plans before users, users before staff).
- **Guard dev-only seeds.** Wrap test data in `return unless Rails.env.development?` — production seeds should only contain reference data (plans, roles, categories).
- **No FFaker in seeds.** Seeds are deterministic reference data, not random test data. Use explicit values.
- **Keep seeds fast.** Avoid N+1s — batch where possible. Seeds run on every `db:setup` and `db:reset`.

> **Note:** For app-critical data that must exist in ALL environments (including test) and survive database cleaner, use **Reference Data** (below) instead of seeds.

### Reference Data

Reference data is app-critical configuration (plans, roles, permission levels, categories, etc.) that:

1. **Must exist in every environment** — development, test, CI, staging, production
2. **Loads automatically on app boot** — no manual `rake db:seed` required
3. **Survives database cleaner** — tests can rely on it being present
4. **Is defined in YAML files** — easy to read, diff, and sync with production
5. **Is truly idempotent** — re-running updates existing records, never duplicates

**This is different from seeds:**
- Seeds (`db/seeds/`) require `bin/rails db:seed` and don't run in test
- Reference data loads automatically via an initializer in all environments

#### Directory Structure

```
db/
├── reference_data/
│   ├── plans.yml
│   ├── roles.yml
│   └── categories.yml
└── seeds/
    └── ...
```

#### YAML Format

Each file defines records for one model. Use a stable `key` field as the lookup identifier:

```yaml
# db/reference_data/plans.yml
#
# Subscription plans. Synced from Stripe — update here after creating
# products/prices via Stripe CLI, then deploy.

- key: free
  name: Free
  stripe_price_id: null
  amount_cents: 0
  interval: null
  features:
    - "Up to 3 projects"
    - "Community support"

- key: pro
  name: Pro
  stripe_price_id: price_1ABC123
  amount_cents: 2900
  interval: month
  features:
    - "Unlimited projects"
    - "Priority support"
    - "API access"

- key: lifetime
  name: Lifetime
  stripe_price_id: price_1XYZ789
  amount_cents: 29900
  interval: null  # one-time
  features:
    - "Everything in Pro"
    - "Lifetime updates"
```

```yaml
# db/reference_data/roles.yml
#
# Staff roles with permission levels.

- key: super_admin
  name: Super Admin
  can_manage_staff: true
  can_manage_billing: true
  can_export_data: true

- key: admin
  name: Admin
  can_manage_staff: false
  can_manage_billing: true
  can_export_data: true

- key: support
  name: Support
  can_manage_staff: false
  can_manage_billing: false
  can_export_data: false
```

#### Loader Module

```ruby
# lib/reference_data.rb
#
# Loads YAML files from db/reference_data/ into the database.
# Called on app boot via initializer. Idempotent — safe to run repeatedly.

module ReferenceData
  class << self
    def load_all!
      Dir[Rails.root.join("db/reference_data/*.yml")].sort.each do |file|
        load_file!(file)
      end
    end

    def load_file!(path)
      filename = File.basename(path, ".yml")
      model_class = filename.classify.constantize
      records = YAML.load_file(path, permitted_classes: [Symbol]) || []

      records.each do |attrs|
        attrs = attrs.deep_symbolize_keys
        key = attrs.delete(:key) || raise("Missing 'key' in #{path}")

        record = model_class.find_or_initialize_by(key: key)
        record.assign_attributes(attrs)
        record.save!
      end

      Logs.info("ReferenceData", "Loaded #{records.size} #{filename}")
    end

    # Export current DB state back to YAML (for syncing from production)
    def export!(model_class, path: nil)
      path ||= Rails.root.join("db/reference_data/#{model_class.table_name}.yml")
      records = model_class.order(:key).map do |record|
        attrs = record.attributes.except("id", "created_at", "updated_at")
        attrs.deep_stringify_keys
      end

      File.write(path, records.to_yaml)
      Logs.info("ReferenceData", "Exported #{records.size} to #{path}")
    end
  end
end
```

#### Initializer (Auto-Load on Boot)

```ruby
# config/initializers/reference_data.rb
#
# Load reference data on every app boot — development, test, and production.
# Runs after database connection is established.

Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection.data_source_exists?("plans")
    ReferenceData.load_all!
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Skip during db:create or when tables don't exist yet
  Logs.warn("ReferenceData", "Skipped — database not ready")
end
```

#### Model Requirements

Each reference data model needs a `key` column as the unique lookup field:

```ruby
# Migration
class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :stripe_price_id
      t.integer :amount_cents, null: false, default: 0
      t.string :interval
      t.jsonb :features, null: false, default: []
      t.timestamps
    end
  end
end

# Model
class Plan < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  # Access by key
  class << self
    def free = find_by!(key: "free")
    def pro = find_by!(key: "pro")
    def lifetime = find_by!(key: "lifetime")
  end
end
```

#### Rake Tasks

```ruby
# lib/tasks/reference_data.rake

namespace :reference_data do
  desc "Load all reference data from YAML files"
  task load: :environment do
    ReferenceData.load_all!
  end

  desc "Export a model's current data to YAML (for syncing from production)"
  task :export, [:model] => :environment do |_t, args|
    model_class = args[:model].classify.constantize
    ReferenceData.export!(model_class)
    puts "Exported to db/reference_data/#{model_class.table_name}.yml"
  end
end
```

Usage:

```bash
# Manually reload reference data (usually not needed — happens on boot)
bin/rails reference_data:load

# Export current Plan records to YAML (run in production via kamal exec)
bin/rails reference_data:export[Plan]

# Then copy the YAML from production to your repo and commit
kamal app exec "cat db/reference_data/plans.yml" > db/reference_data/plans.yml
```

#### Test Configuration (DatabaseCleaner)

Reference data must survive between tests. Configure DatabaseCleaner to use **transactions** (default) which automatically preserves reference data, or if you must use truncation, exclude reference tables:

```ruby
# spec/support/database_cleaner.rb

RSpec.configure do |config|
  config.before(:suite) do
    # Ensure reference data is loaded before any tests run
    ReferenceData.load_all!
  end

  config.use_transactional_fixtures = true

  # If you need truncation for specific tests (e.g., system tests),
  # exclude reference data tables:
  #
  # config.before(:each, type: :system) do
  #   DatabaseCleaner.strategy = :truncation, {
  #     except: %w[plans roles categories]  # reference data tables
  #   }
  # end
end
```

#### Syncing Production Changes

When a staff user creates/updates reference data via the admin UI (e.g., adds a new plan):

1. **Export from production:**
   ```bash
   kamal app exec -i "bin/rails reference_data:export[Plan]"
   kamal app exec "cat db/reference_data/plans.yml"
   ```

2. **Copy to your repo** — paste into `db/reference_data/plans.yml`

3. **Commit and deploy** — now all environments have the new data

This keeps YAML files as the source of truth while allowing production edits when needed.

#### Rules

- **Every reference data model has a `key` column.** This is the stable, human-readable identifier used for lookups. Never use the `id` column as a reference — IDs vary across environments.
- **YAML files are the source of truth.** Production can be updated first, but always export and commit changes back to the repo.
- **Never delete reference data rows.** Add a `deprecated` or `archived` flag instead. Existing records may reference them.
- **Loads on every boot.** The initializer runs on server start, console, rake tasks — everywhere.
- **Tests rely on it.** `Plan.pro` just works in specs without any `let` or `create` setup.
- **No FFaker, no randomness.** This is deterministic configuration, not test data.

### Development Seed Data

Separate from production seeds. This is a **manual** rake task that populates your development database with rich, realistic data so you can launch the app and explore every feature visually.

```bash
bin/rails dev:seed
```

**Structure:** A rake task that loads numbered files from `db/dev_seeds/`:

```ruby
# lib/tasks/dev_seeds.rake
namespace :dev do
  desc "Seed development database with realistic sample data"
  task seed: :environment do
    abort("This task is only for development!") unless Rails.env.development?

    puts "Seeding development data..."
    Dir[Rails.root.join("db/dev_seeds/*.rb")].sort.each do |f|
      puts "  Loading #{File.basename(f)}..."
      load f
    end
    puts "Done!"
  end
end
```

**Helper — `seed_record`:** Use this instead of raw `find_or_create_by`. It finds or initializes by the lookup key, then **always updates** all attributes — so changing a value in the seed file and re-running applies the change.

```ruby
# db/dev_seeds/00_helpers.rb
#
# Loaded first (sorted by filename). Defines helpers used by all seed files.

def seed_record(klass, find_by, attributes = {})
  record = klass.find_or_initialize_by(find_by)
  record.assign_attributes(attributes)
  record.save!
  record
end
```

Usage:

```ruby
# find_by key       attrs that get updated on every run
seed_record(User, { email_address: "dev@example.com" }, { name: "Dev User", password: "password123" })
```

If you change `name: "Dev User"` to `name: "Dev Admin"` and re-run, the existing record gets updated.

**Example files:**

```ruby
# db/dev_seeds/01_users.rb
#
# Creates users covering every type and state:
# - Regular free users
# - Paid users (one per plan)
# - Comped/gifted users
# - Suspended users
# - Users with unverified emails
# - Users who signed up via Google OAuth

# A known user you can always sign in with
seed_record(User,
  { email_address: "dev@example.com" },
  { name: "Dev User", password: "password123" })

# Batch of diverse users
20.times do |i|
  seed_record(User,
    { email_address: "user#{i}@example.com" },
    { name: FFaker::Name.name, password: "password123" })
end

# Suspended user
seed_record(User,
  { email_address: "suspended@example.com" },
  { name: "Suspended User", password: "password123",
    suspended_at: 3.days.ago, suspended_reason: "Terms of service violation" })

# Comped user
seed_record(User,
  { email_address: "comped@example.com" },
  { name: "Comped User", password: "password123", comped: true })

puts "    Created #{User.count} users"
```

```ruby
# db/dev_seeds/02_staff.rb
#
# Staff accounts — use the same dev user for easy access

dev_user = User.find_by!(email_address: "dev@example.com")
seed_record(Staff, { user: dev_user }, { role: "super_admin" })

# Additional staff member
seed_record(User,
  { email_address: "staff@example.com" },
  { name: "Staff Member", password: "password123" })
staff_user = User.find_by!(email_address: "staff@example.com")
seed_record(Staff, { user: staff_user }, { role: "staff" })

puts "    Created #{Staff.count} staff members"
```

```ruby
# db/dev_seeds/03_contact_requests.rb
#
# Mix of read and unread contact requests

8.times do |i|
  seed_record(ContactRequest,
    { email: "contact#{i}@example.com" },
    { name: FFaker::Name.name,
      message: FFaker::Lorem.paragraph,
      read_at: i < 6 ? nil : Time.current })  # first 6 unread, last 2 read
end

puts "    Created #{ContactRequest.count} contact requests"
```

```ruby
# db/dev_seeds/04_announcements.rb
#
# Active, scheduled, and expired announcements

[
  { title: "Welcome to the beta!", body: "Thanks for being an early user.",
    style: "info", starts_at: 1.week.ago, ends_at: 1.month.from_now, dismissible: true },
  { title: "Scheduled maintenance", body: "We'll be down briefly on Saturday.",
    style: "warning", starts_at: 3.days.from_now, ends_at: 4.days.from_now, dismissible: false },
  { title: "Old announcement", body: "This one has expired.",
    style: "info", starts_at: 2.months.ago, ends_at: 1.month.ago, dismissible: true },
].each do |attrs|
  seed_record(Announcement, { title: attrs[:title] }, attrs.except(:title))
end

puts "    Created #{Announcement.count} announcements"
```

Adapt the examples above to your project's actual models. The key is **covering every meaningful state and combination**, not just happy paths.

**Rules:**

- **Truly idempotent — update on re-run.** Use the `seed_record` helper (defined in `00_helpers.rb`). It does `find_or_initialize_by` on a stable key, then `assign_attributes` + `save!` — so changing a value in the seed file and re-running **updates** the existing record. Never use `find_or_create_by` with a block (the block only runs on create, not on subsequent runs).
- **FFaker for bulk data, explicit values for special cases.** The "suspended user" needs a specific email you can find; the 20 regular users use FFaker.
- **One file per domain area.** Numbered for dependency order (users before staff, plans before subscriptions).
- **Print counts.** Each file prints what it created so you can verify at a glance.
- **Keep a known login.** Always create `dev@example.com` / `password123` so you have a predictable way to sign in. Make this user a staff/super_admin for easy access to admin features.
- **Cover every state.** For each model, think: what are the possible statuses, roles, flags, and edge cases? Create at least one record for each.
- **Must be updated with every new feature.** When you add a new model, add a new dev seed file. When you add a new status or flag to an existing model, add a record with that state. This is part of the feature deliverable, not an afterthought.
- **Never run in production.** The rake task aborts if not in development.
- **Separate from `db:seed`.** Production seeds (`db/seeds/`) contain only reference data (plans, roles). Dev seeds (`db/dev_seeds/`) contain sample data for browsing.

---

## Authorization

- **Think in scopes, not permissions.** Don't ask "can this user do this action?" — narrow the query to only return records the user can see, then operate on the result.
- **Use constants for domain strings.** User types, statuses, categories — anything referenced in more than one place should be a constant on the model, not a string literal.
- **Type-check helpers live on the User model.** Use `current_user.admin?` etc. — never define role-check methods in controllers.

---

## Frontend

- **Pages are thin.** Over 100 lines? Extract sub-components. Complex state? Extract a hook.
- **Check [shadcn/ui Blocks](https://www.shadcn.io/blocks/) first.** Before building a custom component, see if a ready-made block exists. Use it as-is or adapt it. Only build from scratch if nothing fits.
- **Use the component library.** shadcn/ui for standard controls. Custom components only for domain-specific UI the library doesn't cover.
- **Install all shadcn/ui components upfront.** Don't add them one-by-one. Install the full set on project setup so they're always available. Make sure every component is i18n-ready (no hardcoded English in placeholders, empty states, aria labels, etc.).
- **Icons use wrapper components.** Never import directly from `lucide-react` in pages or components. Each icon has a dedicated file in `components/icons/` (e.g., `close.tsx` exports `IconClose` from Lucide). This makes icon library swaps a single-directory change.
- **Design tokens, not hardcoded values.** Use semantic color/spacing tokens, never raw color codes or pixel values.
- **Mobile first, always.** Base styles target 320px (minimum supported width). Add `sm:`, `md:`, `lg:` breakpoints to scale up — never the other way around.
- **Minimum supported width: 320px.** Nothing should overflow, clip, or require horizontal scrolling at 320px.
- **Don't skip tablets.** Explicitly handle the `md` (768px) breakpoint. Adjust grid columns, sidebar behavior, padding, and form layouts for tablet-sized screens — don't jump from phone to desktop.
- **Stylelint for CSS.** Run `bun lint:css` on all CSS files. Catches invalid properties, enforces alphabetical ordering, and knows about Tailwind directives. Fix auto-fixable issues with `bun lint:css:fix`.
- **ESLint for JS code quality.** Run `bun lint` to catch errors, unused vars, import ordering, and React hook issues. Run `bun lint:fix` to auto-fix (sorts imports, removes unused imports). See [inertia-react.md](inertia-react.md#eslint--prettier).
- **Prettier for auto-formatting.** Run `bun format` to format JS, CSS, and YAML files. Prettier owns all style decisions (quotes, semicolons, indentation) — ESLint only handles code quality rules.
- **Bun for JS package management.** Use `bun add`, `bun install`, `bun test`, `bunx` — never `npm` or `npx`.

---

## Error Handling

- **Raise meaningful exceptions.** Domain-specific exception classes tell you exactly what went wrong without reading a stack trace.
- **Don't rescue broadly.** `rescue => e` catches everything including typos and nil errors. Rescue specific exceptions you expect and can handle. Let unexpected errors bubble up.
- **Trust the framework.** If a record isn't found, Rails renders 404 automatically. Don't catch exceptions just to manually replicate what the framework already does.

---

## Performance

- **Prevent N+1 queries.** Use `includes` or `preload` when you know the view will access associations.
- **Denormalize sparingly but intentionally.** If a computed value is expensive to derive and queried often, denormalize it. Document why it exists and ensure it stays in sync through a single code path.
- **Paginate all list endpoints.** No endpoint should return unbounded results.

---

## Bullet (N+1 Detection) {#bullet}

**Always include the Bullet gem** in development and test environments. It detects N+1 queries, unused eager loading, and counter cache opportunities.

### Gemfile

```ruby
group :development, :test do
  gem "bullet"
end
```

### Configuration

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true           # Browser popup
  Bullet.bullet_logger = true   # log/bullet.log
  Bullet.console = true         # Browser console
  Bullet.rails_logger = true    # Rails log
  Bullet.add_footer = true      # Page footer
end

# config/environments/test.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.raise = true           # RAISE in tests — fail fast on N+1
end
```

### RSpec Integration

```ruby
# spec/support/bullet.rb
if Bullet.enable?
  RSpec.configure do |config|
    config.before(:each) { Bullet.start_request }
    config.after(:each) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end
```

---

## Ruby Class Structure

**Always use `class << self` for class methods**, never `self.method_name`. Keep class methods at the top of the class, before instance methods.

```ruby
# ✅ CORRECT
class User < ApplicationRecord
  class << self
    def find_by_email(email)
      find_by(email_address: email)
    end

    def active
      where(deactivated_at: nil)
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role == ADMIN
  end
end

# ❌ WRONG — don't use self.method_name
class User < ApplicationRecord
  def self.find_by_email(email)
    find_by(email_address: email)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def self.active  # Also wrong: class methods scattered among instance methods
    where(deactivated_at: nil)
  end
end
```

### Class Layout Order

1. Constants
2. Includes / Concerns
3. Associations
4. Enums
5. `class << self` block (all class methods)
6. Instance methods (public, then private)

---

## RuboCop {#rubocop}

**Always include RuboCop** with the extensions below. It enforces consistent style across the project and catches real bugs.

### Extensions

```ruby
# Gemfile
group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
end
```

### TODO Workflow

Use `.rubocop_todo.yml` to park existing offenses and tackle them incrementally:

```bash
bundle exec rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 999999
```

This generates a TODO file that excludes every current offense by file, not by disabling the cop globally. Chip away at it over time — don't try to fix everything at once.

### When Inline Disables Are OK

Occasionally disabling **Metrics** cops inline is fine when the alternative is worse. Big hashes, long `case` statements, and factory definitions are often clearer as a single block than split across methods. Use a targeted inline comment:

```ruby
# rubocop:disable Metrics/MethodLength
def build_response
  {
    id: record.id,
    name: record.name,
    # ... 20 more fields that belong together
  }
end
# rubocop:enable Metrics/MethodLength
```

Do **not** disable Lint or Security cops inline. If a Lint cop fires, fix the code.

### Base Configuration

Use this as the starting `.rubocop.yml`. Add project-specific `Exclude` entries as needed.

```yaml
# .rubocop.yml
inherit_from: .rubocop_todo.yml

inherit_mode:
  merge:
    - Exclude

plugins:
  - rubocop-capybara
  - rubocop-factory_bot
  - rubocop-rails
  - rubocop-rspec
  - rubocop-rspec_rails
  - rubocop-performance

AllCops:
  NewCops: enable
  Exclude:
    - bin/**
    - vendor/**/*
    - tmp/**/*
    - storage/**/*

# ─── Layout ────────────────────────────────────────────

Layout/BeginEndAlignment:
  Enabled: true

Layout/EmptyLinesAroundAttributeAccessor:
  Enabled: true

Layout/FirstHashElementIndentation:
  Enabled: true
  EnforcedStyle: consistent

Layout/LineLength:
  Enabled: true
  Max: 120
  AllowedPatterns:
    - ^.*_REGEXP\s=.*
  Exclude:
    - db/migrate/*.rb

Layout/MultilineMethodCallIndentation:
  Enabled: true
  EnforcedStyle: indented

Layout/SpaceAroundMethodCallOperator:
  Enabled: true

Layout/SpaceBeforeBrackets:
  Enabled: true

Layout/TrailingEmptyLines:
  Enabled: true

# ─── Metrics ───────────────────────────────────────────

Metrics/BlockLength:
  AllowedMethods:
    - describe
    - context
    - included
  Exclude:
    - config/**/*
    - spec/**/*

Metrics/MethodLength:
  Enabled: true
  Max: 15
  Exclude:
    - config/**/*
    - spec/**/*
    - db/migrate/*

# ─── Lint ──────────────────────────────────────────────

Lint/AmbiguousAssignment:
  Enabled: true

Lint/AmbiguousBlockAssociation:
  Exclude:
    - spec/**/*

Lint/BinaryOperatorWithIdenticalOperands:
  Enabled: true

Lint/ConstantDefinitionInBlock:
  Enabled: true

Lint/DeprecatedConstants:
  Enabled: true

Lint/DeprecatedOpenSSLConstant:
  Enabled: true

Lint/DuplicateBranch:
  Enabled: true

Lint/DuplicateElsifCondition:
  Enabled: true

Lint/DuplicateRegexpCharacterClassElement:
  Enabled: true

Lint/DuplicateRequire:
  Enabled: true

Lint/DuplicateRescueException:
  Enabled: true

Lint/EmptyBlock:
  Enabled: true

Lint/EmptyClass:
  Enabled: true

Lint/EmptyConditionalBody:
  Enabled: true

Lint/EmptyFile:
  Enabled: true

Lint/FloatComparison:
  Enabled: true

Lint/IdentityComparison:
  Enabled: true

Lint/LambdaWithoutLiteralBlock:
  Enabled: true

Lint/MissingSuper:
  Enabled: true

Lint/MixedRegexpCaptureTypes:
  Enabled: true

Lint/NoReturnInBeginEndBlocks:
  Enabled: true

Lint/NumberedParameterAssignment:
  Enabled: true

Lint/OrAssignmentToConstant:
  Enabled: true

Lint/OutOfRangeRegexpRef:
  Enabled: true

Lint/RaiseException:
  Enabled: true

Lint/RedundantDirGlobSort:
  Enabled: true

Lint/SelfAssignment:
  Enabled: true

Lint/StructNewOverride:
  Enabled: false

Lint/SymbolConversion:
  Enabled: true

Lint/ToEnumArguments:
  Enabled: true

Lint/TopLevelReturnWithArgument:
  Enabled: true

Lint/TrailingCommaInAttributeDeclaration:
  Enabled: true

Lint/TripleQuotes:
  Enabled: true

Lint/UnexpectedBlockArity:
  Enabled: true

Lint/UnmodifiedReduceAccumulator:
  Enabled: true

Lint/UnreachableLoop:
  Enabled: true

Lint/UselessMethodDefinition:
  Enabled: true

Lint/UselessTimes:
  Enabled: true

# ─── Performance ───────────────────────────────────────

Performance/AncestorsInclude:
  Enabled: true

Performance/BigDecimalWithNumericArgument:
  Enabled: true

Performance/BlockGivenWithExplicitBlock:
  Enabled: true

Performance/CaseWhenSplat:
  Enabled: true

Performance/ChainArrayAllocation:
  Enabled: false

Performance/CollectionLiteralInLoop:
  Enabled: true

Performance/ConstantRegexp:
  Enabled: true

Performance/IoReadlines:
  Enabled: true

Performance/MethodObjectAsBlock:
  Enabled: true

Performance/OpenStruct:
  Enabled: true

Performance/RedundantEqualityComparisonBlock:
  Enabled: true

Performance/RedundantSortBlock:
  Enabled: true

Performance/RedundantSplitRegexpArgument:
  Enabled: true

Performance/RedundantStringChars:
  Enabled: true

Performance/ReverseFirst:
  Enabled: true

Performance/SortReverse:
  Enabled: true

Performance/Squeeze:
  Enabled: true

Performance/StringInclude:
  Enabled: true

Performance/Sum:
  Enabled: true

# ─── RSpec ─────────────────────────────────────────────

RSpec/ContextWording:
  Enabled: true
  Exclude:
    - spec/support/shared_contexts/*.rb
    - spec/support/shared_contexts/**/*.rb
    - spec/support/shared_examples/*.rb
    - spec/support/shared_examples/**/*.rb

RSpec/DescribeClass:
  Exclude:
    - spec/requests/**/*_spec.rb

RSpec/DescribedClassModuleWrapping:
  Enabled: true

RSpec/EmptyExampleGroup:
  Enabled: true
  Exclude:
    - spec/requests/**/*_spec.rb

RSpec/ExampleLength:
  Max: 15
  Enabled: true
  CountAsOne:
    - array
    - hash

RSpec/ImplicitSubject:
  Enabled: true
  Exclude:
    - spec/models/*_spec.rb

RSpec/IteratedExpectation:
  Enabled: false

RSpec/LetSetup:
  Enabled: false

RSpec/MessageExpectation:
  Enabled: false

RSpec/MultipleExpectations:
  Enabled: false

RSpec/MultipleMemoizedHelpers:
  Enabled: true
  Max: 10
  Exclude:
    - spec/requests/**/*_spec.rb
    - spec/support/shared_contexts/*.rb

RSpec/MultipleSubjects:
  Enabled: true
  Exclude:
    - spec/requests/**/*_spec.rb

RSpec/NestedGroups:
  Max: 10

RSpec/Pending:
  Enabled: true

RSpec/ScatteredSetup:
  Enabled: true
  Exclude:
    - spec/requests/**/*_spec.rb

RSpec/SharedContext:
  Enabled: true

RSpec/VariableName:
  Enabled: true
  EnforcedStyle: snake_case
  AllowedPatterns:
    - ^Accept-Language
    - ^Authorization
    - ^Cookie
    - ^Fingerprint
    - ^If-Match
    - ^User-Agent

# ─── Rails ─────────────────────────────────────────────

Rails/ActiveRecordCallbacksOrder:
  Enabled: true

Rails/AfterCommitOverride:
  Enabled: true

Rails/AttributeDefaultBlockValue:
  Enabled: true

Rails/FilePath:
  Enabled: false

Rails/FindById:
  Enabled: true

Rails/HttpPositionalArguments:
  Enabled: false

Rails/I18nLocaleTexts:
  Enabled: false

Rails/Inquiry:
  Enabled: true

Rails/MailerName:
  Enabled: true

Rails/MatchRoute:
  Enabled: true

Rails/NegateInclude:
  Enabled: true

Rails/Output:
  Enabled: true
  Exclude:
    - db/seeds/**/*
    - lib/tasks/**/*

Rails/Pluck:
  Enabled: true

Rails/PluckId:
  Enabled: true

Rails/PluckInWhere:
  Enabled: true

Rails/RenderInline:
  Enabled: true

Rails/RenderPlainText:
  Enabled: true

Rails/ShortI18n:
  Enabled: true

Rails/SkipsModelValidations:
  Enabled: true

Rails/SquishedSQLHeredocs:
  Enabled: true

Rails/WhereExists:
  Enabled: true

Rails/WhereEquals:
  Enabled: true

Rails/WhereNot:
  Enabled: true

# ─── Style ─────────────────────────────────────────────

Bundler/GemComment:
  Enabled: false

Bundler/OrderedGems:
  Enabled: true

Style/AccessorGrouping:
  Enabled: true

Style/ArgumentsForwarding:
  Enabled: true

Style/ArrayCoercion:
  Enabled: true

Style/AsciiComments:
  Enabled: true

Style/BisectedAttrAccessor:
  Enabled: true

Style/CaseLikeIf:
  Enabled: true

Style/CollectionCompact:
  Enabled: true

Style/CombinableLoops:
  Enabled: true

Style/Documentation:
  Enabled: false

Style/DocumentDynamicEvalDefinition:
  Enabled: true

Style/EndlessMethod:
  Enabled: true

Style/ExplicitBlockArgument:
  Enabled: true

Style/ExponentialNotation:
  Enabled: true

Style/FetchEnvVar:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: true
  SafeAutoCorrect: true

Style/GlobalStdStream:
  Enabled: true

Style/HashAsLastArrayItem:
  Enabled: true

Style/HashEachMethods:
  Enabled: true

Style/HashConversion:
  Enabled: true

Style/HashExcept:
  Enabled: true

Style/HashLikeCase:
  Enabled: true

Style/HashSyntax:
  Enabled: true

Style/HashTransformKeys:
  Enabled: true

Style/HashTransformValues:
  Enabled: true

Style/IfWithBooleanLiteralBranches:
  Enabled: true

Style/KeywordParametersOrder:
  Enabled: true

Style/NegatedIfElseCondition:
  Enabled: true

Style/NilLambda:
  Enabled: true

Style/NumericLiterals:
  Enabled: true

Style/OptionalBooleanParameter:
  Enabled: true

Style/RedundantArgument:
  Enabled: true

Style/RedundantAssignment:
  Enabled: true

Style/RedundantFetchBlock:
  Enabled: false

Style/RedundantFileExtensionInRequire:
  Enabled: true

Style/RedundantRegexpCharacterClass:
  Enabled: true

Style/RedundantRegexpEscape:
  Enabled: true

Style/RedundantSelfAssignment:
  Enabled: true

Style/SingleArgumentDig:
  Enabled: true

Style/SlicingWithRange:
  Enabled: true

Style/SoleNestedConditional:
  Enabled: true

Style/StringChars:
  Enabled: true

Style/StringConcatenation:
  Enabled: true

Style/StringLiterals:
  Enabled: true
  EnforcedStyle: double_quotes

Style/SwapValues:
  Enabled: true

Style/SymbolProc:
  Enabled: true

Style/TrailingCommaInArguments:
  Enabled: true
  EnforcedStyleForMultiline: consistent_comma

Style/TrailingCommaInArrayLiteral:
  Enabled: true
  EnforcedStyleForMultiline: consistent_comma

Style/TrailingCommaInHashLiteral:
  Enabled: true
  EnforcedStyleForMultiline: consistent_comma
```

---

## i18n

- **No hardcoded English anywhere.** Every user-facing string must use `I18n.t()` in Ruby and `useTranslation()` in React.
- **Keys follow a convention:** `controller.action.element` for backend, `page.section.element` for frontend.
- **See [i18n.md](i18n.md) for setup and patterns.**

---

## yamllint (YAML Linting) {#yamllint}

**Lint all YAML files** — Rails locale files (`config/locales/`) and frontend locale files (`app/frontend/locales/`). Catches syntax errors, inconsistent indentation, and trailing whitespace before they cause runtime surprises.

### Installation

```bash
brew install yamllint
```

### Configuration

```yaml
# .yamllint.yml
extends: default

rules:
  line-length: disable
  truthy:
    check-keys: false
  indentation:
    spaces: 2
  trailing-spaces: enable
  new-line-at-end-of-file: enable
  empty-lines:
    max: 1
```

### Scripts

Add to the project `Makefile` or use directly:

```bash
# Lint all locale files (backend + frontend)
yamllint config/locales/ app/frontend/locales/

# Lint a specific file
yamllint config/locales/en.yml
```

### What it catches

- **Syntax errors** — missing colons, bad indentation, duplicate keys
- **Trailing whitespace** — invisible characters that cause diffs
- **Inconsistent indentation** — enforces 2-space indent
- **Missing newline at end of file** — POSIX compliance

### Auto-formatting with Prettier

yamllint detects problems but doesn't fix them. Use **Prettier with `prettier-plugin-yaml`** to auto-format YAML files. Its defaults (2-space indent, trailing newline, consistent quoting) are aligned with the yamllint rules above.

```bash
# Format all locale YAML files
bun format

# Or target YAML specifically
bunx prettier --write 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml'
```

See the [ESLint + Prettier section in inertia-react.md](inertia-react.md#eslint--prettier) for full Prettier setup including the YAML plugin.

---

## Error Tracking (Sentry)

- **Always configure Sentry** for production error tracking.
- **Use the `Logs` module** instead of calling `Rails.logger` or `Sentry.*` directly. It tags every message and routes warnings/errors to Sentry automatically.
- **Filter sensitive params** — never send passwords, tokens, or API keys to Sentry.
- **Set user context** so errors are attributable.
- **See [sentry.md](sentry.md) for setup and the `Logs` module implementation.**

---

## General Principles

- **Naming matters more than comments.** Spend time on names. A well-named method eliminates the need for documentation.
- **Methods should do one thing.** If you're describing a method with "and" — it does too much.
- **Prefer explicit over clever.** Metaprogramming, dynamic method definitions, and dense one-liners are hard to debug and hard for the next person to understand. Write boring code.
- **Delete dead code.** Don't comment it out. Git has history.
- **Small methods, small classes, small commits.** If a method is over 15 lines, it probably does too much. If a class is over 200 lines, it has too many responsibilities.
- **Consistency over personal preference.** Follow the patterns already established in the codebase.

---

## Git Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for all commit messages.

### Format

```
type(scope): short description

Optional body explaining WHY, not WHAT.

Optional footer (e.g., BREAKING CHANGE: ...)
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature or user-facing change |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace (no logic change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Tooling, deps, config (no production code) |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |
| `build` | Build system or external deps |

### Examples

```bash
feat(auth): add Google OAuth login
fix(billing): handle expired card error gracefully
refactor(interactors): extract address validation step
test(teams): add request specs for invitation flow
chore(deps): bump rails to 8.1
docs(schema): document team_members constraints
feat(api)!: change pagination response format
```

### Rules

- Subject line under 72 characters
- Use imperative mood: "add feature" not "added feature"
- Scope is optional but encouraged — use the feature area
- Add `!` after type/scope for breaking changes
- Body for context when the "why" isn't obvious from the subject
