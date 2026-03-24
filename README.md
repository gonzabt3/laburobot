# LaburoBot 🤖

A WhatsApp-first local-services marketplace bot for Argentina. Connects clients (people who need a service) with providers (people who offer services) via click-to-chat links — no payments, no in-app messaging.

## Architecture Overview

```
User (Telegram / WhatsApp)
         │
         ▼
  Channel Adapter
  (Telegram or WhatsApp webhook controller)
         │
         ▼
  ConversationRouter
  ├── IntentExtractService  (AI / stub)
  ├── CategoryNormalizeService
  ├── LocationNormalizeService
  ├── SearchProvidersService
  ├── RateLimitService
  └── ClickToChatService
         │
         ▼
  Domain Models (Postgres)
  Users, ProviderProfiles, ServiceRequests, Leads, Ratings, Reports

         │
         ▼
  Admin UI (React via react_on_rails)
```

### Channel Adapter Pattern

The codebase uses a channel-adapter pattern:
- `app/controllers/telegram/webhooks_controller.rb` — Telegram adapter
- `app/controllers/whatsapp/webhooks_controller.rb` — WhatsApp adapter placeholder

Each adapter normalizes the inbound message and calls `ConversationRouter.route(...)`. Adding a new channel only requires a new controller.

---

## Prerequisites

- Ruby 3.2+
- Node 18+ and npm (or yarn)
- PostgreSQL 14+
- Bundler

---

## Setup

### 1. Clone and Install

```bash
git clone https://github.com/gonzabt3/laburobot
cd laburobot
bundle install
npm install
```

### 2. Environment Variables

Copy the example env file and fill in values:

```bash
cp .env.example .env
```

**Required for Telegram:**
```
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
```

**Required for WhatsApp (when ready):**
```
WHATSAPP_TOKEN=your_meta_cloud_api_token
WHATSAPP_PHONE_NUMBER_ID=your_phone_number_id
WHATSAPP_VERIFY_TOKEN=a_secret_you_choose
WHATSAPP_APP_SECRET=your_meta_app_secret
```

**Admin panel:**
```
ADMIN_USERNAME=admin
ADMIN_PASSWORD=changeme
```

**AI (optional — stub works without keys):**
```
OPENAI_API_KEY=sk-...
LLM_PROVIDER=openai
OPENAI_MODEL=gpt-4o-mini
```

**Location geocoding (optional):**
```
GEOCODE_API_KEY=your_google_maps_key
```

### 3. Database

```bash
rails db:create db:migrate
# In test environment:
rails db:test:prepare
```

---

## Running the Dev Server

```bash
./bin/dev
```

This starts Rails + webpack dev server together (via Foreman / Overmind).

Open [http://localhost:3000/admin](http://localhost:3000/admin) for the admin panel.

---

## Configuring the Telegram Webhook

1. Create a bot via [@BotFather](https://t.me/BotFather) and copy the token into `TELEGRAM_BOT_TOKEN`.
2. Your server must be publicly reachable over HTTPS. For local dev, use [ngrok](https://ngrok.com/):
   ```bash
   ngrok http 3000
   ```
3. Set the webhook URL:
   ```bash
   curl -X POST "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
        -H "Content-Type: application/json" \
        -d '{"url": "https://<your-ngrok-url>/telegram/webhook"}'
   ```
4. Verify:
   ```bash
   curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo"
   ```

The webhook endpoint is `POST /telegram/webhook`.

---

## Admin Panel

The admin panel is a React app (via react_on_rails) at `/admin`.

- **Dashboard** — platform stats (users, requests, leads, reports)
- **Providers** — list and toggle provider profiles active/inactive
- **Reports** — view and moderate user reports

Default credentials: `admin / changeme` (set via env vars `ADMIN_USERNAME` / `ADMIN_PASSWORD`).

---

## AI Layer

`IntentExtractService` is the AI adapter. Without API keys it uses a deterministic keyword-based stub. To use a real LLM:

```env
OPENAI_API_KEY=sk-...
LLM_PROVIDER=openai
OPENAI_MODEL=gpt-4o-mini
```

The service extracts:
- `intent`: `demand` or `offer`
- `category_raw`: raw service category text
- `location_raw`: raw location text
- `urgency`: `urgent`, `today`, `this_week`, or `flexible`
- `missing_fields`: array of fields the user hasn't provided yet

---

## Extending to WhatsApp

1. Obtain WhatsApp Cloud API credentials from [Meta for Developers](https://developers.facebook.com/docs/whatsapp/cloud-api).
2. Set the required env vars (`WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`).
3. Implement `WhatsappClient.send_text` in `app/lib/whatsapp_client.rb` (the stub raises `NotImplementedError`).
4. Configure your Meta app's webhook to point to `GET /whatsapp/webhook` (verification) and `POST /whatsapp/webhook` (messages).

The `Whatsapp::WebhooksController` already parses incoming messages and routes them through `ConversationRouter` — the same logic used by Telegram.

---

## Running Tests

```bash
rails test
```

Tests cover:
- Model validations (User, ProviderProfile)
- Service logic (RateLimitService, ClickToChatService, IntentExtractService, CategoryNormalizeService)

---

## Domain Models

| Model           | Key Fields |
|-----------------|------------|
| User            | phone_e164, role (client/provider), status, consent_at |
| ProviderProfile | categories, description, active, service_area_type, max_distance_km |
| Location        | polymorphic, country, admin_area_1 (province), locality, lat/lng, raw_text |
| ServiceRequest  | client_user, category, location, details, urgency, needed_at |
| Lead            | service_request, provider_user, delivered_at |
| Rating          | lead, score (1–5), comment |
| Report          | reporter_user, target_user, reason, status |
