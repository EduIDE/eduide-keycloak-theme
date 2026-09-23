# EduIDE Keycloak theme

The login and email theme for EduIDE. It gives Keycloak the EduIDE look, and it
puts a data protection statement in front of users as something they read and
tick before they can continue.

**This repository is a theme, not a Keycloak deployment.** It builds one JAR
that you drop into a Keycloak you already run. It ships no server, no realm and
no institution's branding beyond EduIDE's own.

| | |
|---|---|
| Theme name | `eduide` |
| Types | `login`, `email` |
| Keycloak | 26.0 and newer (developed and verified against 26.4) |
| Artifact | `eduide-keycloak-theme-<version>.jar`, attached to each release |
| Licence | EPL-2.0 |

## What it looks like

A centred card on a soft teal-to-orange wash, with the EduIDE mark above it.
Brand teal `#249EA0` and orange `#F78104` come straight from the EduIDE logo.
Headings and buttons are set in Anonymous Pro, self-hosted rather than pulled
from Google Fonts; form fields and the statement body use a system sans,
because a multi-section legal text set in monospace is not readable.

Light and dark both ship, chosen from `prefers-color-scheme`. There is
deliberately no theme toggle - see "Dark mode" in `docs/customising.md`.

## Install

```bash
# 1. build
./scripts/build-jar.sh 1.0.0

# 2. drop it in, on the Keycloak host
cp dist/eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/

# 3. a new provider JAR needs a rebuild - an --optimized image will NOT
#    pick the theme up without this
/opt/keycloak/bin/kc.sh build

# 4. restart Keycloak, then in the admin console:
#    Realm settings -> Themes -> Login theme: eduide, Email theme: eduide
```

Then enable consent and apply your own statement. `docs/deployment.md` has the
full checklist, the verification command and how to roll back.

## Replacing the data protection statement

The text this theme ships is a **placeholder on purpose**. It names no data
controller, because a statement naming the wrong one is worse than an obvious
placeholder.

Your own text goes in as Keycloak realm localization overrides, which take
precedence over the theme bundle - so **no rebuild and no fork**:

```bash
./scripts/apply-localization.sh <realm> deploy/localization/eduide-tum.en.json \
                                        deploy/localization/eduide-tum.de.json
```

Those two files are EduIDE's real statement for the TUM deployment, and double
as a worked example of the format. Copy them, edit the text, apply.

**Override every locale your realm has enabled.** Keycloak resolves overrides
per locale as `realm-de > theme-de > realm-en > theme-en`, so an English-only
override still leaves German users reading this theme's German text.

## Develop

```bash
docker compose up                 # http://127.0.0.1:8080, admin / admin
```

Two realms are imported, theme caches are off so `.ftl` and `.css` edits show
on refresh, and Mailpit catches outgoing mail at http://127.0.0.1:8025.
`docs/development.md` lists the URL for every page worth looking at.

```bash
./scripts/check-messages.sh       # message bundles
./scripts/check-theme.sh          # theme structure + upstream drift
```

## Documentation

| | |
|---|---|
| `docs/deployment.md` | installing, realm settings, verifying, rolling back |
| `docs/customising.md` | changing the text, the colours and the logo |
| `docs/development.md` | the dev stack and every page to check |
| `AGENTS.md` | how the theme is built, and the traps |
