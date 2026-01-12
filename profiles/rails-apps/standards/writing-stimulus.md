---
name: writing-stimulus
description: Creates focused, reusable Stimulus controllers with progressive enhancement, accessibility, and clear APIs for interactive UI behaviors
---

You are an expert in Stimulus.js for Rails applications, specializing in building focused, accessible JavaScript controllers.

## Quick Start

**When to use this skill:**
- Adding interactivity to server-rendered HTML
- Building reusable UI behaviors (toggles, dropdowns, modals)
- Enhancing forms with auto-submit, validation UI, character counters
- Integrating third-party JavaScript libraries (Sortable, date pickers)
- Adding progressive enhancement that works without JavaScript

**Core philosophy:** Stimulus for sprinkles, not frameworks. Use Stimulus to add behavior to server-rendered HTML, not to build SPAs.

## Core Principles

### What Stimulus Is For

✅ Progressive enhancement (works without JS)
✅ DOM manipulation (show/hide, toggle, animate)
✅ Form enhancements (auto-submit, validation UI)
✅ UI interactions (dropdowns, modals, tooltips)
✅ Integration with libraries (Sortable, Trix, etc.)

### What Stimulus Is NOT For

❌ Business logic (belongs in models)
❌ Data fetching (use Turbo)
❌ Client-side routing (use Turbo)
❌ State management (server is source of truth)
❌ Replacing server-rendered views

### Controller Size Philosophy

- 62% are reusable/generic (toggle, modal, clipboard)
- 38% are domain-specific (drag-and-drop cards)
- Most under 50 lines
- Single responsibility only

## Controller Structure

### Basic Template

```javascript
// app/javascript/controllers/[name]_controller.js
import { Controller } from "@hotwired/stimulus"

/**
 * [Controller Name] Controller
 *
 * [Brief description]
 *
 * Targets:
 * - targetName: Description
 *
 * Values:
 * - valueName: Description and default
 *
 * Actions:
 * - actionName: Description
 *
 * @example
 * <div data-controller="controller-name"
 *      data-controller-name-value-name-value="value">
 *   <button data-action="controller-name#actionName">Click</button>
 * </div>
 */
export default class extends Controller {
  static targets = ["targetName"]
  static values = {
    valueName: { type: String, default: "defaultValue" }
  }
  static classes = ["active", "hidden"]
  static outlets = ["other-controller"]

  connect() {
    // Initialize controller state
    // Add event listeners for document/window scope
  }

  disconnect() {
    // Clean up: remove listeners, clear timeouts/intervals
  }

  // Value change callbacks
  valueNameValueChanged(value, previousValue) {
    // React to value changes
  }

  // Actions
  actionName(event) {
    event.preventDefault()
    // Handle the action
    this.dispatch("eventName", { detail: { data: "value" } })
  }

  // Private methods (prefix with #)
  #helperMethod() {
    // Internal logic
  }
}
```

### Static Properties Reference

```javascript
export default class extends Controller {
  // Targets - DOM elements to reference
  static targets = ["input", "output", "button"]
  // Usage: this.inputTarget, this.inputTargets, this.hasInputTarget

  // Values - Reactive data properties
  static values = {
    open: { type: Boolean, default: false },
    count: { type: Number, default: 0 },
    name: { type: String, default: "" },
    items: { type: Array, default: [] },
    config: { type: Object, default: {} }
  }
  // Usage: this.openValue, this.openValue = true

  // Classes - CSS classes to toggle
  static classes = ["active", "hidden", "loading"]
  // Usage: this.activeClass, this.activeClasses, this.hasActiveClass

  // Outlets - Connect to other controllers
  static outlets = ["modal", "dropdown"]
  // Usage: this.modalOutlet, this.modalOutlets, this.hasModalOutlet
}
```

## Common Patterns

### 1. Toggle Controller (Show/Hide)

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger"]
  static values = {
    open: { type: Boolean, default: false }
  }

  toggle(event) {
    event?.preventDefault()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged(isOpen) {
    this.contentTarget.classList.toggle("hidden", !isOpen)

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isOpen.toString())
    }

    this.dispatch(isOpen ? "opened" : "closed")
  }
}
```

```erb
<div data-controller="toggle">
  <button data-toggle-target="trigger"
          data-action="toggle#toggle"
          aria-expanded="false">
    Toggle Details
  </button>

  <div data-toggle-target="content" class="hidden">
    <p>These are the details...</p>
  </div>
</div>
```

### 2. Clipboard Controller (Copy to Clipboard)

```javascript
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    content: String,
    successMessage: { type: String, default: "Copied!" }
  }

  copy(event) {
    event.preventDefault()

    const text = this.hasContentValue
      ? this.contentValue
      : this.sourceTarget.value || this.sourceTarget.textContent

    navigator.clipboard.writeText(text).then(() => {
      this.#showSuccess()
    })
  }

  #showSuccess() {
    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successMessageValue

    setTimeout(() => {
      this.buttonTarget.textContent = originalText
    }, 2000)
  }
}
```

```erb
<div data-controller="clipboard" data-clipboard-content-value="<%= @url %>">
  <input data-clipboard-target="source" value="<%= @url %>" readonly>
  <button data-action="clipboard#copy" data-clipboard-target="button">Copy</button>
</div>
```

### 3. Modal Controller (Dialogs)

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
    document.body.classList.add("modal-open")
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
    document.body.classList.remove("modal-open")
  }

  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  closeWithKeyboard(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
```

```erb
<div data-controller="modal">
  <button data-action="modal#open">Open Modal</button>

  <dialog data-modal-target="dialog"
          data-action="click->modal#clickOutside keydown->modal#closeWithKeyboard">
    <div class="modal__content">
      <h2>Modal Title</h2>
      <p>Modal content...</p>
      <button data-action="modal#close">Close</button>
    </div>
  </dialog>
</div>
```

### 4. Dropdown Controller

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains(this.openClass)) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.add(this.openClass)
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.menuTarget.classList.remove(this.openClass)
    document.removeEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
```

```erb
<div data-controller="dropdown">
  <button data-action="dropdown#toggle">Menu ▾</button>

  <div data-dropdown-target="menu" class="dropdown-menu">
    <%= link_to "Edit", edit_path %>
    <%= link_to "Delete", delete_path, method: :delete %>
  </div>
</div>
```

### 5. Auto-Submit Controller

```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  submit() {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

```erb
<%= form_with model: @filter,
    data: {
      controller: "auto-submit",
      action: "change->auto-submit#submit"
    } do |f| %>
  <%= f.select :status, Card.statuses.keys %>
  <%= f.select :assignee_id, User.all.map { |u| [u.name, u.id] } %>
<% end %>
```

### 6. Character Counter Controller

```javascript
// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = {
    max: Number
  }

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value.length
    const remaining = this.maxValue - length

    this.countTarget.textContent = `${remaining} characters remaining`

    if (remaining < 0) {
      this.countTarget.classList.add("text-danger")
    } else {
      this.countTarget.classList.remove("text-danger")
    }
  }
}
```

```erb
<div data-controller="character-counter" data-character-counter-max-value="280">
  <%= f.text_area :body,
      data: {
        character_counter_target: "input",
        action: "input->character-counter#update"
      } %>
  <div data-character-counter-target="count"></div>
</div>
```

### 7. Search Controller (Debounced)

```javascript
// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "loading"]
  static values = {
    url: String,
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.timeout = null
    this.abortController = null
  }

  disconnect() {
    this.#clearTimeout()
    this.#abortRequest()
  }

  search() {
    this.#clearTimeout()

    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.#clearResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.#performSearch(query)
    }, this.debounceValue)
  }

  async #performSearch(query) {
    this.#abortRequest()
    this.abortController = new AbortController()

    this.#showLoading()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url, {
        signal: this.abortController.signal,
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.resultsTarget.innerHTML = html
        this.dispatch("results", { detail: { query, results: html } })
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Search failed:", error)
        this.dispatch("error", { detail: { error } })
      }
    } finally {
      this.#hideLoading()
    }
  }

  #clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  #abortRequest() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  #showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }

  #hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }

  #clearResults() {
    this.resultsTarget.innerHTML = ""
  }
}
```

### 8. Sortable Controller (Drag & Drop)

```javascript
// app/javascript/controllers/sortable_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    animation: { type: Number, default: 150 }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: this.animationValue,
      onEnd: this.#end.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  #end(event) {
    const id = event.item.dataset.id
    const position = event.newIndex + 1

    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.#csrfToken
      },
      body: JSON.stringify({ id, position })
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
```

```erb
<div data-controller="sortable"
     data-sortable-url-value="<%= reorder_cards_path %>">
  <% @cards.each do |card| %>
    <div data-id="<%= card.id %>">
      <%= render card %>
    </div>
  <% end %>
</div>
```

## Accessibility Best Practices

### ARIA Attributes

```javascript
// ✅ GOOD - Proper ARIA usage
open() {
  this.menuTarget.classList.remove("hidden")
  this.triggerTarget.setAttribute("aria-expanded", "true")
  this.menuTarget.setAttribute("aria-hidden", "false")
  this.triggerTarget.setAttribute("aria-controls", this.menuTarget.id)
}

close() {
  this.menuTarget.classList.add("hidden")
  this.triggerTarget.setAttribute("aria-expanded", "false")
  this.menuTarget.setAttribute("aria-hidden", "true")
}

// ✅ GOOD - Screen reader announcements
announce(message) {
  if (this.hasAnnouncementTarget) {
    this.announcementTarget.textContent = message
  }
}
```

### Focus Management

```javascript
// ✅ GOOD - Trap focus in modals
trapFocus() {
  const focusableElements = this.element.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  )

  this.firstFocusable = focusableElements[0]
  this.lastFocusable = focusableElements[focusableElements.length - 1]
}

handleTab(event) {
  if (event.key !== "Tab") return

  if (event.shiftKey && document.activeElement === this.firstFocusable) {
    event.preventDefault()
    this.lastFocusable.focus()
  } else if (!event.shiftKey && document.activeElement === this.lastFocusable) {
    event.preventDefault()
    this.firstFocusable.focus()
  }
}
```

### Keyboard Navigation

```javascript
// app/javascript/controllers/keyboard_nav_controller.js
navigate(event) {
  switch (event.key) {
    case "ArrowDown":
      event.preventDefault()
      this.#focusNext()
      break

    case "ArrowUp":
      event.preventDefault()
      this.#focusPrevious()
      break

    case "Home":
      event.preventDefault()
      this.#focusFirst()
      break

    case "End":
      event.preventDefault()
      this.#focusLast()
      break

    case "Enter":
    case " ":
      event.preventDefault()
      this.#selectCurrent()
      break
  }
}
```

## Integration with Turbo

### Turbo Frame Events

```javascript
connect() {
  this.frameTarget.addEventListener("turbo:frame-load", this.#onLoad.bind(this))
  this.frameTarget.addEventListener("turbo:frame-render", this.#onRender.bind(this))
}

disconnect() {
  this.frameTarget.removeEventListener("turbo:frame-load", this.#onLoad)
  this.frameTarget.removeEventListener("turbo:frame-render", this.#onRender)
}

#onLoad() {
  if (this.hasLoadingTarget) {
    this.loadingTarget.classList.add("hidden")
  }
}

#onRender() {
  this.dispatch("rendered")
}
```

### Auto-Dismiss Flash Messages

```javascript
export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }

  connect() {
    if (this.autoDismissValue) {
      this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    this.element.classList.add("animate-fade-out")
    this.element.addEventListener("animationend", () => {
      this.element.remove()
    })
  }
}
```

## Controller Composition

### Multiple Controllers on One Element

```erb
<div data-controller="dropdown modal">
  <%# Both controllers active %>
</div>
```

### Nested Controllers

```erb
<div data-controller="sortable">
  <div data-controller="card">
    <div data-controller="dropdown">
      <%# Three controllers in hierarchy %>
    </div>
  </div>
</div>
```

### Controller Communication via Events

```javascript
// Publisher controller
export default class extends Controller {
  publish() {
    this.dispatch("published", { detail: { content: "data" } })
  }
}

// Subscriber controller
export default class extends Controller {
  connect() {
    this.element.addEventListener("publisher:published", this.#handleEvent)
  }

  #handleEvent(event) {
    console.log("Received:", event.detail.content)
  }
}
```

```erb
<div data-controller="subscriber">
  <div data-controller="publisher"
       data-action="publisher:published->subscriber#handleEvent">
    <button data-action="publisher#publish">Publish</button>
  </div>
</div>
```

## Naming Conventions

### Controller Names

- Kebab-case in HTML: `data-controller="auto-submit"`
- Snake_case in filename: `auto_submit_controller.js`
- PascalCase in class: `AutoSubmitController`

### Targets

- camelCase: `data-[controller]-target="menuItem"`
- Access: `this.menuItemTarget` or `this.menuItemTargets`

### Values

- camelCase: `data-[controller]-url-value="/path"`
- Access: `this.urlValue`

### Classes

- camelCase: `data-[controller]-active-class="is-active"`
- Access: `this.activeClass`

## Performance Tips

### 1. Use Event Delegation

```javascript
connect() {
  // Good: One listener on parent
  this.element.addEventListener("click", this.#handleClick)
}

#handleClick(event) {
  if (event.target.matches(".delete-button")) {
    this.delete(event)
  }
}
```

### 2. Debounce Expensive Operations

```javascript
connect() {
  this.search = this.#debounce(this.search.bind(this), 300)
}

#debounce(func, wait) {
  let timeout
  return (...args) => {
    clearTimeout(timeout)
    timeout = setTimeout(() => func.apply(this, args), wait)
  }
}
```

### 3. Clean Up in Disconnect

```javascript
disconnect() {
  clearTimeout(this.timeout)
  this.observer?.disconnect()
  document.removeEventListener("click", this.boundClose)
}
```

### 4. Use IntersectionObserver for Visibility

```javascript
connect() {
  this.observer = new IntersectionObserver(this.#handleIntersection.bind(this))
  this.observer.observe(this.element)
}
```

## Reusable Controller Library

**UI Controllers:**
- `toggle_controller` - Show/hide elements
- `dropdown_controller` - Dropdown menus
- `modal_controller` - Dialog boxes
- `tabs_controller` - Tab navigation
- `tooltip_controller` - Tooltips

**Form Controllers:**
- `auto_submit_controller` - Auto-submit forms
- `character_counter_controller` - Character counting
- `form_validation_controller` - Validation UI
- `password_visibility_controller` - Show/hide password

**Utility Controllers:**
- `clipboard_controller` - Copy to clipboard
- `auto_dismiss_controller` - Auto-remove elements
- `confirm_controller` - Confirmation dialogs
- `disable_controller` - Disable buttons

**Integration Controllers:**
- `sortable_controller` - Drag and drop
- `trix_controller` - Rich text editor
- `flatpickr_controller` - Date picker

## Commands

**Generate controller:**
```bash
bin/rails generate stimulus [name]
```

**List controllers:**
```bash
ls app/javascript/controllers/
```

**Test in browser:**
Open DevTools console, check `this.application.controllers`

## Boundaries

### ✅ Always Do

- Keep controllers small (under 50 lines)
- Single responsibility only
- Use values/classes for configuration
- Clean up in disconnect()
- Use private methods (#)
- Provide fallback for no-JS
- Test with system tests
- Use event delegation
- Include ARIA attributes
- Ensure keyboard navigation

### ⚠️ Ask First

- Before adding business logic (belongs in models)
- Before fetching data (use Turbo)
- Before managing complex state (server is source)
- Before creating domain-specific controllers (favor generic + composition)
- Before adding external dependencies

### 🚫 Never Do

- Build SPAs with Stimulus
- Put business logic in controllers
- Manage application state client-side
- Skip disconnect() cleanup
- Hardcode values (use data-values)
- Create god controllers (split them)
- Forget CSRF tokens in fetch requests
- Skip progressive enhancement (must work without JS)
- Use jQuery or DOM libraries
- Query outside controller scope
- Store complex state in DOM (use values)

## Key Takeaways

- Stimulus controllers are **HTML-first** - enhance existing markup
- Controllers should be **small and focused** - one responsibility
- **Progressive enhancement** - page works without JavaScript
- **Accessibility is required** - ARIA, keyboard, focus
- **Clean up after yourself** - remove listeners in disconnect()
- **Use Stimulus features** - targets, values, classes, outlets
- **Integrate with Turbo** - handle morphing, frames, streams
- Be **pragmatic** - don't over-engineer
