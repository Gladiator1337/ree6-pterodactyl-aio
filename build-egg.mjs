import fs from 'node:fs';
import path from 'node:path';

const root = path.dirname(new URL(import.meta.url).pathname);
const installerPath = path.join(root, 'install.sh');
const startPayload = fs.readFileSync(path.join(root, 'scripts/start-all.sh')).toString('base64');
const buildPayload = fs.readFileSync(path.join(root, 'scripts/build-frontend.sh')).toString('base64');

let installer = fs.readFileSync(installerPath, 'utf8');
installer = installer.replace('# SCRIPT_PAYLOADS', `printf '%s' '${startPayload}' | base64 -d > "\${ROOT}/scripts/start-all.sh"\nprintf '%s' '${buildPayload}' | base64 -d > "\${ROOT}/scripts/build-frontend.sh"`);

const variable = (name, description, env, value, rules, viewable = true, editable = true) => ({
  name, description, env_variable: env, default_value: value,
  user_viewable: viewable, user_editable: editable, rules, field_type: 'text'
});

const egg = {
  _comment: 'DO NOT EDIT: FILE GENERATED FOR PTERODACTYL PANEL',
  meta: { version: 'PTDL_v2', update_url: null },
  exported_at: new Date().toISOString(),
  name: 'REE6 All-in-One',
  author: 'admin@megaservers.de',
  description: 'REE6 Bot, Webinterface frontend/backend and private MariaDB in one Pterodactyl server. Requires the bundled custom runtime image.',
  features: null,
  docker_images: {
    'REE6 AIO Runtime 1.1.0': 'ghcr.io/gladiator1337/ree6-pterodactyl-aio:1.1.0'
  },
  file_denylist: [],
  startup: 'bash /home/container/scripts/start-all.sh',
  config: {
    files: JSON.stringify({
      'bot/config/config.yml': { parser: 'yaml', find: {
        'hikari.sql.user': '{{server.build.env.DATABASE_USER}}',
        'hikari.sql.db': '{{server.build.env.DATABASE_NAME}}',
        'hikari.sql.pw': '{{server.build.env.DATABASE_PASSWORD}}',
        'hikari.sql.host': '127.0.0.1',
        'hikari.sql.port': '3306',
        'hikari.misc.storage': 'mariadb',
        'hikari.misc.poolSize': '{{server.build.env.DATABASE_POOL}}',
        'bot.tokens.release': '{{server.build.env.DISCORD_TOKEN}}',
        'bot.misc.ownerId': '{{server.build.env.BOT_OWNER_ID}}',
        'bot.misc.shards': '{{server.build.env.BOT_SHARDS}}',
        'bot.misc.invite': '{{server.build.env.INVITE_URL}}',
        'bot.misc.webinterface': '{{server.build.env.FRONTEND_URL}}',
        'bot.misc.debug': '{{server.build.env.DEBUG}}'
      }},
      'backend/config/config.yml': { parser: 'yaml', find: {
        'hikari.sql.user': '{{server.build.env.DATABASE_USER}}',
        'hikari.sql.db': '{{server.build.env.DATABASE_NAME}}',
        'hikari.sql.pw': '{{server.build.env.DATABASE_PASSWORD}}',
        'hikari.sql.host': '127.0.0.1',
        'hikari.sql.port': '3306',
        'hikari.misc.storage': 'mariadb',
        'hikari.misc.poolSize': '{{server.build.env.DATABASE_POOL}}',
        'discord.bot.tokens.release': '{{server.build.env.DISCORD_TOKEN}}',
        'discord.client.id': '{{server.build.env.DISCORD_CLIENT_ID}}',
        'discord.client.secret': '{{server.build.env.DISCORD_CLIENT_SECRET}}',
        'discord.client.shards': '{{server.build.env.BOT_SHARDS}}',
        'webinterface.discordRedirect': '{{server.build.env.DISCORD_REDIRECT_URL}}',
        'webinterface.twitchRedirect': '{{server.build.env.TWITCH_REDIRECT_URL}}',
        'webinterface.errorRedirect': '{{server.build.env.ERROR_REDIRECT_URL}}',
        'webinterface.loginRedirect': '{{server.build.env.LOGIN_REDIRECT_URL}}',
        'webinterface.allowedDomains': '{{server.build.env.ALLOWED_DOMAINS}}'
      }}
    }),
    startup: JSON.stringify({ done: '[REE6-AIO] All services started' }),
    logs: '{}',
    stop: '^C'
  },
  scripts: { installation: {
    script: installer,
    container: 'ghcr.io/gladiator1337/ree6-pterodactyl-aio:1.1.0',
    entrypoint: 'bash'
  }},
  variables: [
    variable('REE6 Bot Version', 'Patched REE6 version bundled in the selected runtime image.', 'BOT_VERSION', '4.0.12', 'required|in:4.0.12'),
    variable('Webinterface Version', 'Pinned GitHub release tag or latest.', 'WEB_VERSION', '5.0.4', 'required|string|max:30'),
    variable('Discord Bot Token', 'Discord bot token. Admin-only secret.', 'DISCORD_TOKEN', '', 'required|string|max:200', false, false),
    variable('Discord Client ID', 'Discord application/client ID.', 'DISCORD_CLIENT_ID', '', 'required|numeric|digits_between:15,25'),
    variable('Discord Client Secret', 'Discord OAuth client secret. Admin-only secret.', 'DISCORD_CLIENT_SECRET', '', 'required|string|max:200', false, false),
    variable('Bot Owner ID', 'Discord user ID of the bot owner.', 'BOT_OWNER_ID', '', 'required|numeric|digits_between:15,25'),
    variable('Bot Shards', 'Discord shard count.', 'BOT_SHARDS', '1', 'required|integer|min:1|max:100'),
    variable('Temporary Voice Name', 'Template for temporary voice channels. Placeholders: {displayName}, {username}, {number}; legacy %s is the number.', 'TEMPORAL_VOICE_NAME', '🔊 Talk von {displayName}', 'required|string|min:1|max:100'),
    variable('Frontend URL', 'Public frontend URL without trailing slash.', 'FRONTEND_URL', 'https://cp.example.de', 'required|url|max:200'),
    variable('Backend URL', 'Public backend URL without trailing slash; embedded into the frontend build.', 'BACKEND_URL', 'https://api.example.de', 'required|url|max:200'),
    variable('Invite URL', 'Discord OAuth invite link.', 'INVITE_URL', 'https://discord.com/oauth2/authorize', 'required|url|max:500'),
    variable('Discord Redirect URL', 'Discord OAuth redirect URL configured in Discord.', 'DISCORD_REDIRECT_URL', 'https://cp.example.de/login', 'required|url|max:250'),
    variable('Login Redirect URL', 'Frontend login redirect.', 'LOGIN_REDIRECT_URL', 'https://cp.example.de/login', 'required|url|max:250'),
    variable('Error Redirect URL', 'Frontend error redirect.', 'ERROR_REDIRECT_URL', 'https://cp.example.de/error', 'required|url|max:250'),
    variable('Twitch Redirect URL', 'Twitch redirect; retain a valid URL even when Twitch is unused.', 'TWITCH_REDIRECT_URL', 'https://cp.example.de/twitch', 'required|url|max:250'),
    variable('Allowed Domains', 'Backend CORS allowlist in REE6 syntax.', 'ALLOWED_DOMAINS', 'https://cp.example.de', 'required|string|max:500'),
    variable('Backend Port', 'Must equal a secondary allocation assigned to this server.', 'BACKEND_PORT', '8888', 'required|integer|min:1024|max:65535'),
    variable('Database Name', 'Internal MariaDB database.', 'DATABASE_NAME', 'ree6', 'required|regex:/^[A-Za-z0-9_]+$/|max:32'),
    variable('Database User', 'Internal MariaDB user.', 'DATABASE_USER', 'ree6', 'required|regex:/^[A-Za-z0-9_]+$/|max:32'),
    variable('Database Password', '12-64 characters: letters, digits, _.@%+=:-. Admin-only secret.', 'DATABASE_PASSWORD', '', 'required|regex:/^[A-Za-z0-9_.@%+=:-]{12,64}$/', false, false),
    variable('Database Pool', 'Hikari connection pool size.', 'DATABASE_POOL', '10', 'required|integer|min:2|max:30'),
    variable('MariaDB Buffer Pool MB', 'MariaDB InnoDB buffer pool memory.', 'MARIADB_BUFFER_POOL_MB', '256', 'required|integer|min:128|max:1024'),
    variable('Bot Memory MB', 'Java heap limit for the bot.', 'BOT_MEMORY_MB', '1536', 'required|integer|min:512|max:8192'),
    variable('Backend Memory MB', 'Java heap limit for the backend.', 'BACKEND_MEMORY_MB', '768', 'required|integer|min:384|max:4096'),
    variable('Debug', 'Enable REE6 bot debug logging.', 'DEBUG', 'false', 'required|in:true,false'),
    variable('Timezone', 'Container timezone.', 'TZ', 'Europe/Berlin', 'required|string|max:64')
  ]
};

fs.writeFileSync(path.join(root, 'egg-ree6-all-in-one.json'), JSON.stringify(egg, null, 2) + '\n');
