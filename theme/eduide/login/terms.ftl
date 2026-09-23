<#--
  Consent page for the TERMS_AND_CONDITIONS required action.

  Differs from the stock base/login/terms.ftl in one way: an explicit consent
  checkbox in front of the Accept button, so agreeing is a deliberate act
  rather than a side effect of clicking the only prominent control.

  Two details that matter:

  - The checkbox is gated with the native HTML5 `required` attribute, not
    JavaScript. It works with scripting switched off entirely, needs no
    disabled-button state to re-enable, and creates no keyboard trap.

  - Decline carries `formnovalidate`. Without it the browser would also block
    Decline while the box is unticked, stranding a user who does not consent
    with no way off the page - a worse failure than having no checkbox at all.
    base/login/login-verify-email.ftl uses formnovalidate the same way.

  The acceptance is recorded by Keycloak as the `terms_and_conditions` user
  attribute, holding the epoch seconds of the moment Accept was submitted.
  Note that the server accepts any POST that does not carry `cancel`, so this
  checkbox is a UX gate rather than a server-side control - see docs.
-->
<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=false; section>
    <#if section = "header">
        ${msg("termsTitle")}
    <#elseif section = "form">
        <div id="kc-terms-text" tabindex="0" role="region" aria-label="${msg("termsTitle")}">
            ${kcSanitize(msg("termsText"))?no_esc}
        </div>

        <form class="form-actions ${properties.kcFormClass!}" action="${url.loginAction}" method="POST">
            <div class="eduide-terms__consent ${properties.kcInputClassCheckbox!}">
                <input type="checkbox" id="termsAccepted" name="termsAccepted" required
                       class="${properties.kcCheckboxInputClass!}"
                       aria-describedby="terms-accept-help" />
                <label for="termsAccepted" class="${properties.kcInputClassCheckboxLabel!}">
                    ${msg("acceptTerms")}
                </label>
                <p id="terms-accept-help" class="eduide-helper">${msg("acceptTermsHelp")}</p>
            </div>

            <div id="kc-form-buttons" class="${properties.kcFormButtonsClass!}">
                <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!}"
                       name="accept" id="kc-accept" type="submit" value="${msg("doAccept")}" />
                <button class="${properties.kcButtonClass!} ${properties.kcButtonDefaultClass!} ${properties.kcButtonBlockClass!}"
                        name="cancel" id="kc-decline" type="submit" formnovalidate>${msg("doDecline")}</button>
            </div>
        </form>
        <div class="clearfix"></div>
    </#if>
</@layout.registrationLayout>
