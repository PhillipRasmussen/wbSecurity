<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Summary options (CLIENTUD) --->
<!--- @@description: FarCry UD specific options, plus the two-factor authentication link --->

<cfinclude template="/farcry/core/webskin/dmProfile/displaySummaryOptionsCLIENTUD.cfm" />

<cfif application.fapi.getContentType("wbTwoFactor").isGloballyEnabled()>
	<cfoutput>
		<li><a href="#application.url.webtop#/?id=dashboard&typename=wbTwoFactor&bodyView=webtopBodySetup">Two-factor authentication</a></li>
	</cfoutput>
</cfif>

<cfsetting enablecfoutputonly="false" />
