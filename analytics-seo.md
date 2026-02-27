# Analytics, SEO & Metadata

> Google Analytics, Search Console, meta tags, and sitemaps for Rails apps.

---

## Interview First

Ask the user:

1. **Do you have a Google Analytics account?**
   - Need the GA4 Measurement ID (G-XXXXXXXXXX)

2. **Do you have Google Search Console set up?**
   - Will need to verify domain ownership

3. **Do you have an Ahrefs account?**
   - Need the verification meta tag content value

4. **What's the site description?** (for meta tags)
   - 150-160 characters for optimal SEO

5. **What are the target keywords?**

6. **Do you have social sharing images?**
   - OG image (1200x630)
   - Twitter card image

---

## Google Analytics 4

### Setup

1. Go to https://analytics.google.com
2. Create property for your domain
3. Get Measurement ID (G-XXXXXXXXXX)
4. Add to environment variables

### Environment Variable

```bash
# .env
GA_MEASUREMENT_ID=G-XXXXXXXXXX
```

### Add to Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <!-- ... other head content ... -->

  <%# Google Analytics 4 %>
  <% if ENV['GA_MEASUREMENT_ID'].present? %>
    <script async src="https://www.googletagmanager.com/gtag/js?id=<%= ENV['GA_MEASUREMENT_ID'] %>"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', '<%= ENV['GA_MEASUREMENT_ID'] %>');
    </script>
  <% end %>
</head>
```

---

## Google Search Console

### Setup

1. Go to https://search.google.com/search-console
2. Add property (use URL prefix method)
3. Verify ownership via:
   - HTML file upload (easiest)
   - DNS record
   - Google Analytics (if already set up)

### HTML File Verification

Download the verification file and place in `public/`:

```
public/google[VERIFICATION_CODE].html
```

### Submit Sitemap

After verification:
1. Go to Sitemaps in Search Console
2. Submit: `https://yourdomain.com/sitemap.xml`

---

## Ahrefs Verification

### Setup

1. Go to https://ahrefs.com → Site Audit / Site Explorer
2. Add your domain
3. Choose "HTML tag" verification method
4. Copy the content value from the meta tag

### Environment Variable

```bash
# .env
AHREFS_VERIFICATION=ahrefs-site-verification_xxxxxxxxxxxx
```

### Add to Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <%# Ahrefs Verification %>
  <% if ENV['AHREFS_VERIFICATION'].present? %>
    <meta name="ahrefs-site-verification" content="<%= ENV['AHREFS_VERIFICATION'] %>">
  <% end %>
</head>
```

---

## Meta Tags

### Default Meta Tags in Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <%# Default SEO meta tags - overridden by Inertia Head per page %>
  <meta name="description" content="[DEFAULT_DESCRIPTION]">
  <meta name="keywords" content="[keyword1], [keyword2], [keyword3]">
  <meta name="author" content="[APP_NAME]">

  <%# Open Graph %>
  <meta property="og:site_name" content="[APP_NAME]">
  <meta property="og:type" content="website">
  <meta property="og:image" content="<%= request.base_url %>/og-image.jpg">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">

  <%# Twitter Card %>
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@[TWITTER_HANDLE]">
  <meta name="twitter:image" content="<%= request.base_url %>/og-image.jpg">

  <%# Canonical URL %>
  <link rel="canonical" href="<%= request.original_url.split('?').first %>">
</head>
```

### Per-Page Meta Tags (Inertia)

```jsx
// In any page component
import { Head } from "@inertiajs/react"

export default function IdeaShow({ idea }) {
  return (
    <>
      <Head>
        <title>{idea.name} | AppName</title>
        <meta name="description" content={idea.one_liner} />
        <meta property="og:title" content={idea.name} />
        <meta property="og:description" content={idea.one_liner} />
      </Head>

      {/* Page content */}
    </>
  )
}
```

---

## Sitemap

### Using sitemap_generator Gem

```ruby
# Gemfile
gem 'sitemap_generator'
```

```bash
bundle install
rails sitemap:install
```

### Configure Sitemap

```ruby
# config/sitemap.rb
SitemapGenerator::Sitemap.default_host = "https://yourdomain.com"

SitemapGenerator::Sitemap.create do
  # Static pages
  add root_path, changefreq: 'daily', priority: 1.0
  add pricing_path, changefreq: 'weekly', priority: 0.8
  add privacy_path, changefreq: 'monthly', priority: 0.3
  add terms_path, changefreq: 'monthly', priority: 0.3

  # Dynamic pages (e.g., ideas)
  Idea.published.find_each do |idea|
    add idea_path(idea), lastmod: idea.updated_at, priority: 0.7
  end
end
```

### Generate Sitemap

```bash
# Development
rails sitemap:refresh:no_ping

# Production (run via scheduler)
rails sitemap:refresh
```

### Serve Sitemap

Option 1: Static file in public/

```ruby
# config/sitemap.rb
SitemapGenerator::Sitemap.public_path = 'public/'
SitemapGenerator::Sitemap.sitemaps_path = ''
```

Option 2: Controller (for dynamic generation)

```ruby
# config/routes.rb
get 'sitemap.xml', to: 'sitemaps#show', defaults: { format: 'xml' }
```

---

## robots.txt

Create `public/robots.txt`:

```
User-agent: *
Allow: /

Sitemap: https://yourdomain.com/sitemap.xml

# Disallow admin/private areas
Disallow: /admin/
Disallow: /api/
```

---

## JSON-LD Structured Data

Add to layout for rich search results:

```erb
<%# JSON-LD Organization Schema %>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "[APP_NAME]",
  "description": "[DESCRIPTION]",
  "url": "<%= root_url %>",
  "potentialAction": {
    "@type": "SearchAction",
    "target": "<%= search_url %>?q={search_term_string}",
    "query-input": "required name=search_term_string"
  }
}
</script>
```

---

## Environment Variables Summary

```bash
# .env
GA_MEASUREMENT_ID=G-XXXXXXXXXX
AHREFS_VERIFICATION=ahrefs-site-verification_xxxxxxxxxxxx

# For sitemap generation in production
RAILS_HOST=yourdomain.com
```

---

## Checklist

- [ ] Google Analytics 4 installed
- [ ] Google Search Console verified
- [ ] Ahrefs verified
- [ ] Sitemap generated and submitted
- [ ] robots.txt in place
- [ ] Default meta tags in layout
- [ ] OG image created (1200x630)
- [ ] Per-page meta tags for key pages
- [ ] Canonical URLs set
- [ ] JSON-LD schema added
