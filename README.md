# Redmine Keycloak OIDC Plugin

Integrates Redmine with Keycloak: web login via OIDC, API authentication with JWT (introspection or JWKS), and group mapping from JWT claims.

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
3. In the client, note **Client ID** and **Client secret** (Credentials tab).

### Endpoints

Either set **Base URL** (e.g. `https://keycloak.example.com/realms/your-realm`) and the plugin can use the well-known endpoint, or set each endpoint manually:

- **Authorization endpoint**: e.g. `https://keycloak.example.com/realms/your-realm/protocol/openid-connect/auth`
- **Token endpoint**: `.../protocol/openid-connect/token`
- **Userinfo endpoint**: `.../protocol/openid-connect/userinfo`
- **Introspection endpoint** (for JWT API): `.../protocol/openid-connect/token/introspect`
- **JWKS URI** (optional): `.../protocol/openid-connect/certs`

### Redirect URI

Register in the client exactly:

`https://your-redmine-host/auth/keycloak/callback`

(Use `http` and the correct port if not using HTTPS. If Redmine uses a relative URL root, include it, e.g. `/redmine/auth/keycloak/callback`.)

## Redmine configuration

Go to **Administration → Keycloak** and:

**Note:** The "Login with Keycloak" button on the login page appears only when **"Enable Keycloak web login"** is checked. If you don't see it, enable that option and reload the login page.

1. Enable **Keycloak web login** and/or **JWT API authentication**.
2. Fill **Keycloak server URL**, **Realm**, **Client ID**, **Client secret**.
3. Fill endpoints (or leave empty to derive from base URL after first save).
4. **Group claim**: claim path for groups/roles (e.g. `realm_access.roles` or `groups`).
5. **Group mapping rules**: pattern → Redmine group. Use `*` as wildcard: `*.admin` matches any role ending in `.admin` (e.g. ACC.admin, PROJECT.admin), `ACC.*` matches all ACC roles. You can add multiple rules; the list of roles in Keycloak can change without reconfiguring each one.
6. **Login button text**: optional custom label for the Keycloak login button (empty = default "Login with Keycloak").

Users are created on first login and synced (attributes and groups) on each login. API requests with `Authorization: Bearer <JWT>` use introspection or JWKS to resolve the user and sync groups.

## Configuration via environment variables

You can pre-fill settings and enable Keycloak using environment variables. Set variables before starting Redmine; they override the values stored in the database (Administration → Keycloak). Useful for Docker, Kubernetes, or automated deployments.

| Variable | Description |
|----------|-------------|
| `KEYCLOAK_ENABLED` | Enable web login. Use `1`, `true`, or `yes` (case-insensitive). |
| `KEYCLOAK_JWT_API_ENABLED` | Enable JWT API authentication. Use `1`, `true`, or `yes`. |
| `KEYCLOAK_JWT_BEFORE_API_KEY` | Check JWT before API key. Any non-empty value enables. |
| `KEYCLOAK_BASE_URL` | Keycloak server base URL (e.g. `https://keycloak.example.com/realms/my-realm`). |
| `KEYCLOAK_REALM` | Realm name (default in UI: `master`). |
| `KEYCLOAK_CLIENT_ID` | Client ID. |
| `KEYCLOAK_CLIENT_SECRET` | Client secret (plain text; avoid logging). |
| `KEYCLOAK_GROUP_CLAIM` | Claim path for groups (e.g. `realm_access.roles`, `groups`). |
| `KEYCLOAK_LOGIN_BUTTON_LABEL` | Custom label for the Keycloak login button. |
| `KEYCLOAK_AUTHORIZATION_ENDPOINT` | Authorization endpoint URL. |
| `KEYCLOAK_TOKEN_ENDPOINT` | Token endpoint URL. |
| `KEYCLOAK_USERINFO_ENDPOINT` | Userinfo endpoint URL. |
| `KEYCLOAK_INTROSPECTION_ENDPOINT` | Introspection endpoint URL (JWT API). |
| `KEYCLOAK_JWKS_URI` | JWKS URI (optional, for JWT verification). |
| `KEYCLOAK_GROUP_MAPPING_RULES` | JSON array of mapping rules (see below). |

**Group mapping from ENV:** set `KEYCLOAK_GROUP_MAPPING_RULES` to a JSON array of objects with `pattern`, `group_id`, and optional `priority` (default 10). Example:

```json
[{"pattern": "*.admin", "group_id": 2, "priority": 10}, {"pattern": "users", "group_id": 3}]
```

If both database rules and `KEYCLOAK_GROUP_MAPPING_RULES` are present, the environment value is used. The form in Administration → Keycloak shows the effective values (database merged with ENV); saving the form only writes to the database and does not change environment variables.

## API usage with JWT

Send the access token in the request:

```http
GET /issues.json
Authorization: Bearer <your_keycloak_access_token>
```

The plugin will validate the token via the introspection endpoint (or JWKS if configured) and set the current user.
