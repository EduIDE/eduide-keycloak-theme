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

Three routes, compared properly in `docs/deployment.md`. **Check first whether
your Keycloak image is built with `--optimized`** - it rules one of them out.

```bash
# A. copy the directory - no JAR, no kc.sh build, no restart.
#    Does not survive a container restart; use it to try the theme out.
cp -r theme/eduide /opt/keycloak/themes/eduide

# B. the provider JAR - one versioned file, but kc.sh build is mandatory.
#    On an --optimized image a JAR without a rebuild makes Keycloak REFUSE
#    TO START, so bake both lines into the image.
./scripts/build-jar.sh 1.0.0
cp dist/eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/
/opt/keycloak/bin/kc.sh build

# C. unpack the release JAR into the themes directory - the Kubernetes answer.
#    Versioned like B, installs like A: no rebuild, works on --optimized.
unzip -o eduide-keycloak-theme-1.0.0.jar "theme/*" -d /tmp/x
cp -r /tmp/x/theme/. /opt/keycloak/themes/
```

Then in the admin console set **Realm settings -> Themes -> Login theme:
`eduide`**, and Email theme `eduide`. `docs/deployment.md` has the init-container
manifest for route C, the realm checklist, the verification command and how to
roll back.

## Configure consent

Two settings and one piece of text. All of it is done in the admin console -
nothing here needs the CLI. Menu labels are Keycloak 26.4 verbatim.

### 1. Switch the consent page on

**Authentication -> Required actions**, row **Terms and Conditions**:

| Toggle | Set to | Why |
|---|---|---|
| **Enabled** | on | Makes the action available at all |
| **Set as default action** | on | Assigns it to every **newly created** user, so they consent at first login |

Then leave the registration form alone. Confirm it is off under
**Authentication -> Flows -> registration**, expand **registration form**, and
check that **Terms and conditions** reads **Disabled**.

**Do not enable both.** Keycloak has two consent surfaces and they do not know
about each other: `RegistrationTermsAndConditions.success()` is an empty method
upstream, so the registration checkbox records nothing and never satisfies the
required action. A user who ticks the box while registering is then shown the
consent page again immediately.

The required action is the one to use because it is the only one that leaves a
record - it writes the acceptance to the `terms_and_conditions` user attribute
as epoch seconds, which is the artifact to point at if anyone asks when someone
consented. The theme styles the in-form checkbox too, for deployments that
prefer it; it is simply not enabled at the same time.

### 2. Put your own statement in

The text this theme ships is a **placeholder on purpose**. It names no data
controller, because a statement naming the wrong one is worse than an obvious
placeholder.

Your text goes in as realm localization overrides, which take precedence over
the theme's own bundle - so **no rebuild and no fork**.

**From the admin console:** *Realm settings -> Localization -> Realm overrides
-> Add translation*. Enable **Internationalization** and add your languages to
**Supported locales** first, on that same page, or there is nowhere to put the
text. The value box takes HTML, so a whole statement pastes in as one block.
Changes are live on the next request - no restart, no cache flush.

| Key | What it is |
|---|---|
| `termsText` | the statement itself, as HTML |
| `termsTitle` | the page heading |
| `acceptTerms` | the checkbox label |
| `acceptTermsHelp` | the hint under the checkbox |
| `termsAcceptanceRequired` | the error shown when the box is not ticked |
| `footerImprintUrl`, `footerPrivacyUrl`, `footerHelpUrl` | footer links, each hidden while its URL is empty |

**Or from a file**, which is better when the statement is long or lives in git:

```bash
./scripts/apply-localization.sh <realm> deploy/localization/eduide-tum-linked.en.json \
                                        deploy/localization/eduide-tum-linked.de.json
```

`deploy/localization/` ships two ready-made variants - one linking to a
statement hosted elsewhere, one carrying the full text inline. Apply one, not
both; `deploy/localization/README.md` compares them.

**Override every locale your realm has enabled.** Keycloak resolves overrides
per locale as `realm-de > theme-de > realm-en > theme-en`, so an English-only
override still leaves German users reading this theme's German placeholder.

### 3. Existing users, and re-consent

*Set as default action* only affects users created **after** it is switched on.
Accounts that already exist are untouched.

- One user: **Users -> the user -> Details -> Required user actions**, add
  **Terms and Conditions**, save. They get the page at their next login.
- After the statement changes: clearing a user's `terms_and_conditions`
  attribute (**Users -> the user -> Attributes**) makes the page appear again.
- Everyone at once: script it over the Admin REST API. The console has no bulk
  edit.

### One limitation, stated plainly

`TermsAndConditions.processAction()` accepts any POST that does not carry
`cancel`, so the checkbox on the consent page is a usability gate rather than a
server-side control - a crafted request can skip it. Enforcing it server-side
would need a custom Java `RequiredActionProvider`, which this repo deliberately
does not ship. The registration-form checkbox *is* server-enforced by its
`validate()` method, which is the trade-off between the two surfaces.

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
| `docs/deployment.md` | installing, the full realm checklist, verifying, rolling back |
| `docs/customising.md` | changing the text, the colours and the logo |
| `deploy/localization/README.md` | the two ready-made statements, and which to pick |
| `docs/development.md` | the dev stack and every page to check |
| `AGENTS.md` | how the theme is built, and the traps |
