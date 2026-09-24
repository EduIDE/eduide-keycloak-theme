# Customising the theme

Three seams, in increasing order of effort. Text and links need no rebuild;
colours and logo need a rebuild but no code; anything else is a fork.

## 1. Text and links - no rebuild

Keycloak realm localization overrides take precedence over a theme's message
bundle, so any string this theme renders can be replaced per realm, per locale,
without touching the JAR.

```bash
./scripts/apply-localization.sh <realm> mytexts.en.json mytexts.de.json
```

The file is a flat JSON object of message key to value, and the **locale comes
from the filename**: `<anything>.<locale>.json`.

```json
{
  "termsTitle": "Data protection statement",
  "termsText": "<h2>1. Data controller</h2><p>...</p>",
  "acceptTerms": "I have read the statement and consent",
  "footerPrivacyUrl": "https://example.edu/privacy"
}
```

`deploy/localization/eduide-tum.en.json` and its German sibling are EduIDE's
real statement and double as a worked example.

### Or from the admin console

No CLI needed. **Realm settings -> Localization -> Realm overrides ->
Add translation**, then pick the language and enter the key and value. The value
field takes HTML directly, so a whole statement pastes in as one block.

Two things to know before you start:

- **Internationalization must be on** and the language must be in **Supported
  locales**, on the same Localization page. The overrides tab is organised by
  language, so a language that is not enabled has nowhere to put the text.
- **Changes are live immediately** - no restart and no cache flush. Save, reload
  the consent page, and the new text is there. Verified on Keycloak 26.4.

The script is the better route when the statement is long or you want it in git;
the console is better for a one-line fix.

### Override every locale you have enabled

Precedence resolves per locale:

```
realm-de  >  theme-de  >  realm-en  >  theme-en
```

A realm that overrides only English still serves **this theme's** German text to
German users. This is the single most common way to get a half-translated
consent page.

### The keys worth knowing

| Key | Where it appears |
|---|---|
| `termsTitle` | Heading of the consent page, and the label above the in-form checkbox |
| `termsText` | The statement itself, on both consent surfaces |
| `acceptTerms` | The checkbox label |
| `acceptTermsHelp` | Help text under the checkbox on the consent page |
| `termsAcceptanceRequired` | Validation error when the box is not ticked |
| `footerImprintUrl` / `footerImprintLabel` | Footer link, hidden while the URL is empty |
| `footerPrivacyUrl` / `footerPrivacyLabel` | Footer link, hidden while the URL is empty |
| `footerHelpUrl` / `footerHelpLabel` | Footer link, hidden while the URL is empty |

Any key from Keycloak's own login bundle can be overridden the same way.

### Three rules for message values

These are not style preferences. Breaking any of them corrupts the rendered page
and Keycloak reports nothing.

1. **Every value passes through `MessageFormat`**, even with no arguments.
   Write `''` for a literal apostrophe, and quote braces as `'{'` and `'}'`.
   A lone `'` silently swallows the next character.
2. **`${...}` is substituted from system properties** and environment variables
   before formatting. Never put it in a value.
3. **HTML is sanitized.** Allowed: `p`, `h1`-`h6`, `ul`, `ol`, `li`, `a`,
   `strong`, `em`, `b`, `i`, `br`, `hr`, `div`, `span`, `pre`, `code`,
   `blockquote`, tables. Stripped silently: `details`, `section`, `header`,
   `footer`, `nav`, `button`, `form`, `input`, `script`, `style`, `iframe`.
   Every `<a>` gains `rel="nofollow"`, and `target` may only be `_blank`.

   So a collapsible statement is not available - the theme renders the text in
   a scrolling panel instead, which is CSS and needs no markup from you.

`./scripts/check-messages.sh` enforces rules 1 and 2 on the bundles in this
repo. It cannot see your realm overrides, so apply the rules by hand there.

## 2. Colours and logo - rebuild, no code

Every colour lives in **section 2** of
`theme/eduide/login/resources/css/login.css`, in one `:root` block plus its two
dark-mode counterparts. Nothing else in that file names a colour.

```css
:root {
    --eduide-accent: #249ea0;       /* decorative: borders, stripes, focus */
    --eduide-accent-ink: #14696b;   /* text-safe: links, headings */
    --eduide-accent-warm: #f78104;  /* decorative only */
    --eduide-btn-bg: #1b7a7c;
    ...
}
```

**Why two accent colours.** The brand teal reaches only about 2.8:1 against the
light card, well under the 4.5:1 needed for body text, so it is used for borders
and focus rings while `--eduide-accent-ink` carries links and headings. Orange is
decorative for the same reason. If you replace these, check both light and dark
against a contrast checker - this is a login page, and the focus ring in
particular must stay visible.

The logo is one file, `theme/eduide/login/resources/img/eduide-logo.svg`.
Replace it, and regenerate the favicon from it:

```bash
magick -background none theme/eduide/login/resources/img/eduide-logo.svg \
  -resize 64x64 -define icon:auto-resize=64,48,32,16 \
  theme/eduide/login/resources/img/favicon.ico
```

The favicon must exist. Under `parent=base` there is no favicon upstream to fall
back to, so a missing file means a 404 on every page.

The email template carries its own copy of the palette, inline, because mail
cannot load a stylesheet. Update `theme/eduide/email/html/template.ftl` to match
when you rebrand - it is the one accepted duplication in the repo.

Then `./scripts/build-jar.sh` and redeploy.

### Fonts

Anonymous Pro is vendored under `theme/eduide/login/resources/fonts/` with its
OFL licence, and is used for headings and buttons only. Body text and form
fields use a system sans stack, because a long legal text set in monospace is
hard to read. To change the typeface, replace the `@font-face` blocks in section
1 of the stylesheet and the `--eduide-font-brand` / `--eduide-font-body` tokens.

Nothing is loaded from a third-party host. Keep it that way: a login page whose
purpose is collecting privacy consent should not be making requests to a CDN.

## 3. Dark mode

Light and dark both ship. The theme follows `prefers-color-scheme` and
**intentionally has no toggle**.

The reason is specific and worth not "fixing": the EduIDE app stores its theme
choice in `localStorage` on its own origin, and Keycloak runs on a different
origin. The login page physically cannot read that choice. A toggle here would
create a second, independent preference that silently disagrees with the app the
user is about to enter. The OS preference is the only signal genuinely shared
between the two.

The selectors are written so a toggle could be added later
(`:root[data-theme='dark']` is honoured alongside the media query), but adding
one is a product decision, not a styling one.

## 4. Anything else - fork

Adding or changing templates means editing the theme itself. Before you do, read
the "Only two templates are overridden" section of `AGENTS.md`: most changes that
look like they need a template turn out to need a CSS hook or a `kc*` property,
and every template you take ownership of is one you must re-port on each
Keycloak upgrade.

If you do add one, copy it from the pinned Keycloak tag first and edit from
there. Never write a `registrationLayout` from scratch.
