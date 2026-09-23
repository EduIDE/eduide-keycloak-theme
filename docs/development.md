# Developing the theme

## The stack

```bash
docker compose up
```

| | |
|---|---|
| Keycloak | http://127.0.0.1:8080 - admin console `admin` / `admin` |
| Mailpit | http://127.0.0.1:8025 - catches everything Keycloak sends |

Ports bind `127.0.0.1` explicitly. OrbStack does not publish containers to
`localhost` on its own, and an unqualified mapping would also expose Keycloak on
the local network. Under OrbStack `http://eduide-keycloak-dev.orb.local` also
resolves, if you prefer a hostname.

The theme directory is bind-mounted and all three theme caches are off, so
**`.ftl` and `.css` edits show on refresh**. A `theme.properties` change needs
`docker compose restart keycloak`.

Two realms are imported at startup; see `dev/README.md` for what each is for
and why there are two.

## Pages worth looking at

All URLs are for realm `eduide-dev`. The client is `eduide-dev`.

Set `AUTH` once:

```bash
B=http://127.0.0.1:8080
R=$B/realms/eduide-dev
AUTH="$R/protocol/openid-connect/auth?client_id=eduide-dev&response_type=code&scope=openid&redirect_uri=$R/account/"
```

| Page | How to reach it |
|---|---|
| Login | open `$AUTH` |
| Consent (required action) | log in as `terms@example.com` / `password` |
| Registration | replace `/auth?` with `/registrations?` in `$AUTH` |
| Registration **with** the in-form checkbox | same, against realm `eduide-dev-regterms` |
| Forgot password | the "Forgot Password?" link on the login page |
| Verify email, and the branded mail | register a new user, then read Mailpit |
| Error | `$R/protocol/openid-connect/auth?client_id=does-not-exist&response_type=code` |
| Page expired | leave the login page open, restart Keycloak, submit |
| Logout confirm | `$R/protocol/openid-connect/logout` with no `id_token_hint` |
| German | append `&ui_locales=de` to `$AUTH`, or use the language switcher |

To see the consent page again for a user who already accepted, delete their
`terms_and_conditions` attribute or re-add the `TERMS_AND_CONDITIONS` required
action in the admin console.

## Checks

```bash
./scripts/check-messages.sh     # bundles: missing keys, en/de drift, escaping
./scripts/check-theme.sh        # structure, resource paths, upstream kc* drift
./scripts/check-agents-md.sh    # every path named in AGENTS.md exists
```

These are what CI runs. **They do not render a single page** - nothing in CI
boots Keycloak. A change that breaks a template still goes green, so look at the
pages before you push.

`check-theme.sh` and `check-messages.sh` fetch Keycloak's base theme from GitHub
via `gh` and cache it under the temp directory. Without `gh`, or offline, they
skip those checks and say so rather than failing.

To test against a different Keycloak:

```bash
KEYCLOAK_TAG=26.7.0 ./scripts/check-theme.sh
```

## Testing the JAR path

The dev stack bind-mounts a directory; a real deployment loads a JAR. To check
the artifact itself:

```bash
./scripts/build-jar.sh
docker compose --profile jar up -d keycloak-jar     # http://127.0.0.1:8081
```

This is what proves a plain `zip` archive really is a loadable theme provider,
since CI never boots Keycloak. Worth re-running whenever `scripts/build-jar.sh`
changes.

## Adding a template

Don't, if a CSS hook or a `kc*` property in `theme/eduide/login/theme.properties`
would do - see `AGENTS.md`. If you must:

1. Copy the file from the pinned Keycloak tag, verbatim:

   ```bash
   gh api -H "Accept: application/vnd.github.raw" \
     "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login/<name>.ftl?ref=26.4.0" \
     > theme/eduide/login/<name>.ftl
   ```

2. Edit only what you need, and keep every `<#nested>` section and macro
   argument intact.
3. Check the page in a browser, and check the container log for FreeMarker
   errors - a broken template often still returns HTTP 200 with a missing
   fragment.

## Tearing down

```bash
docker compose down            # keeps nothing; the dev realms re-import next time
```

There is no database volume. Every `up` starts from the imported realms, which
is deliberate: it keeps the fixtures honest.
