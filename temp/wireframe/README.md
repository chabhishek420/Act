# Act Wireframe Catalog & Component Mapping

> **Total Assets**: 60 files (59 PNGs + 1 PDF) + 3 subdirectories  
> **Last Updated**: 2026-01-20  
> **Naming Convention**: `act-[feature]-[variant].png` or `component-[name].png`

---

## 🎯 Component-to-Wireframe Mapping

### Core App Structure

| Swift Component | Wireframe | Description |
|-----------------|-----------|-------------|
| `ActApp.swift` | - | App entry point, no UI |
| `RootView.swift` | [act-welcome-empty-state.png](./act-welcome-empty-state.png) | Chat-first container + sidebar (no tabs) |

### Onboarding Flow

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `WelcomeView.swift` | [act-welcome-empty-state.png](./act-welcome-empty-state.png) | Empty state with suggestion chips ("Website content audit"), floating composer bar |
| `APISetupView.swift` | - | Custom implementation (API key input) |
| `FirstConnectionView.swift` | - | Custom implementation (OAuth flow) |

### Chat Interface

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `ChatView.swift` | [act-chat-message-basic.png](./act-chat-message-basic.png) | User bubble (dark), assistant response, action icons row |
| `MessageRow.swift` | [act-chat-message-multi-turn.png](./act-chat-message-multi-turn.png) | Multi-turn conversation with longer responses |
| `ChatListHeader.swift` | [act-welcome-empty-state.png](./act-welcome-empty-state.png) | Header: hamburger menu, title, compose button |

### Composer & Input

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `ComposerView.swift` | [act-composer-keyboard.png](./act-composer-keyboard.png) | "+" button, "Ask anything" placeholder, mic icon, voice waves |
| `ComposerView.swift` (active) | [act-composer-typing.png](./act-composer-typing.png) | Active typing with keyboard visible |

### Tool Execution States

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `ToolStatusCard.swift` (loading) | [act-loading-state.png](./act-loading-state.png) | Pulsing black dot indicator, stop button |
| `ToolStatusCard.swift` (variants) | [act-loading-state-1.png](./act-loading-state-1.png) to [act-loading-state-6.png](./act-loading-state-6.png) | Various loading state contexts |

### Rich Content Displays

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `ResultCard.swift` (music) | [act-result-music-spotify.png](./act-result-music-spotify.png) | "Asked Spotify" badge, playlist card, song list |
| `ResultCard.swift` (shopping) | [act-result-shopping-grocery.png](./act-result-shopping-grocery.png) | Grocery list by category, product cards with prices |
| `ResultCard.swift` (travel) | [act-result-travel-hotels.png](./act-result-travel-hotels.png) | Hotel cards with images, ratings, "View on Booking.com" |
| `ResultCard.swift` (flights) | [act-result-travel-flights.png](./act-result-travel-flights.png) | Flight/travel booking interface |

### Map & Location

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `MapResultView.swift` | [act-map-restaurant-finder.png](./act-map-restaurant-finder.png) | Full-screen map with pins, bottom sheet with venue |
| `MapResultView.swift` (full) | [act-map-fullscreen.png](./act-map-fullscreen.png) | Split view with list + map |

### Detail Views

| Swift Component | Wireframe | What It Shows |
|-----------------|-----------|---------------|
| `DetailView.swift` | [act-ios-restaurant-detail.png](./act-ios-restaurant-detail.png) | Restaurant detail card with gallery, rating, CTA |
| `DetailCard.swift` | [act-detail-card.png](./act-detail-card.png) | Tool result detail view |

---

## 📂 Complete File Index

### Core Screens (act-*)

| New Filename | Purpose | Component |
|--------------|---------|-----------|
| `act-welcome-empty-state.png` | Home/empty state | `WelcomeView` |
| `act-composer-keyboard.png` | Composer with keyboard | `ComposerView` |
| `act-composer-typing.png` | Active typing state | `ComposerView` |
| `act-composer-typing-1.png` | Typing variant 1 | `ComposerView` |
| `act-composer-typing-2.png` | Typing variant 2 | `ComposerView` |
| `act-composer-typing-3.png` | Typing variant 3 | `ComposerView` |
| `act-composer-typing-4.png` | Typing variant 4 | `ComposerView` |

### Chat Messages (act-chat-*)

| New Filename | Purpose | Component |
|--------------|---------|-----------|
| `act-chat-message-basic.png` | Basic chat message | `ChatView`, `MessageRow` |
| `act-chat-message-multi-turn.png` | Multi-turn dialogue | `MessageRow` |
| `act-chat-message-extended.png` | Extended conversation | `MessageRow` |
| `act-chat-message-compact.png` | Compact variant | `MessageRow` |
| `act-chat-rich-content.png` | With rich content | `ResultCard` |
| `act-chat-tool-results.png` | Tool execution results | `ToolStatusCard` |
| `act-chat-multi-tool.png` | Multi-tool response | `ToolStatusCard` |

### Loading States (act-loading-*)

| New Filename | Purpose |
|--------------|---------|
| `act-loading-state.png` | Primary loading indicator |
| `act-loading-state-1.png` | Loading variant 1 |
| `act-loading-state-2.png` | Loading variant 2 |
| `act-loading-state-3.png` | Loading variant 3 |
| `act-loading-state-4.png` | Loading variant 4 |
| `act-loading-state-5.png` | Loading variant 5 |
| `act-loading-state-6.png` | Loading variant 6 |

### Result Cards (act-result-*)

| New Filename | Integration Type | Component |
|--------------|------------------|-----------|
| `act-result-music-spotify.png` | Music/Spotify | `ResultCard` |
| `act-result-shopping-grocery.png` | Shopping/Grocery | `ResultCard` |
| `act-result-shopping-search.png` | Product search | `ResultCard` |
| `act-result-shopping-detail.png` | Product detail | `ResultCard` |
| `act-result-shopping-cart.png` | Cart/checkout | `ResultCard` |
| `act-result-shopping-confirm.png` | Order confirmation | `ResultCard` |
| `act-result-order-tracking.png` | Order tracking | `ResultCard` |
| `act-result-order-history.png` | Order history | `ResultCard` |
| `act-result-travel-hotels.png` | Hotel booking | `ResultCard` |
| `act-result-travel-flights.png` | Flight booking | `ResultCard` |

### Maps & Location (act-map-*)

| New Filename | Purpose | Component |
|--------------|---------|-----------|
| `act-map-restaurant-finder.png` | Restaurant map | `MapResultView` |
| `act-map-fullscreen.png` | Full map view | `MapResultView` |

### iOS Specific (act-ios-*)

| New Filename | Purpose |
|--------------|---------|
| `act-ios-patterns.png` | iOS patterns overview |
| `act-ios-music-integration.png` | Music in device frame |
| `act-ios-restaurant-detail.png` | Restaurant detail card |
| `act-ios-variant-3.png` | iOS variant 3 |
| `act-ios-variant-4.png` | iOS variant 4 |
| `act-ios-variant-5.png` | iOS variant 5 |
| `act-ios-fullscreen.png` | iOS full screen |

### Other

| New Filename | Purpose |
|--------------|---------|
| `act-detail-card.png` | Detail card view |
| `act-agent-reasoning.png` | Agent multi-step reasoning |

### UI Components (component-*)

| New Filename | Component Type |
|--------------|----------------|
| `component-onboarding.png` | Onboarding/splash |
| `component-navigation.png` | Navigation header |
| `component-message-bubbles.png` | Message bubble variants |
| `component-settings.png` | Settings/config |
| `component-action-buttons.png` | Action buttons |
| `component-input-controls.png` | Input controls |
| `component-status-indicators.png` | Status indicators |
| `component-tab-bar.png` | Sidebar drawer (NOT a tab bar) |
| `component-toggles.png` | Toggles/switches |
| `component-empty-states.png` | Empty states |
| `component-list-rows.png` | List rows |
| `component-message-states.png` | Message states (loading, searching) |
| `component-cards.png` | Cards/containers |
| `component-badges.png` | Badges/chips |
| `component-icons.png` | Icons/symbols |
| `component-color-palette.png` | Color palette |

---

## 🔧 Implementation Priority

### Phase 1: MVP Core (P0)

| Component | Wireframe |
|-----------|-----------|
| `ComposerView` | `act-composer-keyboard.png` |
| `MessageRow` | `act-chat-message-basic.png` |
| `ToolStatusCard` | `act-loading-state.png` |
| `WelcomeView` | `act-welcome-empty-state.png` |
| `ChatView` | `act-chat-message-multi-turn.png` |

### Phase 2: Rich Results (P1)

| Component | Wireframe |
|-----------|-----------|
| `ResultCard` (list) | `act-result-shopping-grocery.png` |
| `ResultCard` (media) | `act-result-music-spotify.png` |
| `ResultCard` (booking) | `act-result-travel-hotels.png` |

### Phase 3: Advanced (P2)

| Component | Wireframe |
|-----------|-----------|
| `MapResultView` | `act-map-restaurant-finder.png` |
| `DetailView` | `act-ios-restaurant-detail.png` |

---

## 📦 Additional Assets

### PDF Component Library
- **File**: `ChatGPT Apps Components Templates.pdf` (19 MB)
- **Contents**: Complete design system, spacing grids, component specs

### Icon Assets
- **Directory**: `icon/` - Standard app icons
- **Directory**: `icon-thin/` - Thin variant icons

---

## 📝 Naming Convention

| Prefix | Usage | Example |
|--------|-------|---------|
| `act-` | App screens & flows | `act-welcome-empty-state.png` |
| `act-chat-` | Chat interface screens | `act-chat-message-basic.png` |
| `act-composer-` | Composer/input states | `act-composer-keyboard.png` |
| `act-loading-` | Loading states | `act-loading-state.png` |
| `act-result-` | Tool result displays | `act-result-music-spotify.png` |
| `act-map-` | Map/location views | `act-map-fullscreen.png` |
| `act-ios-` | iOS-specific patterns | `act-ios-restaurant-detail.png` |
| `component-` | UI component library | `component-badges.png` |

---

**Last Updated**: 2026-01-20  
**All files renamed from ChatGPT5 naming to Act project convention**
