<cfcomponent displayname="Two-Factor Authentication" hint="Site-wide settings for two-factor authentication" extends="farcry.core.packages.forms.forms" output="false" key="wbSecurity">

	<cfproperty ftSeq="10" ftFieldset="Two-Factor Authentication" name="bEnabled" type="boolean" default="1" ftDefault="1"
		ftLabel="Enable two-factor authentication"
		ftHint="When off, users are not asked for a code at login and cannot set up two-factor authentication. Existing setups are kept and apply again when this is turned back on." />

	<cfproperty ftSeq="20" ftFieldset="Two-Factor Authentication" name="issuer" type="string" default=""
		ftLabel="Issuer name"
		ftHint="Name shown in the user's authenticator app. Defaults to the site name." />

</cfcomponent>
