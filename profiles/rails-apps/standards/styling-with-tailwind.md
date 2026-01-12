---
name: styling-with-tailwind
description: Styles HTML ERB views and ViewComponents with Tailwind CSS using mobile-first responsive design, accessibility, and modern UI patterns
---

You are an expert in Tailwind CSS styling for Rails applications with Hotwire.

## Quick Start

**When to use this skill:**
- Styling HTML ERB views and ViewComponents
- Creating responsive, mobile-first layouts
- Building accessible interfaces with proper ARIA attributes
- Implementing consistent design patterns
- Styling Turbo Frames and Streams

**Core philosophy:** Mobile-first responsive design with Tailwind utility classes. Always ensure accessibility, maintain consistent patterns, and extract repeated styles into ViewComponents.

## Core Principles

### Rails 8 / Tailwind Integration

- **Importmap:** Tailwind compiled via Rails asset pipeline
- **Hot Reload:** `bin/dev` watches Tailwind files for changes
- **Custom Utilities:** Add to `app/assets/tailwind/application.css`
- **View Transitions:** Works seamlessly with Turbo 8 morphing
- **Component Libraries:** Use ViewComponent for reusable UI

### Mobile-First Responsive Design

Always start with mobile styles, then add breakpoints for larger screens:

```erb
<%# ✅ GOOD - Mobile-first responsive grid %>
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <%= render @items %>
</div>

<%# ✅ GOOD - Mobile-first typography %>
<h1 class="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold">
  Welcome
</h1>

<%# ✅ GOOD - Mobile-first spacing %>
<div class="px-4 sm:px-6 md:px-8 lg:px-12">
  <%= yield %>
</div>

<%# ❌ BAD - Desktop-first (requires overriding) %>
<div class="grid-cols-3 md:grid-cols-1">
  <%# Backwards - forces overrides %>
</div>
```

**Tailwind Breakpoints:**
- `sm:` 640px+ (small tablets)
- `md:` 768px+ (tablets)
- `lg:` 1024px+ (desktops)
- `xl:` 1280px+ (large desktops)
- `2xl:` 1536px+ (extra-large desktops)

### Semantic HTML and Accessibility

Use semantic HTML elements and proper ARIA attributes:

```erb
<%# ✅ GOOD - Semantic HTML with accessibility %>
<nav aria-label="Main navigation" class="bg-white shadow-md">
  <ul class="flex gap-4 p-4">
    <li>
      <%= link_to "Home", root_path,
          class: "text-gray-700 hover:text-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded",
          aria_current: current_page?(root_path) ? "page" : nil %>
    </li>
  </ul>
</nav>

<%# ✅ GOOD - Accessible form with labels %>
<%= form_with model: @user, class: "space-y-4" do |f| %>
  <div>
    <%= f.label :email, "Email Address",
        class: "block text-sm font-medium text-gray-700 mb-1" %>
    <%= f.email_field :email,
        required: true,
        aria: { required: "true" },
        class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" %>
  </div>

  <%= f.submit "Sign Up",
      class: "w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" %>
<% end %>

<%# ✅ GOOD - Accessible button with icon %>
<button type="button"
        aria-label="Close modal"
        class="text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 rounded">
  <span aria-hidden="true">&times;</span>
</button>
```

**Accessibility Checklist:**
- ✅ Use semantic HTML (`<nav>`, `<main>`, `<article>`, `<button>`)
- ✅ Include `aria-label` for icon-only buttons
- ✅ Use `aria-current="page"` for current navigation items
- ✅ Ensure focus states with `focus:ring-` and `focus:outline-` classes
- ✅ Add `sr-only` class for screen-reader-only text
- ✅ Use proper heading hierarchy (`h1` → `h2` → `h3`)
- ✅ Ensure sufficient color contrast (WCAG AA: 4.5:1 for text)

## Color Palette

Use Tailwind's semantic color system consistently:

```erb
<%# Primary Actions (Blue) %>
<%= link_to "Save", save_path,
    class: "bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white px-4 py-2 rounded-md" %>

<%# Success (Green) %>
<div class="bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded-md">
  <p class="font-medium">Success!</p>
</div>

<%# Warning (Yellow/Orange) %>
<div class="bg-yellow-50 border border-yellow-200 text-yellow-800 px-4 py-3 rounded-md">
  <p class="font-medium">Warning</p>
</div>

<%# Error/Danger (Red) %>
<div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-md">
  <p class="font-medium">Error</p>
</div>

<%# Neutral/Gray for secondary elements %>
<button class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-md">
  Cancel
</button>
```

**Color Usage Guidelines:**
- **Blue** (`blue-*`): Primary actions, links, brand
- **Green** (`green-*`): Success states, confirmations
- **Red** (`red-*`): Errors, deletions, destructive actions
- **Yellow/Orange** (`yellow-*`, `orange-*`): Warnings
- **Gray** (`gray-*`): Neutral elements, disabled states
- **Indigo/Purple** (`indigo-*`, `purple-*`): Alternative brand

## Typography Scale

Use consistent typography with Tailwind's built-in scale:

```erb
<%# Page Titles %>
<h1 class="text-3xl md:text-4xl lg:text-5xl font-bold text-gray-900 mb-4">
  Dashboard
</h1>

<%# Section Headings %>
<h2 class="text-2xl md:text-3xl font-semibold text-gray-800 mb-3">
  Recent Activity
</h2>

<%# Subsection Headings %>
<h3 class="text-xl md:text-2xl font-medium text-gray-800 mb-2">
  Details
</h3>

<%# Body Text %>
<p class="text-base text-gray-700 leading-relaxed mb-4">
  This is standard body text with good readability.
</p>

<%# Small Text / Captions %>
<p class="text-sm text-gray-600">
  Additional information or metadata
</p>

<%# Extra Small / Labels %>
<span class="text-xs uppercase tracking-wide text-gray-500 font-medium">
  Category
</span>
```

**Typography Scale:**
- `text-xs`: 12px (labels, badges)
- `text-sm`: 14px (captions, secondary text)
- `text-base`: 16px (body text)
- `text-lg`: 18px (prominent text)
- `text-xl`: 20px (small headings)
- `text-2xl`: 24px (headings)
- `text-3xl`: 30px (page titles)
- `text-4xl`: 36px (hero headings)
- `text-5xl`: 48px (large hero text)

## Spacing and Layout

Use consistent spacing (1 unit = 0.25rem = 4px):

```erb
<%# Container with consistent padding %>
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <%= yield %>
</div>

<%# Card with consistent spacing %>
<div class="bg-white rounded-lg shadow-md p-6 space-y-4">
  <h3 class="text-xl font-semibold text-gray-800">Card Title</h3>

  <p class="text-gray-600">Card content with consistent spacing.</p>

  <div class="flex gap-3 pt-4 border-t border-gray-200">
    <%= link_to "Action", "#", class: "btn-primary" %>
    <%= link_to "Cancel", "#", class: "btn-secondary" %>
  </div>
</div>

<%# Stacked form with consistent gaps %>
<form class="space-y-6">
  <div class="space-y-2">
    <%= label_tag :name, "Name", class: "block text-sm font-medium" %>
    <%= text_field_tag :name, nil, class: "input-field" %>
  </div>

  <div class="space-y-2">
    <%= label_tag :email, "Email", class: "block text-sm font-medium" %>
    <%= email_field_tag :email, nil, class: "input-field" %>
  </div>
</form>
```

**Common Spacing Patterns:**
- `space-y-2`: 8px vertical gap (tight)
- `space-y-4`: 16px vertical gap (standard)
- `space-y-6`: 24px vertical gap (generous)
- `gap-3`: 12px grid/flex gap
- `gap-4`: 16px grid/flex gap
- `gap-6`: 24px grid/flex gap

## Interactive States

Always style hover, focus, and active states:

```erb
<%# Button with all interactive states %>
<%= link_to "Primary Button", action_path,
    class: "
      inline-flex items-center justify-center
      px-4 py-2 rounded-md font-semibold
      bg-blue-600 text-white
      hover:bg-blue-700
      active:bg-blue-800
      focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
      disabled:opacity-50 disabled:cursor-not-allowed
      transition-colors duration-200
    " %>

<%# Link with hover and focus states %>
<%= link_to "Read More", article_path,
    class: "
      text-blue-600 underline
      hover:text-blue-800 hover:no-underline
      focus:outline-none focus:ring-2 focus:ring-blue-500 rounded
    " %>

<%# Input with focus states %>
<%= text_field_tag :search, nil,
    placeholder: "Search...",
    class: "
      w-full px-4 py-2 rounded-md
      border border-gray-300
      focus:border-blue-500 focus:ring-2 focus:ring-blue-500
      placeholder:text-gray-400
      transition-colors duration-200
    " %>

<%# Card with hover effect %>
<div class="
  bg-white rounded-lg shadow-md p-6
  hover:shadow-xl hover:-translate-y-1
  transition-all duration-300
">
  <%# Card content %>
</div>
```

**Interactive State Guidelines:**
- ✅ **Always** include `hover:` states for clickable elements
- ✅ **Always** include `focus:` states for keyboard navigation
- ✅ Use `active:` for button press feedback
- ✅ Use `disabled:` for disabled state styling
- ✅ Add `transition-*` for smooth animations
- ✅ Use `group-hover:` for child elements

## Component Patterns

### Button Variants

```erb
<%# Primary Button %>
<%= button_to "Create", create_path,
    class: "
      bg-blue-600 hover:bg-blue-700 active:bg-blue-800
      text-white font-semibold
      px-4 py-2 rounded-md
      focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Secondary Button %>
<%= link_to "Cancel", back_path,
    class: "
      bg-gray-100 hover:bg-gray-200 active:bg-gray-300
      text-gray-700 font-semibold
      px-4 py-2 rounded-md border border-gray-300
      focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Danger Button %>
<%= button_to "Delete", delete_path, method: :delete,
    data: { turbo_confirm: "Are you sure?" },
    class: "
      bg-red-600 hover:bg-red-700 active:bg-red-800
      text-white font-semibold
      px-4 py-2 rounded-md
      focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2
      transition-colors duration-200
    " %>

<%# Icon Button %>
<button type="button"
        aria-label="Close"
        class="
          p-2 rounded-full
          text-gray-400 hover:text-gray-600 hover:bg-gray-100
          focus:outline-none focus:ring-2 focus:ring-gray-500
          transition-colors duration-200
        ">
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
    <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
  </svg>
</button>
```

### Form Fields

```erb
<%# Text Input %>
<div class="space-y-1">
  <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
  <%= f.text_field :name,
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
        transition-colors duration-200
      ",
      placeholder: "Enter name..." %>
</div>

<%# Select Dropdown %>
<div class="space-y-1">
  <%= f.label :status, class: "block text-sm font-medium text-gray-700" %>
  <%= f.select :status, ["Active", "Inactive"],
      { include_blank: "Select status" },
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        transition-colors duration-200
      " %>
</div>

<%# Textarea %>
<div class="space-y-1">
  <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
  <%= f.text_area :description,
      rows: 4,
      class: "
        w-full px-3 py-2 rounded-md
        border border-gray-300
        focus:border-blue-500 focus:ring-2 focus:ring-blue-500
        placeholder:text-gray-400
        transition-colors duration-200
      ",
      placeholder: "Enter description..." %>
</div>

<%# Checkbox %>
<div class="flex items-center gap-2">
  <%= f.check_box :terms,
      class: "
        w-4 h-4 rounded
        text-blue-600 border-gray-300
        focus:ring-2 focus:ring-blue-500
      " %>
  <%= f.label :terms, "I agree to the terms",
      class: "text-sm text-gray-700" %>
</div>
```

### Cards

```erb
<%# Basic Card %>
<div class="bg-white rounded-lg shadow-md p-6">
  <h3 class="text-xl font-semibold text-gray-800 mb-2">Card Title</h3>
  <p class="text-gray-600">Card content goes here.</p>
</div>

<%# Card with Header and Footer %>
<div class="bg-white rounded-lg shadow-md overflow-hidden">
  <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-800">Card Header</h3>
  </div>

  <div class="p-6">
    <p class="text-gray-600">Card body content.</p>
  </div>

  <div class="bg-gray-50 px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
    <%= link_to "Cancel", "#", class: "text-gray-600 hover:text-gray-800" %>
    <%= link_to "Save", "#", class: "text-blue-600 hover:text-blue-800 font-semibold" %>
  </div>
</div>

<%# Hoverable Card %>
<%= link_to item_path(@item), class: "block" do %>
  <div class="
    bg-white rounded-lg shadow-md p-6
    hover:shadow-xl hover:-translate-y-1
    transition-all duration-300
  ">
    <h3 class="text-xl font-semibold text-gray-800 mb-2"><%= @item.title %></h3>
    <p class="text-gray-600"><%= @item.description %></p>
  </div>
<% end %>
```

### Alerts/Notifications

```erb
<%# Success Alert %>
<div class="bg-green-50 border border-green-200 rounded-md p-4" role="alert">
  <div class="flex gap-3">
    <div class="flex-shrink-0">
      <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
      </svg>
    </div>
    <div>
      <h4 class="text-sm font-medium text-green-800">Success!</h4>
      <p class="text-sm text-green-700 mt-1">Your changes have been saved.</p>
    </div>
  </div>
</div>

<%# Error Alert %>
<div class="bg-red-50 border border-red-200 rounded-md p-4" role="alert">
  <div class="flex gap-3">
    <div class="flex-shrink-0">
      <svg class="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
      </svg>
    </div>
    <div>
      <h4 class="text-sm font-medium text-red-800">Error</h4>
      <p class="text-sm text-red-700 mt-1">Something went wrong.</p>
    </div>
  </div>
</div>

<%# Dismissible Alert %>
<div data-controller="dismissible"
     class="bg-blue-50 border border-blue-200 rounded-md p-4"
     role="alert">
  <div class="flex justify-between gap-3">
    <div class="flex gap-3">
      <div class="flex-shrink-0">
        <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />
        </svg>
      </div>
      <p class="text-sm text-blue-700">This is an informational message.</p>
    </div>
    <button data-action="dismissible#dismiss"
            aria-label="Dismiss"
            class="flex-shrink-0 text-blue-400 hover:text-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded">
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
</div>
```

### Badges

```erb
<%# Status Badges %>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Active
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
  Inactive
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
  Deleted
</span>

<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
  Pending
</span>
```

### Loading States

```erb
<%# Spinner %>
<div class="flex items-center justify-center p-4">
  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
</div>

<%# Skeleton Loader %>
<div class="animate-pulse space-y-4">
  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
  <div class="h-4 bg-gray-200 rounded w-1/2"></div>
  <div class="h-4 bg-gray-200 rounded w-5/6"></div>
</div>

<%# Button with Loading State %>
<button data-controller="loading"
        data-action="loading#submit"
        class="btn-primary">
  <span data-loading-target="text">Save</span>
  <svg data-loading-target="spinner"
       class="hidden animate-spin ml-2 h-4 w-4"
       fill="none"
       viewBox="0 0 24 24">
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
  </svg>
</button>
```

## Turbo Integration

```erb
<%# Turbo Frame with loading state %>
<turbo-frame id="comments"
             src="<%= comments_path %>"
             class="space-y-4"
             loading="lazy">
  <div class="flex items-center justify-center p-8">
    <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
  </div>
</turbo-frame>

<%# Turbo Stream target with transition %>
<div id="notifications"
     class="fixed top-4 right-4 z-50 w-80 space-y-2 pointer-events-none">
  <%# Turbo Streams append here %>
</div>

<%# Permanent element (survives morphing) %>
<div id="shopping-cart"
     data-turbo-permanent
     class="fixed top-4 right-4 bg-white shadow-lg rounded-lg p-4">
  <%# Cart contents preserved %>
</div>
```

## Custom Utilities

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";

/* Only add custom utilities when absolutely necessary */
@utility btn-primary {
  @apply bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-md transition-colors;
}

@utility input-field {
  @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:border-blue-500 focus:ring-2 focus:ring-blue-500;
}
```

## Common Utility Patterns

**Layout:**
- `container mx-auto` - Centered container
- `flex items-center justify-between` - Horizontal layout
- `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3` - Responsive grid
- `space-y-4` - Vertical spacing
- `gap-4` - Grid/flex gap

**Typography:**
- `text-xl font-semibold text-gray-900` - Heading
- `text-sm text-gray-600` - Caption/secondary
- `font-medium` - Medium weight
- `leading-relaxed` - Line height

**Colors:**
- `bg-white` - White background
- `text-gray-900` - Dark text
- `border-gray-300` - Light border
- `hover:bg-blue-700` - Hover state

**Spacing:**
- `p-6` - Padding all sides (24px)
- `px-4 py-2` - Horizontal/vertical padding
- `mb-4` - Margin bottom (16px)
- `mt-8` - Margin top (32px)

**Borders & Shadows:**
- `rounded-lg` - Large radius
- `shadow-md` - Medium shadow
- `border border-gray-300` - Border with color

**Transitions:**
- `transition-colors duration-200` - Smooth colors
- `hover:shadow-xl hover:-translate-y-1` - Hover lift
- `transition-all duration-300` - All properties

## Commands

**Start server:**
```bash
bin/dev
```

**Lint views:**
```bash
bundle exec rubocop -a app/views/
bundle exec rubocop -a app/components/
```

**Test components:**
```bash
bundle exec rspec spec/components/
```

## Boundaries

### ✅ Always Do

- Use mobile-first responsive design
- Ensure proper accessibility
- Follow consistent color palette
- Follow typography scale
- Extract repeated patterns into components
- Add smooth transitions
- Test across breakpoints
- Include focus states
- Use semantic HTML

### ⚠️ Ask First

- Before adding custom CSS beyond Tailwind utilities
- Before changing existing component APIs
- Before adding arbitrary values (`w-[372px]`)
- Before creating overly complex custom utilities

### 🚫 Never Do

- Use inline styles
- Skip responsive classes
- Ignore accessibility
- Mix custom CSS without justification
- Use arbitrary values without reason
- Skip focus states
- Create non-semantic HTML
- Forget ARIA attributes
- Use desktop-first approach

## Key Takeaways

- **Mobile-first** - Start mobile, scale up
- **Accessibility is required** - ARIA, semantic HTML, keyboard
- **Consistent patterns** - Follow color, typography, spacing scales
- **Extract to components** - Reuse repeated patterns
- **Progressive enhancement** - Works without JavaScript
- **Test thoroughly** - Responsive, accessible, interactive states
- Be **pragmatic** - Use Tailwind utilities, avoid custom CSS
