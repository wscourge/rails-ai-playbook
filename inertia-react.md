# Inertia + React + Vite

> Frontend setup patterns for Rails + Inertia + React + Tailwind + shadcn/ui.

---

## Stack Overview

| Layer | Technology |
|-------|------------|
| Build | Vite |
| SPA Bridge | Inertia.js |
| UI Framework | React |
| Styling | Tailwind CSS v4 |
| Components | shadcn/ui |
| Icons | Lucide React |
| Validation | Zod |
| CSS Linting | Stylelint |
| Package Manager | Bun |
| i18n | react-i18next |

---

## Project Structure

```
app/frontend/
├── entrypoints/
│   ├── application.js       # Turbo + Stimulus (if needed)
│   ├── application.css      # Tailwind @theme tokens
│   └── inertia.jsx          # Inertia app setup
├── pages/
│   ├── Home.jsx             # Landing page
│   ├── Pricing.jsx          # Pricing page
│   ├── Auth/
│   │   ├── Login.jsx
│   │   └── Signup.jsx
│   └── App/
│       ├── Dashboard.jsx
│       └── Settings.jsx
├── components/
│   ├── ui/                  # shadcn/ui components (all installed)
│   ├── icons/               # Icon wrappers (one per icon)
│   │   ├── close.tsx
│   │   ├── plus.tsx
│   │   ├── check.tsx
│   │   └── ...              # Every icon used in the app
│   ├── ThemeProvider.tsx     # Light/dark/system theme context
│   ├── ThemeToggle.tsx       # Theme switcher dropdown
│   ├── marketing/           # Landing page components
│   ├── app/                 # App-specific components
│   └── ErrorBoundary.jsx    # Error handling
├── layout/
│   └── AppLayout.jsx        # Authenticated shell
└── lib/
    ├── utils.js             # cn() helper
    └── hooks/
        └── useFlashToasts.ts # Rails flash → Sonner toasts
```

---

## Tailwind Setup

### application.css

```css
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

@theme {
  --radius: 1rem;

  /* Typography - customize per project */
  --font-heading: "Inter", ui-sans-serif, system-ui, sans-serif;
  --font-body: "Inter", ui-sans-serif, system-ui, sans-serif;

  /* Colors — light mode values (via CSS variables) */
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-sidebar-background: var(--sidebar-background);
  --color-sidebar-foreground: var(--sidebar-foreground);
  --color-sidebar-primary: var(--sidebar-primary);
  --color-sidebar-primary-foreground: var(--sidebar-primary-foreground);
  --color-sidebar-accent: var(--sidebar-accent);
  --color-sidebar-accent-foreground: var(--sidebar-accent-foreground);
  --color-sidebar-border: var(--sidebar-border);
  --color-sidebar-ring: var(--sidebar-ring);
}

/*
 * Light / dark palette — customize per project.
 * These are the default shadcn "slate" base colors.
 * Replace the hsl() values after the brand interview.
 */
:root {
  --background: hsl(0 0% 100%);
  --foreground: hsl(222.2 84% 4.9%);
  --card: hsl(0 0% 100%);
  --card-foreground: hsl(222.2 84% 4.9%);
  --popover: hsl(0 0% 100%);
  --popover-foreground: hsl(222.2 84% 4.9%);
  --primary: hsl(222.2 47.4% 11.2%);
  --primary-foreground: hsl(210 40% 98%);
  --secondary: hsl(210 40% 96.1%);
  --secondary-foreground: hsl(222.2 47.4% 11.2%);
  --muted: hsl(210 40% 96.1%);
  --muted-foreground: hsl(215.4 16.3% 46.9%);
  --accent: hsl(210 40% 96.1%);
  --accent-foreground: hsl(222.2 47.4% 11.2%);
  --destructive: hsl(0 84.2% 60.2%);
  --destructive-foreground: hsl(210 40% 98%);
  --border: hsl(214.3 31.8% 91.4%);
  --input: hsl(214.3 31.8% 91.4%);
  --ring: hsl(222.2 84% 4.9%);
  --sidebar-background: hsl(0 0% 98%);
  --sidebar-foreground: hsl(240 5.3% 26.1%);
  --sidebar-primary: hsl(240 5.9% 10%);
  --sidebar-primary-foreground: hsl(0 0% 98%);
  --sidebar-accent: hsl(240 4.8% 95.9%);
  --sidebar-accent-foreground: hsl(240 5.9% 10%);
  --sidebar-border: hsl(220 13% 91%);
  --sidebar-ring: hsl(217.2 91.2% 59.8%);
}

.dark {
  --background: hsl(222.2 84% 4.9%);
  --foreground: hsl(210 40% 98%);
  --card: hsl(222.2 84% 4.9%);
  --card-foreground: hsl(210 40% 98%);
  --popover: hsl(222.2 84% 4.9%);
  --popover-foreground: hsl(210 40% 98%);
  --primary: hsl(210 40% 98%);
  --primary-foreground: hsl(222.2 47.4% 11.2%);
  --secondary: hsl(217.2 32.6% 17.5%);
  --secondary-foreground: hsl(210 40% 98%);
  --muted: hsl(217.2 32.6% 17.5%);
  --muted-foreground: hsl(215 20.2% 65.1%);
  --accent: hsl(217.2 32.6% 17.5%);
  --accent-foreground: hsl(210 40% 98%);
  --destructive: hsl(0 62.8% 30.6%);
  --destructive-foreground: hsl(210 40% 98%);
  --border: hsl(217.2 32.6% 17.5%);
  --input: hsl(217.2 32.6% 17.5%);
  --ring: hsl(212.7 26.8% 83.9%);
  --sidebar-background: hsl(240 5.9% 10%);
  --sidebar-foreground: hsl(240 4.8% 95.9%);
  --sidebar-primary: hsl(224.3 76.3% 48%);
  --sidebar-primary-foreground: hsl(0 0% 100%);
  --sidebar-accent: hsl(240 3.7% 15.9%);
  --sidebar-accent-foreground: hsl(240 4.8% 95.9%);
  --sidebar-border: hsl(240 3.7% 15.9%);
  --sidebar-ring: hsl(217.2 91.2% 59.8%);
}

@layer base {
  * { @apply border-border; }
  html, body { height: 100%; }
  body {
    @apply bg-background text-foreground antialiased font-body;
  }
  h1, h2, h3, h4, h5, h6 {
    @apply font-heading;
  }
  .container { @apply max-w-[1200px] mx-auto px-6 md:px-8; }
}

.section-py { @apply py-16 md:py-24; }
```

---

## Dark Mode (System Default)

**Always support light, dark, and system themes.** System is the default — the app follows `prefers-color-scheme` until the user explicitly picks a theme. The choice is persisted in `localStorage`.

### ThemeProvider

```tsx
// app/frontend/components/ThemeProvider.tsx
import { createContext, useContext, useEffect, useState } from "react";

type Theme = "light" | "dark" | "system";

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextType>({
  theme: "system",
  setTheme: () => {},
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === "undefined") return "system";
    return (localStorage.getItem("theme") as Theme) || "system";
  });

  const applyTheme = (t: Theme) => {
    const root = document.documentElement;
    const isDark =
      t === "dark" ||
      (t === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);

    root.classList.toggle("dark", isDark);
  };

  const setTheme = (t: Theme) => {
    setThemeState(t);
    localStorage.setItem("theme", t);
    applyTheme(t);
  };

  useEffect(() => {
    applyTheme(theme);

    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => {
      if (theme === "system") applyTheme("system");
    };
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
```

### Wrap the Inertia App

```tsx
// app/frontend/entrypoints/inertia.jsx
import { ThemeProvider } from "@/components/ThemeProvider";
import { Toaster } from "@/components/ui/sonner";

createInertiaApp({
  // ...
  setup({ el, App, props }) {
    createRoot(el).render(
      <ThemeProvider>
        <App {...props} />
        <Toaster richColors closeButton position="top-right" />
      </ThemeProvider>
    );
  },
});
```

### Prevent Flash of Wrong Theme

Add an inline script in the HTML head so the class is set before React hydrates:

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <script>
    (function() {
      var t = localStorage.getItem('theme') || 'system';
      var d = t === 'dark' || (t === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
      if (d) document.documentElement.classList.add('dark');
    })();
  </script>
</head>
```

### Theme Toggle Component

```tsx
// app/frontend/components/ThemeToggle.tsx
import { useTheme } from "@/components/ThemeProvider";
import { useTranslation } from "react-i18next";
import { IconSun } from "@/components/icons/sun";
import { IconMoon } from "@/components/icons/moon";
import { IconMonitor } from "@/components/icons/monitor";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const { t } = useTranslation();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label={t("theme.toggle")}>
          <IconSun className="h-4 w-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <IconMoon className="absolute h-4 w-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme("light")}>
          <IconSun className="mr-2 h-4 w-4" />
          {t("theme.light")}
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("dark")}>
          <IconMoon className="mr-2 h-4 w-4" />
          {t("theme.dark")}
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("system")}>
          <IconMonitor className="mr-2 h-4 w-4" />
          {t("theme.system")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

### Icon Wrappers for Theme

```tsx
// app/frontend/components/icons/sun.tsx
export { Sun as IconSun } from 'lucide-react';
export { Sun as default } from 'lucide-react';

// app/frontend/components/icons/moon.tsx
export { Moon as IconMoon } from 'lucide-react';
export { Moon as default } from 'lucide-react';

// app/frontend/components/icons/monitor.tsx
export { Monitor as IconMonitor } from 'lucide-react';
export { Monitor as default } from 'lucide-react';
```

### i18n Keys

```json
{
  "theme": {
    "toggle": "Toggle theme",
    "light": "Light",
    "dark": "Dark",
    "system": "System"
  }
}
```

### Usage in Layouts

Add `<ThemeToggle />` in the app header, typically next to the user menu:

```jsx
<header className="bg-background border-b">
  <div className="container h-14 flex items-center justify-between">
    <Link href={routes.app} className="font-semibold">
      AppName
    </Link>
    <div className="flex items-center gap-2">
      <ThemeToggle />
      {/* ... user menu */}
    </div>
  </div>
</header>
```

---

## Shared Data (Inertia)

### Rails Controller

```ruby
# app/controllers/application_controller.rb

class ApplicationController < ActionController::Base
  include InertiaRails::Controller

  inertia_share flash: -> { flash.to_hash },
                auth: -> {
                  {
                    user: Current.user ? {
                      id: Current.user.id,
                      email: Current.user.email_address,
                      handle: Current.user.handle,
                      first_name: Current.user.first_name,
                      last_name: Current.user.last_name,
                      full_name: Current.user.full_name,
                      initials: Current.user.initials,
                      plan_name: Current.user.plan_name,
                      email_verified: Current.user.email_verified?
                    } : nil,
                    authenticated: !!Current.user
                  }
                },
                routes: -> {
                  {
                    home: root_path,
                    login: login_path,
                    signup: sign_up_path,
                    logout: Current.user ? sign_out_path : nil,
                    pricing: pricing_path,
                    app: Current.user ? "/app" : nil,
                    settings: Current.user ? settings_path : nil,
                    billing_portal: Current.user ? "/billing/portal" : nil,
                    subscribe: subscribe_path
                  }
                }
end
```

### React Access

```jsx
import { usePage } from "@inertiajs/react";

function MyComponent() {
  const { auth, routes, flash } = usePage().props;

  // auth.user - current user or null
  // auth.authenticated - boolean
  // routes.* - named routes
  // flash.notice / flash.alert - flash messages

  return (
    <div>
      {auth.authenticated ? (
        <p>Welcome, {auth.user.first_name}!</p>
      ) : (
        <Link href={routes.login}>Log in</Link>
      )}
    </div>
  );
}
```

---

## Navigation

### Internal Links (Inertia)

```jsx
import { Link } from "@inertiajs/react";

// Always use shared routes
function Nav() {
  const { routes } = usePage().props;

  return (
    <nav>
      <Link href={routes.home}>Home</Link>
      <Link href={routes.pricing}>Pricing</Link>
      <Link href={routes.app}>Dashboard</Link>
    </nav>
  );
}
```

### Form Submissions

```jsx
import { useForm } from "@inertiajs/react";
import { useTranslation } from "react-i18next";
import { validateContactForm } from "@/lib/validators";

function ContactForm() {
  const { routes } = usePage().props;
  const { t } = useTranslation();
  const { data, setData, post, processing, errors: serverErrors } = useForm({
    name: "",
    email: "",
    message: ""
  });
  const [clientErrors, setClientErrors] = useState({});

  const handleSubmit = (e) => {
    e.preventDefault();

    // Validate on frontend first — don't send invalid data
    const validation = validateContactForm(data);
    if (!validation.success) {
      setClientErrors(validation.errors);
      return;
    }

    setClientErrors({});
    post(routes.contact);
  };

  const displayErrors = { ...clientErrors, ...serverErrors };

  return (
    <form onSubmit={handleSubmit}>
      <Input
        value={data.name}
        onChange={e => setData("name", e.target.value)}
        error={displayErrors.name}
      />
      <Button type="submit" disabled={processing}>
        {processing ? t("common.sending") : t("contact.send")}
      </Button>
    </form>
  );
}
```

---

## Frontend Validation (Zod) {#frontend-validation}

**Always validate forms client-side before submitting to the backend.** Show errors instantly without a server round-trip. The backend still validates independently (defense in depth), but the frontend should catch obvious issues first.

### Installation

```bash
bun add zod
```

### Validation Schemas

```ts
// app/frontend/lib/validators.ts
import { z } from "zod";
import i18n from "@/lib/i18n";

export const contactFormSchema = z.object({
  name: z.string().min(1, () => i18n.t("validation.name_required")),
  email: z.string().min(1, () => i18n.t("validation.email_required")).email(() => i18n.t("validation.email_invalid")),
  message: z.string().min(10, () => i18n.t("validation.message_too_short")),
});

export const signupFormSchema = z.object({
  email: z.string().min(1, () => i18n.t("validation.email_required")).email(() => i18n.t("validation.email_invalid")),
  password: z.string().min(8, () => i18n.t("validation.password_too_short")),
  name: z.string().min(1, () => i18n.t("validation.name_required")),
});

// Helper: run validation and return { success, errors } object
export function validate<T>(schema: z.ZodSchema<T>, data: unknown) {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data, errors: {} };
  }

  const errors: Record<string, string> = {};
  for (const issue of result.error.issues) {
    const key = issue.path.join(".");
    if (!errors[key]) errors[key] = issue.message;
  }
  return { success: false, data: null, errors };
}

export function validateContactForm(data: unknown) {
  return validate(contactFormSchema, data);
}

export function validateSignupForm(data: unknown) {
  return validate(signupFormSchema, data);
}
```

### Usage in Forms

```jsx
import { validate, signupFormSchema } from "@/lib/validators";

function SignupForm() {
  const { t } = useTranslation();
  const { data, setData, post, processing, errors: serverErrors } = useForm({
    email: "", password: "", name: "",
  });
  const [clientErrors, setClientErrors] = useState({});

  const handleSubmit = (e) => {
    e.preventDefault();
    const { success, errors } = validate(signupFormSchema, data);

    if (!success) {
      setClientErrors(errors);
      return;
    }

    setClientErrors({});
    post(routes.signup);
  };

  // Merge: client errors show immediately, server errors after response
  const errors = { ...clientErrors, ...serverErrors };

  return (
    <form onSubmit={handleSubmit}>
      <Input label={t("auth.email")} error={errors.email} ... />
      <Input label={t("auth.password")} error={errors.password} ... />
      <Input label={t("auth.name")} error={errors.name} ... />
      <Button disabled={processing}>{t("auth.sign_up")}</Button>
    </form>
  );
}
```

### Testing Validators with Jest

Validation schemas are pure logic — test them with Jest, not E2E:

```ts
// app/frontend/lib/__tests__/validators.test.ts
import { validateSignupForm } from "@/lib/validators";

describe("validateSignupForm", () => {
  it("passes with valid data", () => {
    const result = validateSignupForm({
      email: "user@example.com", password: "password123", name: "Jane",
    });
    expect(result.success).toBe(true);
  });

  it("fails with empty email", () => {
    const result = validateSignupForm({
      email: "", password: "password123", name: "Jane",
    });
    expect(result.success).toBe(false);
    expect(result.errors.email).toBeDefined();
  });

  it("fails with short password", () => {
    const result = validateSignupForm({
      email: "user@example.com", password: "short", name: "Jane",
    });
    expect(result.success).toBe(false);
    expect(result.errors.password).toBeDefined();
  });
});
```
```

---

## shadcn/ui Setup

### components.json

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": false,
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "app/frontend/entrypoints/application.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils"
  }
}
```

### Install All Components Upfront

**Always install the full shadcn/ui component set when setting up a new project.** Don't add them one-by-one as needed — install everything so they're ready to use immediately. This eliminates friction and keeps the codebase consistent.

```bash
bunx shadcn@latest add \
  accordion alert alert-dialog aspect-ratio avatar \
  badge breadcrumb button calendar card carousel \
  chart checkbox collapsible command context-menu \
  dialog drawer dropdown-menu form hover-card \
  input input-otp label menubar navigation-menu \
  pagination popover progress radio-group resizable \
  scroll-area select separator sheet sidebar skeleton \
  slider sonner switch table tabs textarea toast \
  toggle toggle-group tooltip
```

### i18n-Ready Components

All shadcn/ui components that display user-facing text must use i18n keys. When the default shadcn component has hardcoded English (e.g. placeholder text, aria labels, empty states), update it on install:

```tsx
// Example: make DataTable i18n-ready
import { useTranslation } from "react-i18next";

export function DataTablePagination({ table }) {
  const { t } = useTranslation();

  return (
    <div className="flex items-center justify-between">
      <p className="text-sm text-muted-foreground">
        {t("table.rows_selected", {
          count: table.getFilteredSelectedRowModel().rows.length,
          total: table.getFilteredRowModel().rows.length,
        })}
      </p>
      <Button variant="outline" size="sm" onClick={() => table.previousPage()}>
        {t("common.previous")}
      </Button>
      <Button variant="outline" size="sm" onClick={() => table.nextPage()}>
        {t("common.next")}
      </Button>
    </div>
  );
}
```

Common text to i18n in components:
- Empty states: `t("common.no_results")`
- Pagination: `t("common.previous")`, `t("common.next")`
- Search inputs: `placeholder={t("common.search")}`
- Close buttons: `aria-label={t("common.close")}`
- Loading states: `t("common.loading")`
- Confirmations: `t("common.confirm")`, `t("common.cancel")`

### Utils Helper

```js
// app/frontend/lib/utils.js
import { clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs) {
  return twMerge(clsx(inputs));
}
```

---

## Responsive Design

**Mobile first. Minimum 320px. Always.**

Every component starts with base styles targeting a 320px viewport. Use responsive prefixes (`sm:`, `md:`, `lg:`, `xl:`) to add complexity as the screen grows — never the reverse.

### Breakpoints

| Prefix | Min width | Target |
|--------|-----------|--------|
| *(base)* | 320px | Small phones |
| `sm:` | 640px | Large phones |
| `md:` | 768px | Tablets |
| `lg:` | 1024px | Laptops |
| `xl:` | 1280px | Desktops |

### Patterns

```jsx
{/* Grid: 1 col → 2 cols on tablet → 3 cols on desktop */}
<div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">

{/* Sidebar: hidden on mobile, visible on tablet+ */}
<aside className="hidden md:block md:w-64">
<main className="flex-1 px-4 md:px-8">

{/* Stack → row on tablet */}
<div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">

{/* Form: full width on mobile, constrained on larger screens */}
<form className="w-full max-w-sm mx-auto md:max-w-md lg:max-w-lg">

{/* Text: responsive sizing */}
<h1 className="text-2xl font-bold md:text-3xl lg:text-4xl">

{/* Padding: tighter on mobile */}
<div className="p-4 md:p-6 lg:p-8">

{/* Table: horizontal scroll on mobile, full on tablet+ */}
<div className="overflow-x-auto -mx-4 md:mx-0">
  <table className="min-w-full">
```

### Mobile Checklist (Every Component)

- [ ] Readable and usable at 320px — no overflow, no clipped content
- [ ] Touch targets ≥ 44px (buttons, links, form controls)
- [ ] No horizontal scrolling (except data tables, explicitly wrapped)
- [ ] Text doesn't shrink below `text-sm` (14px)
- [ ] Tablet layout explicitly handled at `md:` — not just phone → desktop

### shadcn/ui Blocks

Before building a responsive layout from scratch, check [shadcn/ui Blocks](https://www.shadcn.io/blocks/) for ready-made responsive components (dashboards, sidebars, forms, auth pages, etc.). Use them as-is or adapt them to your design tokens.

---

## Common Patterns

### Page Layout

```jsx
export default function Dashboard() {
  return (
    <section className="section-py">
      <div className="container">
        <h1 className="text-2xl font-bold mb-4 md:text-3xl md:mb-6">Dashboard</h1>
        {/* Content */}
      </div>
    </section>
  );
}
```

### Flash Messages (Sonner Toasts)

Rails flash messages (`notice`, `alert`) are automatically converted to Sonner toasts. The `useFlashToasts` hook watches for flash changes on every Inertia page visit and fires the appropriate toast.

```tsx
// app/frontend/lib/hooks/useFlashToasts.ts
import { usePage } from "@inertiajs/react";
import { useEffect, useRef } from "react";
import { toast } from "sonner";

export function useFlashToasts() {
  const { flash } = usePage<{ flash: { notice?: string; alert?: string } }>().props;
  const prevFlash = useRef<typeof flash>({});

  useEffect(() => {
    if (flash?.notice && flash.notice !== prevFlash.current?.notice) {
      toast.success(flash.notice);
    }
    if (flash?.alert && flash.alert !== prevFlash.current?.alert) {
      toast.error(flash.alert);
    }
    prevFlash.current = flash;
  }, [flash?.notice, flash?.alert]);
}
```

### Using Toasts in Layouts

Call `useFlashToasts()` once in each layout — it handles both `notice` (success) and `alert` (error):

```jsx
import { useFlashToasts } from "@/lib/hooks/useFlashToasts";

export default function AppLayout({ children }) {
  useFlashToasts();

  return (
    <div className="min-h-screen flex flex-col">
      {/* ... header, main, etc. */}
      <main className="flex-1">{children}</main>
    </div>
  );
}
```

### Direct Toasts (Client-Side)

For actions that don't involve a server round-trip, call `toast()` directly:

```tsx
import { toast } from "sonner";
import { useTranslation } from "react-i18next";

function CopyButton({ text }) {
  const { t } = useTranslation();

  const handleCopy = () => {
    navigator.clipboard.writeText(text);
    toast.success(t("common.copied"));
  };

  return <Button onClick={handleCopy}>{t("common.copy")}</Button>;
}
```

### Toast Variants

```tsx
import { toast } from "sonner";

// Success — green, for completed actions
toast.success(t("contact.success"));

// Error — red, for failures
toast.error(t("errors.something_went_wrong"));

// Info — neutral, for informational messages
toast.info(t("common.session_expired"));

// Warning — yellow, for caution states
toast.warning(t("billing.trial_ending_soon"));

// With description
toast.success(t("settings.saved"), {
  description: t("settings.saved_description"),
});

// Promise toast — shows loading → success/error automatically
toast.promise(saveSettings(), {
  loading: t("common.saving"),
  success: t("settings.saved"),
  error: t("errors.save_failed"),
});
```

### App Layout

```jsx
import { Link, usePage } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { useFlashToasts } from "@/lib/hooks/useFlashToasts";

export default function AppLayout({ children }) {
  useFlashToasts();
  const { routes, auth } = usePage().props;

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-background border-b">
        <div className="container h-14 flex items-center justify-between">
          <Link href={routes.app} className="font-semibold">
            AppName
          </Link>
          <div className="flex items-center gap-4">
            <Link href={routes.settings}>Settings</Link>
            <form method="POST" action={routes.logout}>
              <input type="hidden" name="_method" value="delete" />
              <input
                type="hidden"
                name="authenticity_token"
                value={document.querySelector('meta[name="csrf-token"]')?.content}
              />
              <Button type="submit" variant="outline">
                Logout
              </Button>
            </form>
          </div>
        </div>
      </header>
      <main className="flex-1">
        {children}
      </main>
    </div>
  );
}
```

---

## Icons

**Every icon gets a dedicated wrapper file** in `app/frontend/components/icons/`. This makes it trivial to swap the underlying icon library (Lucide, Heroicons, Phosphor, etc.) without touching every page and component.

### Wrapper Pattern

Each icon file re-exports a single icon with a semantic name:

```tsx
// app/frontend/components/icons/close.tsx
export { X as IconClose } from 'lucide-react';
export { X as default } from 'lucide-react';
```

```tsx
// app/frontend/components/icons/plus.tsx
export { Plus as IconPlus } from 'lucide-react';
export { Plus as default } from 'lucide-react';
```

```tsx
// app/frontend/components/icons/check.tsx
export { Check as IconCheck } from 'lucide-react';
export { Check as default } from 'lucide-react';
```

```tsx
// app/frontend/components/icons/settings.tsx
export { Settings as IconSettings } from 'lucide-react';
export { Settings as default } from 'lucide-react';
```

```tsx
// app/frontend/components/icons/arrow-left.tsx
export { ArrowLeft as IconArrowLeft } from 'lucide-react';
export { ArrowLeft as default } from 'lucide-react';
```

### Usage

```jsx
import { IconPlus } from "@/components/icons/plus";
import { IconClose } from "@/components/icons/close";

<Button>
  <IconPlus className="mr-2 h-4 w-4" />
  {t("common.add_item")}
</Button>

<button onClick={onClose}>
  <IconClose className="h-4 w-4" />
</button>
```

### Naming Convention

| File | Named export | Lucide source |
|------|-------------|---------------|
| `close.tsx` | `IconClose` | `X` |
| `plus.tsx` | `IconPlus` | `Plus` |
| `check.tsx` | `IconCheck` | `Check` |
| `chevron-down.tsx` | `IconChevronDown` | `ChevronDown` |
| `arrow-left.tsx` | `IconArrowLeft` | `ArrowLeft` |
| `settings.tsx` | `IconSettings` | `Settings` |
| `user.tsx` | `IconUser` | `User` |
| `mail.tsx` | `IconMail` | `Mail` |
| `trash.tsx` | `IconTrash` | `Trash2` |
| `edit.tsx` | `IconEdit` | `Pencil` |
| `search.tsx` | `IconSearch` | `Search` |
| `loading.tsx` | `IconLoading` | `Loader2` |
| `menu.tsx` | `IconMenu` | `Menu` |
| `log-out.tsx` | `IconLogOut` | `LogOut` |
| `sun.tsx` | `IconSun` | `Sun` |
| `moon.tsx` | `IconMoon` | `Moon` |
| `monitor.tsx` | `IconMonitor` | `Monitor` |
| `eye.tsx` | `IconEye` | `Eye` |
| `eye-off.tsx` | `IconEyeOff` | `EyeOff` |

### Why Wrappers?

1. **Swap libraries in one place.** Changing from Lucide to Heroicons means updating icon files only — not every component that uses an icon.
2. **Semantic naming.** `IconClose` is clearer than `X` when reading component code.
3. **Tree-shaking still works.** Each file is a single re-export, so unused icons are eliminated by the bundler.
4. **Icon audit.** `ls components/icons/` shows every icon used in the app.

---

## Vite Config

```js
// vite.config.js
import { fileURLToPath, URL } from "node:url";

import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./app/frontend", import.meta.url)),
    },
  },
  server: {
    hmr: { overlay: true },
  },
});
```

### Path Alias — `@` → `app/frontend/`

The `@` alias maps to `app/frontend/` so imports are always clean and absolute:

```js
// ✅ Good — use @ for anything outside the current directory tree
import { Button } from "@/components/ui/button";
import { validateEmail } from "@/lib/validators";
import { useFlashToasts } from "@/lib/hooks/useFlashToasts";

// ✅ Good — relative imports are OK for same directory or one level down
import { formatDate } from "./utils";
import { ColumnHeader } from "./columns/header";

// ❌ Bad — never use ../ (parent-relative imports)
import { Button } from "../../components/ui/button";
import { formatDate } from "../utils";
```

**Rule: no `../` imports.** Use `@/` for anything outside the current directory. Relative imports (`./`) are only allowed for the same directory or one level down (`./x`, `./x/y`).

### jsconfig.json (IDE Support)

Since we don't use TypeScript, add a `jsconfig.json` at the project root so VS Code (and other editors) understand the `@` alias for autocompletion and go-to-definition:

```json
// jsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["app/frontend/*"]
    },
    "jsx": "react-jsx"
  },
  "include": ["app/frontend/**/*"],
  "exclude": ["node_modules", "public", "vendor", "tmp"]
}
```

---

## ESLint + Prettier {#eslint--prettier}

**ESLint for linting, Prettier for formatting.** They work together — ESLint catches code quality issues, Prettier handles all formatting decisions so you never argue about style.

### Installation

```bash
bun add -d eslint eslint-config-prettier eslint-plugin-react eslint-plugin-react-hooks eslint-plugin-simple-import-sort eslint-plugin-import eslint-plugin-unused-imports prettier prettier-plugin-yaml
```

### ESLint Configuration

```js
// eslint.config.mjs
import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import prettierConfig from "eslint-config-prettier";
import importPlugin from "eslint-plugin-import";
import reactPlugin from "eslint-plugin-react";
import reactHooksPlugin from "eslint-plugin-react-hooks";
import simpleImportSort from "eslint-plugin-simple-import-sort";
import unusedImports from "eslint-plugin-unused-imports";

const eslintConfig = defineConfig([
  // 1. Base JS rules
  js.configs.recommended,

  // 2. Global Ignores
  globalIgnores([
    "node_modules/**",
    "public/**",
    "vendor/**",
    "tmp/**",
    "coverage/**",
  ]),

  // 3. React + Import rules
  {
    files: ["**/*.js", "**/*.jsx"],
    languageOptions: {
      parserOptions: {
        ecmaFeatures: { jsx: true },
        sourceType: "module",
      },
    },
    plugins: {
      react: reactPlugin,
      "react-hooks": reactHooksPlugin,
      "simple-import-sort": simpleImportSort,
      import: importPlugin,
      "unused-imports": unusedImports,
    },
    rules: {
      // React
      ...reactPlugin.configs.recommended.rules,
      ...reactHooksPlugin.configs.recommended.rules,
      "react/react-in-jsx-scope": "off",
      "react/prop-types": "off",

      // Unused imports — auto-removable
      "no-unused-vars": "off",
      "unused-imports/no-unused-imports": "error",
      "unused-imports/no-unused-vars": [
        "warn",
        {
          vars: "all",
          varsIgnorePattern: "^_",
          args: "after-used",
          argsIgnorePattern: "^_",
        },
      ],

      // Import sorting — auto-fixable
      "simple-import-sort/imports": "error",
      "simple-import-sort/exports": "error",
      "import/first": "error",
      "import/newline-after-import": "error",
      "import/no-duplicates": "error",

      // No parent-relative imports — use @/ alias instead
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["../*"],
              message: "Use @/ alias instead of ../. Relative imports are only allowed for ./x or ./x/y.",
            },
          ],
        },
      ],

      // Disable conflicting rules
      "import/order": "off",
      "sort-imports": "off",
    },
    settings: {
      react: { version: "detect" },
    },
  },

  // 4. Prettier — must be last (disables ESLint rules that conflict)
  prettierConfig,
]);

export default eslintConfig;
```

### Prettier Configuration

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false,
  "plugins": ["prettier-plugin-yaml"],
  "overrides": [
    {
      "files": "*.yml",
      "options": {
        "singleQuote": false,
        "proseWrap": "preserve"
      }
    }
  ]
}
```

> The `prettier-plugin-yaml` plugin auto-formats YAML files with the same `prettier` command. Its defaults (2-space indent, trailing newline, consistent quoting) align with our yamllint rules.

### Prettier Ignore

```
// .prettierignore
node_modules
public
vendor
coverage
tmp
.git
```

### Scripts

```json
// package.json (scripts)
{
  "scripts": {
    "lint": "eslint app/frontend/",
    "lint:fix": "eslint app/frontend/ --fix",
    "format": "prettier --write 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml'",
    "format:check": "prettier --check 'app/frontend/**/*.{js,jsx,css}' 'config/locales/**/*.yml' 'app/frontend/locales/**/*.yml'"
  }
}
```

### Usage

```bash
# Lint JS
bun lint

# Auto-fix lint issues (unused imports, sort order)
bun lint:fix

# Format all files (JS/CSS/YAML)
bun format

# Check formatting without writing (CI)
bun format:check
```

### Key Points

- **No TypeScript.** We use plain JS/JSX everywhere. No `.ts`, `.tsx`, no TS parser, no TS plugin.
- **`@` alias for imports.** `@` maps to `app/frontend/`. Use it for anything outside the current directory. No `../` imports ever — ESLint enforces this via `no-restricted-imports`.
- **Relative imports: `./` only.** Same directory (`./utils`) or one level down (`./columns/header`) is fine. Anything else uses `@/`.
- **`eslint-config-prettier` must be last** in the ESLint config — it disables all ESLint rules that Prettier handles.
- **Prettier owns formatting.** Never add formatting rules (quotes, semicolons, indentation) to ESLint.
- **ESLint owns code quality.** Unused vars, missing deps in hooks, unreachable code — that's ESLint's job.
- **`simple-import-sort`** auto-sorts imports on `bun lint:fix`. No manual import ordering ever.
- **`unused-imports`** auto-removes dead imports on `bun lint:fix`. Prefix intentionally unused vars with `_`.
- **`prettier-plugin-yaml`** formats YAML locale files with the same `bun format` command. No separate YAML formatter needed.

---

## Stylelint

**Use Stylelint to lint all CSS files.** Catches errors, enforces consistent ordering, and prevents invalid Tailwind usage.

### Installation

```bash
bun add -d stylelint stylelint-config-standard stylelint-order
```

### Configuration

```json
// .stylelintrc.json
{
  "extends": ["stylelint-config-standard"],
  "plugins": ["stylelint-order"],
  "rules": {
    "at-rule-no-unknown": [
      true,
      {
        "ignoreAtRules": [
          "theme",
          "plugin",
          "custom-variant",
          "utility",
          "variant",
          "apply",
          "layer",
          "config",
          "source",
          "tailwind"
        ]
      }
    ],
    "import-notation": null,
    "function-no-unknown": [
      true,
      {
        "ignoreFunctions": ["theme"]
      }
    ],
    "order/properties-alphabetical-order": true
  }
}
```

### Scripts

```json
// package.json (scripts)
{
  "scripts": {
    "lint:css": "stylelint \"app/frontend/**/*.css\"",
    "lint:css:fix": "stylelint \"app/frontend/**/*.css\" --fix"
  }
}
```

### Usage

```bash
# Lint all CSS
bun lint:css

# Auto-fix what's fixable
bun lint:css:fix
```

---

## Controller → Inertia

```ruby
class DashboardController < ApplicationController
  def show
    result = Dashboard::LoadStats.call(user: Current.user)

    render inertia: "App/Dashboard", props: {
      projects: Current.user.projects.order(created_at: :desc),
      stats: result.stats
    }
  end
end
```

---

## Frontend Philosophy

> **The frontend is a dumb display layer.** With Inertia, the server controls the page. React components receive display-ready props and render them. If a component needs to think, the server should have thought for it.

- **Server sends display-ready data.** Every prop should be ready to render directly. Send `role_label: "Office/Sales"` not `user_type: "office_sales"`. Send `address: "123 Main St, Denver, CO"` not raw fields for the client to assemble.
- **No data transformation on the client.** No `.reduce()`, `.map()`, or `.filter()` for display logic. No label lookups, no string formatting, no pluralization, no date formatting. If you're writing `===` checks to transform server data, that logic belongs on the server.
- **Constants live on the server.** Role labels, status labels, category labels — defined as model constants and shared via `inertia_share`. The frontend never duplicates these mappings.
- **URLs from server only.** Pass `path`, `edit_path` etc. in props. Never construct URLs on the client with template literals like `` `/things/${id}` ``.
- **Props are explicit hashes.** Never pass raw ActiveRecord objects. Only include fields the frontend actually needs.

---

## Key Rules

1. **Never hardcode routes** - always use `usePage().props.routes`
2. **Use `<Link>` for internal navigation** - not `<a>`
3. **Check [shadcn/ui Blocks](https://www.shadcn.io/blocks/) before building custom components** - use or adapt existing blocks first
4. **Use shadcn/ui components** - not custom Tailwind divs
5. **Icons use wrapper components** - import from `@/components/icons/`, never directly from `lucide-react` in pages/components
6. **Install all shadcn/ui components upfront** - full set on project setup, make them i18n-ready
7. **Use Tailwind tokens** - `bg-background`, not `bg-white`
8. **Mobile first, 320px minimum** - base styles for mobile, then `sm:` → `md:` → `lg:` → `xl:` to scale up
9. **Adjust for tablets** - explicitly handle the `md` breakpoint, don't jump from phone to desktop
10. **Keep pages thin** - extract to components when >100 lines
11. **Validate forms client-side before submitting** - Zod schemas, instant error feedback
12. **No hardcoded English** - use `useTranslation()` for all user-facing text, including shadcn/ui component text
13. **Test validators with Jest** - pure logic, no React rendering needed
14. **Dark mode always supported** - system default, light/dark toggle via `ThemeProvider` + `ThemeToggle`
15. **Stylelint for all CSS** - run `bun lint:css` before committing, Tailwind directives are allowlisted
16. **ESLint for code quality** - `bun lint` catches errors, unused vars, and hook issues
17. **Prettier for formatting** - `bun format` auto-formats JS/TS/CSS/YAML — no manual style debates
18. **Bun for everything JS** - `bun add`, `bun install`, `bun test`, `bunx` — never npm/npx, there's no package-lock.json
