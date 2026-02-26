# Solid Stack - Single Database Setup

> Configure Solid Queue, Solid Cache, and Solid Cable to use the primary database (no separate databases).

---

## Overview

Rails includes Solid Queue, Solid Cache, and Solid Cable. By default, they want separate databases. **We use a single database** for simplicity and smaller apps.

---

## Step 1: Consolidated Migration

Create a single migration for all Solid* tables. This replaces the separate schema files.

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_solid_tables.rb

class CreateSolidTables < ActiveRecord::Migration[x.x]
  def change
    # ─────────────────────────────────────────────────────────────
    # Solid Cache
    # ─────────────────────────────────────────────────────────────
    create_table "solid_cache_entries", force: :cascade do |t|
      t.binary "key", limit: 1024, null: false
      t.binary "value", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "key_hash", limit: 8, null: false
      t.integer "byte_size", limit: 4, null: false
      t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
      t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
    end

    # ─────────────────────────────────────────────────────────────
    # Solid Cable
    # ─────────────────────────────────────────────────────────────
    create_table "solid_cable_messages", force: :cascade do |t|
      t.binary "channel", limit: 1024, null: false
      t.binary "payload", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "channel_hash", limit: 8, null: false
      t.index ["channel"], name: "index_solid_cable_messages_on_channel"
      t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
      t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
    end

    # ─────────────────────────────────────────────────────────────
    # Solid Queue
    # ─────────────────────────────────────────────────────────────
    create_table "solid_queue_blocked_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.string "concurrency_key", null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
      t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
    end

    create_table "solid_queue_claimed_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.bigint "process_id"
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
      t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
    end

    create_table "solid_queue_failed_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.text "error"
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
    end

    create_table "solid_queue_jobs", force: :cascade do |t|
      t.string "queue_name", null: false
      t.string "class_name", null: false
      t.text "arguments"
      t.integer "priority", default: 0, null: false
      t.string "active_job_id"
      t.datetime "scheduled_at"
      t.datetime "finished_at"
      t.string "concurrency_key"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
      t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
      t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
      t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
      t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
    end

    create_table "solid_queue_pauses", force: :cascade do |t|
      t.string "queue_name", null: false
      t.datetime "created_at", null: false
      t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
    end

    create_table "solid_queue_processes", force: :cascade do |t|
      t.string "kind", null: false
      t.datetime "last_heartbeat_at", null: false
      t.bigint "supervisor_id"
      t.integer "pid", null: false
      t.string "hostname"
      t.text "metadata"
      t.datetime "created_at", null: false
      t.string "name", null: false
      t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
      t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
      t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
    end

    create_table "solid_queue_ready_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
      t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
      t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
    end

    create_table "solid_queue_recurring_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "task_key", null: false
      t.datetime "run_at", null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
      t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
    end

    create_table "solid_queue_recurring_tasks", force: :cascade do |t|
      t.string "key", null: false
      t.string "schedule", null: false
      t.string "command", limit: 2048
      t.string "class_name"
      t.text "arguments"
      t.string "queue_name"
      t.integer "priority", default: 0
      t.boolean "static", default: true, null: false
      t.text "description"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
      t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
    end

    create_table "solid_queue_scheduled_executions", force: :cascade do |t|
      t.bigint "job_id", null: false
      t.string "queue_name", null: false
      t.integer "priority", default: 0, null: false
      t.datetime "scheduled_at", null: false
      t.datetime "created_at", null: false
      t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
      t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
    end

    create_table "solid_queue_semaphores", force: :cascade do |t|
      t.string "key", null: false
      t.integer "value", default: 1, null: false
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
      t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
    end

    # ─────────────────────────────────────────────────────────────
    # Foreign Keys
    # ─────────────────────────────────────────────────────────────
    add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
    add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  end
end
```

---

## Step 2: Remove Separate Schema Files

Delete these files if they exist (we're using the migration instead):

```bash
rm -f db/queue_schema.rb
rm -f db/cache_schema.rb
rm -f db/cable_schema.rb
```

---

## Step 3: Initializers (Single Database)

### config/initializers/solid_queue.rb

```ruby
# Configure Solid Queue to use primary database
Rails.application.configure do
  config.solid_queue.connects_to = { database: { writing: :primary } }
end
```

### config/initializers/solid_cache.rb

```ruby
# Configure Solid Cache to use primary database
Rails.application.configure do
  config.solid_cache.connects_to = { database: { writing: :primary } }
end
```

### config/initializers/solid_cable.rb

```ruby
# Configure Solid Cable to use primary database
Rails.application.configure do
  config.solid_cable.connects_to = { database: { writing: :primary } }
end
```

---

## Step 4: config/cable.yml

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
  # No connects_to needed - uses initializer config
```

---

## Step 5: config/database.yml

Single database only - no separate queue/cache/cable databases:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: <%= ENV.fetch("APP_NAME", "myapp") %>_development

test:
  <<: *default
  database: <%= ENV.fetch("APP_NAME", "myapp") %>_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

---

## Step 6: config/application.rb

```ruby
# Set Solid Queue as Active Job adapter
config.active_job.queue_adapter = :solid_queue
```

---

## Step 7: Run Migration

```bash
bin/rails db:migrate
```

---

## Verification

After setup, verify everything works:

```bash
# Check tables exist
bin/rails runner "puts SolidQueue::Job.table_name"
bin/rails runner "puts SolidCache::Entry.table_name"
bin/rails runner "puts SolidCable::Message.table_name"

# Test a job
bin/rails runner "TestJob.perform_later"
bin/rails jobs:work  # Should process the job
```

---

## Deployment Considerations

- Single database = simpler setup (one PostgreSQL instance on Hetzner)
- Works well for apps with moderate job/cache load
- If you outgrow it, can migrate to separate databases later
- Use `kamal app exec "bin/rails db:migrate"` for migrations
