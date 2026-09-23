# Deploying the EduIDE Keycloak theme

For whoever administers the Keycloak. Nothing here assumes EduIDE ran it, and
nothing here is specific to one institution.

## What you are installing

A login theme and an email theme, both named `eduide`, installed either as a
directory or as a provider JAR. Either way the install is **server-wide but
inert**: it adds an option to the Themes dropdown and changes nothing for any
realm until a realm selects it. If this Keycloak also serves other realms, they
are unaffected.

Requires Keycloak **26.0 or newer**.

## 1. Install the theme

Two ways. Both are supported by Keycloak and both are verified against 26.4;
pick on how your Keycloak is operated, not on which looks cleaner.

### Option A - copy the directory (no JAR, no build step)

Keycloak reads themes straight out of `/opt/keycloak/themes/`. The contents of
`theme/` in this repo map one-to-one onto it, so installing is a copy of a
single directory:

```bash
cp -r theme/eduide /opt/keycloak/themes/eduide
```

That is the whole install. No JAR, no `META-INF/keycloak-themes.json`, **no
`kc.sh build`, and no restart** - the theme appears in the Themes dropdown
immediately, and later edits to `.ftl` and `.css` files are picked up on the
next request. All of that was verified on a Keycloak 26.4 running in production
mode, not inferred from dev mode.

The catch is persistence, and it is the thing that actually bites. A copy into
a running container lives in the container filesystem and **is gone on the next
restart**. So on Kubernetes this only works as a real install if the directory
is mounted, typically from a ConfigMap:

- the theme is 18 files, 168 KB, which fits a ConfigMap
- but five of them are binary - four `.woff2` and `favicon.ico` - so they must
  go in `binaryData` as base64, not `data`
- and there is no version stamp anywhere, so `kubectl` cannot tell you which
  build of the theme is live

Use Option A when you have shell or volume access to the Keycloak and want the
shortest path, or while iterating on a staging instance.

### Option B - the provider JAR

```bash
./scripts/build-jar.sh 1.0.0
cp dist/eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/
/opt/keycloak/bin/kc.sh build          # required; see below
```

Then restart Keycloak.

**The rebuild is the step that gets missed.** A container started with
`--optimized` will **not** pick up a new provider JAR until it is rebuilt - the
server starts cleanly, logs nothing unusual, and the theme simply does not
appear.

In exchange you get one file with a version in its name, so what is deployed is
identifiable and a rollback is a file swap. Bake it into the Keycloak image
with `COPY eduide-keycloak-theme-<version>.jar /opt/keycloak/providers/`, or
mount it from a volume.

Use Option B when someone else operates the Keycloak, when the image is built
in CI, or whenever "which version is live?" needs an answer.

### Which to ask TUM for

If EduIDE's realm lives on a Keycloak that TUM builds as an image, Option B is
the one that fits their pipeline: a single versioned artifact from our releases
page, added to their image. Option A asks them to carry 18 loose files with no
version on them.

If they would rather mount a directory, Option A is legitimate and cheaper for
them - just be explicit that a theme update then has no version to point at, and
agree how it is rolled back.

### Browser caching applies to both

Theme resources are served with `Cache-Control: max-age=2592000` - 30 days -
under a path like `/resources/<hash>/login/eduide/css/login.css`. That `<hash>`
is Keycloak's own resource version: **it does not change when the theme
changes.** So updating the stylesheet in place leaves returning visitors on the
old CSS until their cache expires.

This is true of the JAR route as well; it is a property of Keycloak themes, not
of how you installed one. In practice it means: change wording through realm
localization overrides (step 4), which are not cached this way, and expect a
CSS or template change to reach returning users gradually unless the Keycloak
version also changed.

## 2. Select the theme

Admin console, on the realm that should use it:

- **Realm settings -> Themes -> Login theme** -> `eduide`
- **Realm settings -> Themes -> Email theme** -> `eduide`

If the dropdown does not list `eduide`, step 1 did not take effect - almost
always the missing `kc.sh build`.

## 3. Configure the realm

The theme renders what the realm asks for. These settings are what turn it into
a working login, registration and consent experience.

| Where | Setting | Value |
|---|---|---|
| Realm settings -> Login | User registration | On, if users may self-register |
| Realm settings -> Login | Forgot password | On |
| Realm settings -> Login | Verify email | On, if registration is on |
| Realm settings -> Localization | Internationalization | On, with `en` and `de` |
| Realm settings -> Email | SMTP | Configured, or no mail is sent at all |
| Authentication -> Required actions | **Terms and Conditions** | Enabled, **Set as default action** on |
| Authentication -> Flows -> registration -> registration form | Terms and conditions | **Disabled** |

### Why consent is configured this way

Keycloak offers two consent surfaces, and **you want exactly one of them**.

*Terms and Conditions* as a required action shows the consent page after login
and records the acceptance as the `terms_and_conditions` user attribute,
holding the epoch seconds of the moment Accept was submitted. That attribute is
the artifact to point at if anyone asks when a user consented.

The registration-form checkbox is the other surface. Upstream,
`RegistrationTermsAndConditions.success()` is an empty method: the checkbox is
validated and then **nothing is recorded** and the required action is not
marked satisfied. Enable both and a user who just ticked the box during
registration is shown the consent page again immediately.

So: required action on and set as a default action, registration execution
disabled. Consent then happens once, for new and existing users alike, and is
recorded.

If you prefer in-form consent instead, invert the two settings and accept that
nothing is recorded and existing users never consent. `dev/realm-eduide-registration-terms.json`
shows that configuration.

**One honest limitation.** `TermsAndConditions.processAction()` accepts any POST
that does not carry `cancel`, so the checkbox on the consent page is a usability
gate rather than a server-side control - a crafted request can skip it.
Enforcing it server-side would need a custom Java `RequiredActionProvider`,
which this repo deliberately does not ship. The registration-form checkbox, by
contrast, *is* server-enforced by its `validate()` method.

## 4. Install your data protection statement

**The text shipped in the theme is a placeholder.** It states that no statement
has been published, and names no data controller - a statement naming the wrong
controller would be worse. Replace it before real use.

Your text goes in as realm localization overrides, which take precedence over
the theme bundle, so this needs no rebuild and no fork:

```bash
./scripts/apply-localization.sh <realm> \
    deploy/localization/eduide-tum.en.json \
    deploy/localization/eduide-tum.de.json
```

Those two files are EduIDE's statement for the TUM deployment; copy them, edit
the text, and apply your own. The same mechanism sets the footer links
(`footerImprintUrl`, `footerPrivacyUrl`, `footerHelpUrl`) - each link is hidden
while its URL is empty, so a realm that sets nothing gets a clean footer rather
than dead links.

**Override every locale the realm has enabled.** Keycloak resolves overrides per
locale, as `realm-de > theme-de > realm-en > theme-en`. Overriding only English
leaves German users reading the theme's German placeholder.

`docs/customising.md` covers the format, the HTML that survives sanitization,
and the escaping rules.

### Re-consent after the statement changes

Removing the `terms_and_conditions` attribute from a user puts them back through
the consent page on next login. To re-consent everyone, clear that attribute for
all users, or add the `TERMS_AND_CONDITIONS` required action to them, via the
Admin REST API.

## 5. Verify

```bash
curl -s "https://<keycloak-host>/realms/<realm>/protocol/openid-connect/auth\
?client_id=<client>&response_type=code&scope=openid&redirect_uri=<redirect>" \
  | grep -o 'resources/[^/]*/login/[a-z]*'
```

Prints `resources/<hash>/login/eduide` when the theme is live.

Then look at the pages themselves: the login form, the consent page, and - if
registration is on - the registration form. `docs/development.md` lists how to
reach each one.

## Rolling back

Clear the Login theme and Email theme fields on the realm. It takes effect
immediately: no restart, no redeploy, and the theme can stay installed.

To roll back to an older *version* of the theme, replace the JAR and rebuild
(Option B), or re-copy the directory from the tag you want (Option A). Option B
is the one where "which version is live" has an answer without diffing files.

## Operational notes

- **Leave theme caching on in production.** The `--spi-theme-cache-themes`,
  `--spi-theme-cache-templates` and `--spi-theme-static-max-age` flags in
  `docker-compose.yml` exist so edits show up during development. In production
  they cost you page-render performance for nothing, and a JAR swap needs a
  restart regardless.
- **Content Security Policy.** The theme loads no third-party scripts, styles,
  fonts or images - fonts are self-hosted and icons are inline CSS - so it works
  under a strict CSP. It does rely on inline `<script type="module">` blocks
  that Keycloak itself emits for session checking; a CSP forbidding inline
  scripts would break those for every theme, not just this one.
- **German message fallback.** Keycloak's own German bundle ships in the
  community distribution. On a build that omits it, inherited strings fall back
  to English while the keys this theme defines still translate.
