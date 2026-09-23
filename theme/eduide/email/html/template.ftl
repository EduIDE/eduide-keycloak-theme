<#--
  EduIDE transactional email layout.

  Replaces base/email/html/template.ftl, which is a bare
  <html><body><#nested></body></html>. Every mail Keycloak sends - verify
  address, reset password, execute actions - renders through this wrapper, and
  all of its copy comes from message keys, so nothing here needs per-mail work.

  Branding is CSS only, with NO image. Remote images are blocked by default in
  most mail clients, inline SVG is poorly supported, and a remote image in a
  transactional mail reads like a tracking pixel to some filters. A teal rule
  and the brand typeface carry the identity instead, and the mail looks
  correct in text-only and image-blocking clients.

  Styles are inline on the elements rather than in a <style> block, because
  several clients strip <head> entirely. Table layout for the same reason.
  Colours are duplicated here rather than shared with login.css - an email
  cannot load an external stylesheet, so this is the one accepted duplication.
  Keep it in step with section 2 of resources/css/login.css when rebranding.
-->
<#macro emailLayout>
<html lang="${locale!'en'}">
<head>
    <meta charset="utf-8" />
    <meta name="color-scheme" content="light" />
</head>
<body style="margin:0; padding:0; background-color:#dbdbdb;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"
           style="background-color:#dbdbdb; padding:24px 12px;">
        <tr>
            <td align="center">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"
                       style="max-width:560px; background-color:#ffffff; border:1px solid rgba(0,0,0,0.14);
                              border-radius:16px; overflow:hidden;">
                    <#-- Brand rule: the same teal-to-orange gradient as the login card. -->
                    <tr>
                        <td style="height:4px; line-height:4px; font-size:0;
                                   background-color:#249ea0;
                                   background-image:linear-gradient(90deg,#249ea0,#f78104);">&nbsp;</td>
                    </tr>
                    <tr>
                        <td style="padding:28px 32px 8px 32px;
                                   font-family:'Anonymous Pro',ui-monospace,SFMono-Regular,Menlo,monospace;
                                   font-size:20px; font-weight:700; color:#1a1a1a;">
                            ${realmName!''}
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:0 32px 28px 32px;
                                   font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;
                                   font-size:15px; line-height:1.6; color:#1a1a1a;">
                            <#nested>
                        </td>
                    </tr>
                </table>
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"
                       style="max-width:560px;">
                    <tr>
                        <td style="padding:16px 32px;
                                   font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;
                                   font-size:12px; line-height:1.5; color:rgba(26,26,26,0.7); text-align:center;">
                            ${msg("emailFooterText")}
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
</#macro>
