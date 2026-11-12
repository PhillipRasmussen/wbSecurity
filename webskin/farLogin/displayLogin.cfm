<cfsetting enablecfoutputonly="Yes">
<!--- @@displayname: FarCry UD login form --->
<!--- @@description: Core login form, replaced by the two-factor code step while a code is pending --->

<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin" />

<cfset oClientUD = structKeyExists(application.security.userdirectories, "CLIENTUD") ? application.security.userdirectories.CLIENTUD : "" />

<cfif isObject(oClientUD) AND structKeyExists(oClientUD, "isPending") AND oClientUD.isPending()>
	<skin:view typename="farLogin" template="displayLoginTwoFactor" stParam="#arguments.stParam#" />
<cfelse>
	<cfinclude template="/farcry/core/webskin/farLogin/displayLogin.cfm" />
</cfif>

<cfsetting enablecfoutputonly="No">
