# LaburoBot - Copilot Instructions

## Contexto del proyecto
LaburoBot es un bot de Telegram para conectar clientes con proveedores de servicios (plomeros, electricistas, etc.) al estilo Workana. El bot actúa como tablero de anuncios inteligente: el cliente publica una solicitud, los proveedores postulan con precio y fecha, el cliente elige, y el bot los conecta directamente.

## Stack
- Ruby on Rails 8.1 (API + frontend React on Rails con Shakapacker)
- PostgreSQL
- Telegram Bot API (via `TelegramClient` wrapper de HTTParty)
- WhatsApp Business API (via `WhatsappClient`)
- Deploy en Render (Docker)
- Solid Queue para jobs async

## Arquitectura

### Flujo principal (estilo Workana)
```
Cliente → "necesito plomero" → Bot pide descripción → Bot pide ubicación
→ Crea ServiceRequest (status: open)
→ NotifyProvidersJob notifica proveedores cercanos
→ Proveedores responden "25000 viernes" → Crea Proposal
→ NotifyClientProposalJob avisa al cliente con lista de propuestas
→ Cliente elige "1" → Bot conecta ambos con click-to-chat
→ Bot se sale del medio
```

### Motor central
- `ConversationStateMachine` (app/services/) — rutea cada mensaje según el paso actual del usuario
- `ConversationState` (app/models/) — persiste el estado: `idle → awaiting_category → awaiting_description → awaiting_location → awaiting_provider_selection`
- Para proveedores: `provider_awaiting_proposal`

### Modelos clave
- `User` — cliente o proveedor, identificado por `phone_e164` (o `+tg{id}` para Telegram)
- `ServiceRequest` — solicitud del cliente con status enum: `open → with_proposals → assigned → completed → expired`
- `Proposal` — propuesta del proveedor con `price_cents`, `available_date`, status: `pending → accepted/rejected/expired`
- `ProviderProfile` — perfil del proveedor con categorías y área de servicio
- `Lead` — registro de que un proveedor fue notificado de una solicitud
- `ConversationState` — estado conversacional por usuario/canal
- `Location` — ubicación polimórfica (service_request o provider_profile)
- `Rating` — calificación post-servicio (1-5)

### Servicios
- `ConversationStateMachine.process(...)` — punto de entrada principal
- `NotifyProvidersService.call(service_request)` — busca y notifica proveedores
- `SearchProvidersService.call(category:, location:)` — busca providers matching
- `IntentExtractService.call(text)` — extrae intención (demand/offer) con keywords o LLM
- `CategoryNormalizeService.normalize(raw)` — normaliza categorías
- `LocationNormalizeService.normalize(raw)` — normaliza ubicaciones
- `ClickToChatService` — genera links wa.me/t.me para conectar
- `RateLimitService` — caps de entregas por request/día
- `ServiceCategories::CATALOG` — catálogo de categorías argentinas

### Jobs
- `NotifyProvidersJob` — async: notifica proveedores al crear solicitud
- `NotifyClientProposalJob` — async: avisa al cliente de nuevas propuestas
- `NotifyProviderAcceptedJob` — async: avisa al proveedor que lo eligieron
- `ExpireRequestsJob` — cron: expira solicitudes viejas (24hs)

### Controllers
- `Telegram::WebhooksController` — recibe webhooks de Telegram, delega a `ConversationStateMachine`
- `Whatsapp::WebhooksController` — recibe webhooks de WhatsApp
- `Admin::DashboardController` — panel admin

## Convenciones
- Servicios en `app/services/` con método `.call` o `.process`
- Jobs async en `app/jobs/` con `perform_later`
- Modelos usan `enum` con `prefix: true` (ej: `status_open?`, `role_provider?`)
- Respuestas del bot en español argentino informal (vos, tuteo)
- IDs sintéticos de Telegram: `+tg{user_id}` en campo `phone_e164`
- Variables sensibles (tokens) van en env vars de Render, NO en Dockerfile ni repo
- Tests en `test/` (Minitest)
- Frontend React en `app/javascript/`