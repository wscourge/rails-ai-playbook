# Solid Stack - Separate Databases (Rails Default)

> Configure Solid Queue, Solid Cache, and Solid Cable using the default Rails approach with separate databases.

---

## Overview

Rails includes Solid Queue, Solid Cache, and Solid Cable. By default, each gets its own database. **We use this default setup** — each Solid library manages its own schema via the bundled schema files.

---

## Step 1: config/database.yml

Add the queue, cache, and cable databases alongside your primary database:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  primary:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_development
  queue:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_queue_development
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_cache_development
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_cable_development
    migrations_paths: db/cable_migrate

test:
  primary:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_test
  queue:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_queue_test
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_cache_test
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    database: <%= ENV.fetch("APP_NAME", "myapp") %>_cable_test
    migrations_paths: db/cable_migrate

production:
  primary:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
  queue:
    <<: *default
    url: <%= ENV["QUEUE_DATABASE_URL"] %>
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    url: <%= ENV["CACHE_DATABASE_URL"] %>
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    url: <%= ENV["CABLE_DATABASE_URL"] %>
    migrations_paths: db/cable_migrate
```

---

## Step 2: Schema Files

Rails ships with schema files for each Solid library. These are used automatically when you run `db:prepare`. Ensure these files exist (they come from the gems):

- `db/queue_schema.rb` — Solid Queue tables
- `db/cache_schema.rb` — Solid Cache tables
- `db/cable_schema.rb` — Solid Cable tables

If they don't exist after installing the gems, generate them:

```bash
bin/rails solid_queue:install
bin/rails solid_cache:install
bin/rails solid_cable:install
```

---

## Step 3: config/cable.yml

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

---

## Step 3.5: config/queue.yml

Configure worker threads, processes, and polling intervals:

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

---

## Step 3.6: config/cache.yml

Configure cache size and expiration:

```yaml
default: &default
  store_options:
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

---

## Step 3.7: config/recurring.yml (Scheduled Jobs)

Schedule recurring jobs like cleanup tasks:

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  # Add more scheduled jobs as needed:
  # daily_report:
  #   class: DailyReportJob
  #   schedule: every day at 9am
```

This prevents the `solid_queue_jobs` table from growing indefinitely.

---

## Step 4: config/application.rb

```ruby
# Set Solid Queue as Active Job adapter
config.active_job.queue_adapter = :solid_queue
```

---

## Step 4.5: Development Environment (Optional)

For faster development without running a separate worker process, use the async adapter in development:

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :async
config.cache_store = :memory_store
```

Jobs execute inline in the same process. When you need to test real background job behavior, switch back to `:solid_queue` and run `bin/jobs`.

---

## Step 5: Create & Migrate All Databases

```bash
bin/rails db:create
bin/rails db:prepare
```

This creates all four databases (primary + queue + cache + cable) and loads the appropriate schemas.

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
bin/jobs  # Should process the job
```

---

## bin/jobs Wrapper

Create a simple wrapper script for running the worker:

```bash
#!/usr/bin/env ruby
# bin/jobs
exec "bundle", "exec", "rails", "solid_queue:work"
```

Make it executable: `chmod +x bin/jobs`

---

## Environment Variables

In production, you need a `DATABASE_URL` for each database:

```
DATABASE_URL=postgresql://user:pass@host:5432/myapp_production
QUEUE_DATABASE_URL=postgresql://user:pass@host:5432/myapp_queue_production
CACHE_DATABASE_URL=postgresql://user:pass@host:5432/myapp_cache_production
CABLE_DATABASE_URL=postgresql://user:pass@host:5432/myapp_cable_production

# Optional: Scale worker processes (default: 1)
JOB_CONCURRENCY=2
```

See [env-template.md](env-template.md) for the full list.

---

## Deployment Considerations

- Separate databases keep Solid tables isolated from application data
- All four databases can live on the same PostgreSQL instance
- Use `kamal app exec "bin/rails db:prepare"` for migrations
- If you want to simplify later, you can consolidate to a single database by pointing all `connects_to` to `:primary`
