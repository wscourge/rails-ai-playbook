# Search — pg_search

> Full-text search using PostgreSQL's built-in capabilities via the pg_search gem.
> No external search services (Elasticsearch, Meilisearch) — keep it simple with what PostgreSQL already provides.

---

## Why pg_search

- Zero infrastructure overhead — PostgreSQL handles it
- Supports ranked results, prefix matching, accent/case insensitivity
- `tsvector` columns + GIN indexes make it fast
- Scopes compose naturally with ActiveRecord

---

## Installation

### Gemfile

```ruby
gem "pg_search"
```

```bash
bundle install
```

---

## Model Setup

### Include the module

```ruby
class Article < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search,
    against: {
      title: "A",
      body: "B"
    },
    using: {
      tsearch: {
        prefix: true,
        dictionary: "english",
        tsvector_column: "searchable"
      }
    }
end
```

**Weight convention:** Use PostgreSQL weights to rank column importance:
- `A` — primary field (title, name)
- `B` — secondary field (body, description)
- `C` — tertiary field (tags, metadata)
- `D` — lowest priority

### Associated models

When you need to search across associations:

```ruby
class Article < ApplicationRecord
  include PgSearch::Model

  belongs_to :author

  pg_search_scope :search,
    against: {
      title: "A",
      body: "B"
    },
    associated_against: {
      author: { name: "C" }
    },
    using: {
      tsearch: {
        prefix: true,
        dictionary: "english",
        tsvector_column: "searchable"
      }
    }
end
```

> **Note:** Associated search skips the `tsvector_column` optimization for the associated model's fields — those are computed at query time. Only use `associated_against` when genuinely needed.

---

## Migration — tsvector Column + GIN Index

Every searchable model gets a dedicated `tsvector` column and a GIN index. This avoids recomputing the vector on every query.

```ruby
class AddSearchableToArticles < ActiveRecord::Migration[x.x]
  def up
    add_column :articles, :searchable, :tsvector

    add_index :articles, :searchable, using: :gin

    execute <<-SQL
      UPDATE articles SET searchable =
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    SQL
  end

  def down
    remove_index :articles, :searchable
    remove_column :articles, :searchable
  end
end
```

---

## Keeping the tsvector Column Updated

Use a database trigger to keep the `searchable` column in sync automatically. This is more reliable than callbacks.

### Migration for the trigger

```ruby
class AddSearchableTriggerToArticles < ActiveRecord::Migration[x.x]
  def up
    execute <<-SQL
      CREATE FUNCTION articles_searchable_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.searchable :=
          setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.body, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER articles_searchable_update
        BEFORE INSERT OR UPDATE OF title, body
        ON articles
        FOR EACH ROW
        EXECUTE FUNCTION articles_searchable_trigger();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS articles_searchable_update ON articles;
      DROP FUNCTION IF EXISTS articles_searchable_trigger();
    SQL
  end
end
```

> **Why triggers over callbacks?** Triggers run at the database level — no ActiveRecord bypass risk, no forgotten callback, works with bulk updates and raw SQL.

---

## Interactor Pattern

Search always goes through an interactor. The controller stays thin.

### SearchArticles interactor

```ruby
class SearchArticles
  include Interactor

  def call
    query = context.query&.strip

    if query.blank?
      context.articles = Article.none
      return
    end

    context.articles = Article
      .search(query)
      .limit(context.limit || 25)
  end
end
```

### Controller

```ruby
class ArticlesController < ApplicationController
  def index
    result = SearchArticles.call(
      query: params[:q],
      limit: 25
    )

    render inertia: "Articles/Index", props: {
      articles: result.articles.map { |a| ArticleSerializer.new(a).as_json },
      query: params[:q]
    }
  end
end
```

### When listing + searching share a page

If the index page shows all records when there's no query and filters when there is:

```ruby
class ListArticles
  include Interactor

  def call
    scope = Article.all

    if context.query.present?
      scope = scope.search(context.query)
    end

    scope = scope.order(created_at: :desc) unless context.query.present?

    context.articles = scope.page(context.page).per(25)
  end
end
```

> **Note:** Don't apply `.order` when searching — pg_search already orders by rank. Adding `.order` overrides the relevance sorting.

---

## Frontend — Search Input

Use a debounced input that sends the query as a URL parameter via Inertia:

```tsx
import { useState, useCallback } from "react";
import { router } from "@inertiajs/react";
import { Input } from "@/components/ui/input";
import { useTranslation } from "react-i18next";
import { SearchIcon } from "@/components/icons";
import { useDebouncedCallback } from "use-debounce";

interface SearchInputProps {
  defaultValue?: string;
  route: string;
  placeholder?: string;
}

export function SearchInput({ defaultValue = "", route, placeholder }: SearchInputProps) {
  const { t } = useTranslation();
  const [value, setValue] = useState(defaultValue);

  const debouncedSearch = useDebouncedCallback((q: string) => {
    router.get(route, { q: q || undefined }, {
      preserveState: true,
      preserveScroll: true,
      replace: true,
    });
  }, 300);

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const q = e.target.value;
    setValue(q);
    debouncedSearch(q);
  }, [debouncedSearch]);

  return (
    <div className="relative">
      <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
      <Input
        type="search"
        value={value}
        onChange={handleChange}
        placeholder={placeholder ?? t("common.search")}
        className="pl-9"
      />
    </div>
  );
}
```

### Usage on a page

```tsx
<SearchInput defaultValue={query} route="/articles" />
```

### Dependency

```bash
bun add use-debounce
```

---

## i18n Keys

Add to the common namespace:

```yaml
# app/frontend/locales/en/common.yml (merge with existing)
common:
  search: Search…
  noResults: No results found
  searchResultsCount_one: "{{count}} result"
  searchResultsCount_other: "{{count}} results"
```

---

## Multi-model Search (Global Search)

For searching across multiple models (e.g., a global search bar), use `PgSearch.multisearch`:

### Enable multisearch

```ruby
# config/initializers/pg_search.rb
PgSearch.multisearch_options = {
  using: {
    tsearch: {
      prefix: true,
      dictionary: "english"
    }
  }
}
```

### Migration

```bash
rails g pg_search:migration:multisearch
rails db:migrate
```

### Models opt in

```ruby
class Article < ApplicationRecord
  include PgSearch::Model
  multisearchable against: [:title, :body]
end

class Product < ApplicationRecord
  include PgSearch::Model
  multisearchable against: [:name, :description]
end
```

### Global search interactor

```ruby
class GlobalSearch
  include Interactor

  def call
    query = context.query&.strip

    if query.blank?
      context.results = []
      return
    end

    context.results = PgSearch.multisearch(query)
      .includes(:searchable)
      .limit(context.limit || 10)
      .map do |doc|
        {
          type: doc.searchable_type.underscore,
          id: doc.searchable_id,
          title: doc.content,
          url: url_for_searchable(doc.searchable)
        }
      end
  end

  private

  def url_for_searchable(record)
    case record
    when Article then "/articles/#{record.id}"
    when Product then "/products/#{record.id}"
    end
  end
end
```

> **Use multisearch sparingly.** Single-model search with `pg_search_scope` is faster and simpler. Only add multisearch when you genuinely need a global search bar across models.

---

## Testing

### Model spec

```ruby
RSpec.describe Article do
  describe ".search" do
    let!(:ruby_article) { create(:article, title: "Ruby on Rails Guide", body: "Learn Rails") }
    let!(:python_article) { create(:article, title: "Python Tutorial", body: "Learn Python") }

    it "finds matching articles" do
      results = described_class.search("rails")
      expect(results).to include(ruby_article)
      expect(results).not_to include(python_article)
    end

    it "supports prefix matching" do
      results = described_class.search("rai")
      expect(results).to include(ruby_article)
    end

    it "returns empty for blank query" do
      # pg_search raises on blank — interactor handles this
      expect(described_class.search("something")).to be_a(ActiveRecord::Relation)
    end
  end
end
```

### Interactor spec

```ruby
RSpec.describe SearchArticles do
  describe ".call" do
    let!(:article) { create(:article, title: "Testing pg_search") }

    it "returns matching articles" do
      result = described_class.call(query: "testing")
      expect(result.articles).to include(article)
    end

    it "returns none for blank query" do
      result = described_class.call(query: "")
      expect(result.articles).to be_empty
    end

    it "respects limit" do
      create_list(:article, 5, title: "Bulk item")
      result = described_class.call(query: "bulk", limit: 3)
      expect(result.articles.size).to eq(3)
    end
  end
end
```

---

## Key Rules

1. **Always use a `tsvector` column + GIN index.** Never rely on query-time tsvector generation in production — it's slow on large tables.
2. **Use database triggers to update the `tsvector` column.** More reliable than ActiveRecord callbacks.
3. **Search goes through interactors.** Controllers don't call `pg_search_scope` directly.
4. **Don't apply `.order` to search results.** pg_search orders by relevance rank. Adding `.order` overrides this.
5. **Debounce frontend search input.** 300ms is a good default — prevents hammering the server on every keystroke.
6. **Guard against blank queries.** pg_search raises on empty strings. The interactor should return `.none` for blank input.
7. **Prefer single-model `pg_search_scope` over multisearch.** Only use `PgSearch.multisearch` for genuine cross-model global search.
8. **Weights communicate intent.** Title/name = `A`, body/description = `B`, tags/metadata = `C`.
9. **Use `prefix: true` for autocomplete-style search.** Lets "rai" match "rails".
10. **Use `dictionary: "english"` for stemming.** Lets "running" match "run". Adjust for your app's language.
