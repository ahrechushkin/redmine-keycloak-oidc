# Redmine Keycloak OIDC Plugin

Integrates Redmine with Keycloak: web login via OIDC, API authentication with JWT (introspection or optional JWKS fallback), and group mapping from JWT claims.

## Installation

1. Copy or symlink this plugin into Redmine's plugins directory:
   ```bash
   ln -s /path/to/redmine-keycloak-oidc /path/to/redmine/plugins/redmine_keycloak_oidc
   ```
2. Restart Redmine.

## Keycloak setup

### Realm and client

1. In Keycloak Admin create a realm (or use `master`).
2. Create a **Client** (e.g. `redmine`):
   - **Client authentication**: ON (confidential client).
   - **Valid redirect URIs**: your Redmine callback URL, e.g. `https://redmine.example.com/auth/keycloak/callback`.
   - **Web origins**: your Redmine base URL if needed.
3. Note **Client ID** and **Client secret** (Credentials tab).

### Endpoints

Set **Base URL** (full realm URL `https://keycloak.example.com/realms/your-realm` or host `https://keycloak.example.com` plus **Realm** in the form), or set each endpoint manually.

If **Introspection endpoint** is empty, the plugin uses Keycloak’s default path:

`{issuer}/protocol/openid-connect/token/introspect`

where **issuer** comes from Base URL + Realm, or from **Userinfo** / **Token** / **Authorization** URL (the part before `/protocol/openid-connect/`).

- **JWKS URI** is optional and only used if you enable the unsigned-JWT fallback; introspection is recommended for production.

### Redirect URI

Register in the client:

`https://your-redmine-host/auth/keycloak/callback`

(Include relative URL root if needed, e.g. `/redmine/auth/keycloak/callback`.)

## Redmine configuration

**Administration → Keycloak**

1. Enable **Keycloak web login** and/or **JWT API authentication**.
2. Set **Base URL**, **Realm**, **Client ID**, **Client secret**.
3. Endpoints can be left partial if issuer is derivable (see above).
4. **Group claim** and **group mapping rules** as needed.

Enable **REST API** in Redmine global settings when using the API.

## Configuration via environment variables

| Variable | Description |
|----------|-------------|
| `KEYCLOAK_ENABLED` | Web login: `1`, `true`, or `yes`. |
| `KEYCLOAK_JWT_API_ENABLED` | JWT API: `1`, `true`, or `yes`. |
| `KEYCLOAK_JWT_BEFORE_API_KEY` | Non-empty value enables checking JWT before API key (default in UI is on). |
| `KEYCLOAK_BASE_URL` | Keycloak base / realm URL. |
| `KEYCLOAK_REALM` | Realm name (default in UI: `master`). |
| `KEYCLOAK_CLIENT_ID` | Client ID. |
| `KEYCLOAK_CLIENT_SECRET` | Client secret. |
| `KEYCLOAK_GROUP_CLAIM` | Claim path for groups. |
| `KEYCLOAK_*_ENDPOINT` | Override OIDC endpoints if needed. |
| `KEYCLOAK_GROUP_MAPPING_RULES` | JSON array of `{ "pattern", "group_id", "priority" }`. |

## API usage with JWT

```http
GET /issues.json
Authorization: Bearer <keycloak_access_token>
```

The plugin validates the token via **introspection** (same **client_id** / **client_secret** as web login). Check `log/production.log` (or `development.log`) for lines prefixed with `[redmine_keycloak_oidc]` if something fails.

### Troubleshooting

- Use **`/issues.json`** (or `.xml` / `?format=json`) — plain `/issues` is not a REST API request for Redmine.
- **`Doorkeeper::AccessToken` in logs** — Redmine looks up Bearer tokens in its own OAuth table; Keycloak tokens are not there. This plugin runs **before** that when JWT API is enabled and a Bearer token is present.
- **401** — Enable **JWT API** in Administration → Keycloak; ensure **REST API** is enabled; send a valid Keycloak access token; configure **Base URL** / introspection so validation can reach Keycloak.
