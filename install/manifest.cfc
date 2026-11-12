<!--- @@displayname: Security installation manifest --->
<!--- @@Description: Installation manifest for the Security plugin --->
<!---
1.0 Two-factor authentication (TOTP) for CLIENTUD logins
    Users opt in from the webtop profile menu (QR code + emergency codes)
    Admin: site-wide switch (Admin > Configuration > Two-Factor Authentication) and per-user reset
--->
<cfcomponent extends="farcry.core.webtop.install.manifest" name="manifest">

<cfset this.name = "Security v1.0" />
<cfset this.description = "Two-factor authentication (TOTP) for FarCry logins" />
<cfset this.lRequiredPlugins = "" />
<cfset this.version = "1.0" />
<cfset addSupportedCore(majorVersion="7", minorVersion="0", patchVersion="0") />

</cfcomponent>
