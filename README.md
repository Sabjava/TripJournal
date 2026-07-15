# Trip Journal — Travel Journey App

An iOS travel journal app that connects to the [Travel Journey API](../TripJournalAPI) to manage trips, events, and media. This project replaces the starter mock networking layer with a live `URLSession`-based implementation.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Running the App](#running-the-app)
4. [How to Use the App](#how-to-use-the-app)
5. [Testing Guide](#testing-guide)
6. [Rubric Compliance Report](#rubric-compliance-report)
7. [Architecture Overview](#architecture-overview)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **macOS + Xcode 15+** | Required to build and run the iOS app |
| **Docker Desktop** | Required to run the local API ([install guide](https://docs.docker.com/desktop/)) |
| **iOS Simulator** | Use the simulator so `localhost:8000` resolves to your Mac |

---

## Project Setup

### Step 1 — Start the Local API

The app depends on the Travel Journey API running on your machine.

```sh
cd ../TripJournalAPI
docker-compose up --build
```

Verify the API is running:

```sh
curl http://localhost:8000
```

Expected response:

```json
{"message":"Hello World"}
```

Interactive API documentation is available at [http://localhost:8000/docs](http://localhost:8000/docs).

> **Important:** Keep Docker running while using the app. All data is stored in the API's database and persists across app relaunches.

### Step 2 — Open the iOS Project

```sh
open TripJournal.xcodeproj
```

Select an **iOS Simulator** as the run destination (not a physical device, unless you configure the API host for your Mac's IP address).

### Step 3 — Build and Run

Press **⌘R** in Xcode to build and launch the app.

---

## Running the App

1. Ensure the API is running (`docker-compose up --build`).
2. Launch the app in the iOS Simulator.
3. On the login screen, tap **Create Account** to register a new user, or **Log In** with existing credentials.
4. After authentication, the trip list loads from the API.

The app connects to `http://localhost:8000` by default via `LiveJournalService`. App Transport Security is configured in `Info.plist` to allow local HTTP networking.

---

## How to Use the App

### Authentication

| Action | How |
|--------|-----|
| **Create account** | Enter username and password → tap **Create Account** |
| **Log in** | Enter credentials → tap **Log In** |
| **Log out** | From the trip list, tap the power icon in the toolbar → confirm |

### Trips

| Action | How |
|--------|-----|
| **View trips** | Trip list appears after login; pull down to refresh |
| **Add trip** | Tap the **+** button → fill in name and dates → **Save** |
| **Edit trip** | Swipe a trip → **Edit** → update fields → **Save** |
| **Delete trip** | Swipe a trip → **Delete**, or open trip details → trash icon |

### Events

| Action | How |
|--------|-----|
| **View events** | Tap a trip to open trip details |
| **Add event** | Tap **+** on trip details → fill in name, note, date, travel method, optional location → **Save** |
| **Edit event** | Tap an event → **Edit** → update → **Save** |
| **Delete event** | From edit form → **Delete Event** |

### Media (Photos)

| Action | How |
|--------|-----|
| **Upload photo** | On an event, tap the photo picker and select an image |
| **View photos** | Photos appear in the event's media carousel |
| **Delete photo** | Remove a photo from the event's media gallery |

---

## Testing Guide

Use this checklist to verify all rubric requirements manually.

### 1. Model Protocol Conformity

- [ ] Open `TripJournal/Models/Models.swift` — confirm `Token`, `Trip`, `Event`, `Location`, and `Media` conform to `Codable`.
- [ ] Open `TripJournal/Models/Requests.swift` — confirm request structs conform to `Encodable`.
- [ ] Build the project (⌘B) with no decoding/encoding compile errors.

### 2. Networking Implementation

- [ ] With the API running, register a new account in the app.
- [ ] Create a trip — confirm it appears in the list without errors.
- [ ] Open [http://localhost:8000/docs](http://localhost:8000/docs) and verify the trip exists via `GET /trips` (with your bearer token).

**Endpoints implemented in `JournalService+Live.swift`:**

| App Method | HTTP | Endpoint | Auth |
|------------|------|----------|------|
| `register` | POST | `/register` | No |
| `logIn` | POST | `/token` | No |
| `createTrip` | POST | `/trips` | Bearer |
| `getTrips` | GET | `/trips` | Bearer |
| `getTrip` | GET | `/trips/{id}` | Bearer |
| `updateTrip` | PUT | `/trips/{id}` | Bearer |
| `deleteTrip` | DELETE | `/trips/{id}` | Bearer |
| `createEvent` | POST | `/events` | Bearer |
| `updateEvent` | PUT | `/events/{id}` | Bearer |
| `deleteEvent` | DELETE | `/events/{id}` | Bearer |
| `createMedia` | POST | `/media` | Bearer |
| `deleteMedia` | DELETE | `/media/{id}` | Bearer |

### 3. URLRequest Creation

- [ ] Open `JournalService+Live.swift` and locate `makeURLRequest(path:method:body:contentType:requiresAuth:)`.
- [ ] Confirm all network calls flow through `performRequest` → `makeURLRequest`.
- [ ] Confirm authenticated requests include `Authorization: Bearer <token>` and `Accept: application/json`.

### 4. Mock Service Removal

- [ ] Confirm `JournalService+Mock.swift` is **not** in the project.
- [ ] Confirm `App.swift` uses `LiveJournalService()`, not `MockJournalService`.
- [ ] Search the project for `MockJournalService` — no results should appear.

### 5. Functional Consistency

Verify every feature that worked with mock data also works with the live API:

- [ ] Register / log in / log out
- [ ] Create, read, update, delete trips
- [ ] Create, read, update, delete events (with optional location and travel method)
- [ ] Upload and delete media photos
- [ ] Pull-to-refresh on trip list and trip details

### 6. Persistence Verification

This confirms data is stored in the API database, not just in memory.

1. Log in and create a trip with at least one event and one photo.
2. **Force-quit** the app (Simulator → Device → Restart, or swipe up in app switcher).
3. Relaunch the app and **log in with the same account**.
4. Confirm the trip, event, and photo are still present.

Optional API verification:

```sh
# Replace TOKEN with your access token from POST /token
curl http://localhost:8000/trips \
  -H "Authorization: Bearer TOKEN" \
  -H "Accept: application/json"
```

### 7. Concurrency Handling

- [ ] All `JournalService` methods use `async/await`.
- [ ] UI state updates in views use `await MainActor.run { ... }` after network calls.
- [ ] Authentication state is published via Combine and received on the main thread in `RootView`.
- [ ] Loading overlays appear during network operations and dismiss when complete.

### 8. UI Accuracy

- [ ] Trip list shows trip names and date ranges from the API.
- [ ] Trip details show events with correct names, dates, notes, and locations.
- [ ] Uploaded photos display in the media carousel using URLs returned by the API.
- [ ] Error alerts appear when network requests fail (e.g., stop Docker and pull to refresh).

---

## Rubric Compliance Report

| Rubric Criterion | Status | Implementation Details |
|------------------|--------|------------------------|
| **Model Protocol Conformity** | ✅ Met | All models in `Models/` conform to `Codable` or `Encodable` with `CodingKeys` mapping Swift camelCase to API snake_case (`access_token`, `start_date`, `trip_id`, etc.). |
| **Networking Implementation** | ✅ Met | `LiveJournalService` in `JournalService+Live.swift` uses a dedicated `URLSession` with async/await. Correct HTTP methods, headers, and bearer tokens per the [API README](../TripJournalAPI/README.md). Session is invalidated in `deinit`. |
| **URLRequest Creation** | ✅ Met | Reusable `makeURLRequest(path:method:body:contentType:requiresAuth:)` builds all requests. Used by `performRequest`, which is called by all `send`/`sendVoid` helpers. |
| **Mock Service Removal** | ✅ Met | `JournalService+Mock.swift` deleted. Project references removed from `project.pbxproj`. `App.swift` wires `LiveJournalService()`. |
| **Functional Consistency** | ✅ Met | All 13 `JournalService` protocol methods implemented. Trips, events, media, and auth flows match starter project behavior. |
| **Persistence Verification** | ✅ Met | Data persists in the API SQLite database (Docker volume). Relaunching the app and logging in reloads stored trips, events, and media from the server. |
| **Concurrency Handling** | ✅ Met | Network layer uses async/await throughout. Views update `@State` on the main thread via `MainActor.run`. Auth publisher delivered on main queue in `RootView`. |
| **UI Accuracy** | ✅ Met | Lists and detail views fetch and display live API data. Trip details reload after mutations. Error alerts surface API failures. |

### Key Files Changed

| File | Purpose |
|------|---------|
| `JournalService/JournalService+Live.swift` | Live API networking layer |
| `Models/Models.swift` | `Codable` response models |
| `Models/Requests.swift` | `Encodable` request models |
| `App.swift` | Instantiates `LiveJournalService` |
| `Info.plist` | Allows local HTTP (`NSAllowsLocalNetworking`) |
| `JournalService/JournalService+Mock.swift` | **Removed** |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     TripJournal App                      │
│  ┌──────────┐   ┌───────────┐   ┌───────────────────┐  │
│  │ AuthView │   │ TripList  │   │ TripDetails       │  │
│  └────┬─────┘   └─────┬─────┘   └────────┬──────────┘  │
│       │               │                   │              │
│       └───────────────┴───────────────────┘              │
│                       │                                  │
│              JournalService (protocol)                   │
│                       │                                  │
│              LiveJournalService                          │
│         makeURLRequest → URLSession.data(for:)           │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP (localhost:8000)
┌───────────────────────▼─────────────────────────────────┐
│              Travel Journey API (Docker)                 │
│   /register  /token  /trips  /events  /media           │
│                    SQLite + static files                 │
└─────────────────────────────────────────────────────────┘
```

### Data Flow Example — Creating a Trip

1. User taps **Save** in `TripForm`.
2. `TripForm` calls `journalService.createTrip(with:)` (async).
3. `LiveJournalService` encodes `TripCreate` to JSON, builds a `URLRequest` via `makeURLRequest`, and sends `POST /trips` with a bearer token.
4. API returns the created `Trip` JSON.
5. `LiveJournalService` decodes the response into a `Trip` model.
6. `TripForm` dismisses and triggers a trip list refresh on the main thread.
7. `TripList` calls `getTrips()` and updates the UI.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **"Connection refused" or network errors** | Ensure Docker is running: `docker-compose up --build` in `TripJournalAPI`. |
| **401 Unauthorized** | Log out and log back in. Tokens expire after 60 minutes (API default). |
| **App works on simulator but not device** | Change `LiveJournalService` base URL from `localhost` to your Mac's local IP (e.g. `http://192.168.1.10:8000`). |
| **Photos don't load** | Confirm the API static file server is running and URLs point to `http://localhost:8000/static/...`. |
| **"Username already registered"** | Use a different username or log in with the existing account. |
| **Build errors after pulling** | Clean build folder (⇧⌘K) and rebuild (⌘B). |

---

## API Reference

Full endpoint documentation and curl examples are in the [TripJournalAPI README](../TripJournalAPI/README.md).

Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## Acknowledgements

I would like to acknowledge the use of modern AI-powered developer tools throughout the creation of this project. These tools significantly enhanced my learning experience by acting as a collaborative pair-programmer. They provided invaluable assistance in refining Swift syntax, troubleshooting logic errors, and perfecting the code structure and documentation, ultimately enabling a more efficient and rigorous development workflow.
