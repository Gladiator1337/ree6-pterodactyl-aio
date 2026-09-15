# REE6 All-in-One Egg for Pterodactyl

This package runs REE6 Bot, Webinterface Backend, Webinterface Frontend, and a private MariaDB in one Pterodactyl server.

## Components

- REE6 Bot `4.0.12` (Java 21)
- REE6 Webinterface `5.0.4` (Java 21 + Node 22)
- MariaDB bound to `127.0.0.1:3306`
- One primary frontend allocation plus one additional backend allocation

## 1. Publish the runtime image

Create a GitHub repository, copy this package into it, and push to `main`. The included GitHub Actions workflow publishes:

`ghcr.io/OWNER/ree6-pterodactyl-aio:1.0.0`

Set the package visibility to public or configure Wings to authenticate to GHCR.

## 2. Adapt and import the egg

Open `egg-ree6-all-in-one.json` and replace `gladiator1337` in both Docker image fields if your GitHub owner differs. Then import the JSON under **Admin > Nests > Import Egg**.

## 3. Create the server

Assign two allocations to the same Pterodactyl server:

- Primary allocation: frontend, for example `3000`
- Additional allocation: backend, for example `8888`

Set `BACKEND_PORT` to the additional allocation port. Wings must permit this port for the server.

Recommended resources: 3-4 GB RAM, two CPU threads, 10 GB disk.

## 4. Required values

- Discord bot token
- Discord application/client ID and secret
- Bot owner Discord user ID
- Frontend public URL, e.g. `https://cp.example.de`
- Backend public URL, e.g. `https://api.example.de`
- Invite URL
- Random database password (12-64 characters; allowed: letters, digits, `_.@%+=:-`)

Configure Discord OAuth redirects for the frontend URLs entered in the egg.

## Reverse proxy

Create separate proxy hosts for frontend and backend. Forward WebSockets and preserve `Host`, `X-Forwarded-For`, and `X-Forwarded-Proto` headers. TLS should terminate at the proxy.

## Persistence and updates

Persistent paths are `database/`, `bot/`, and `backend/`. Reinstall updates runtime files while retaining those paths. Pin versions using `BOT_VERSION` and `WEB_VERSION`; do not use blind updates on every boot.

## Important limitation

This is a multi-process container by design. If any critical service exits, the startup supervisor stops the server so Pterodactyl can detect and restart the crash.

The supervisor starts the REE6 bot first and waits for JDA's `Finished Loading!` marker before it starts the webinterface backend. A further ten-second gap serializes the two Discord `IDENTIFY` operations. This prevents the bot and backend, which use independent JDA sessions for the same Discord application, from entering a mutual reconnect loop during startup.

The backend is deliberately given its config path through the lowercase `config` environment variable. Webinterface 5.0.4 has a command-line parser defect for `--config=...`; using that form can silently select the wrong file and fall back to SQLite.

Webinterface 5.0.4 also returns `Failed to update` when the first ticket configuration is saved without an existing `Tickets` row. The startup supervisor includes a compatibility guard that maintains a disabled zero-value placeholder for known guilds, allowing ticket setups to be created again after removal. Remove this guard when an upstream release fixes `GuildService.updateTicket()`.
