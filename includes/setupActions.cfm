<cfsetting enablecfoutputonly="true" />
<!---
Shared form actions and state for the two-factor setup views (wbTwoFactor/webtopBodySetup and wbTwoFactor/displayPageSetup).
Included from a wbTwoFactor webskin, so the type's methods are available directly.

Sets: currentUD, stUser, stTF, bUserEnabled, aNewCodes, errorMessage
--->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset currentUD = listLast(session.security.userid, "_") />
<cfset currentUserID = application.factory.oUtils.listSlice(session.security.userid, 1, -2, "_") />
<cfset aNewCodes = arrayNew(1) />
<cfset errorMessage = "" />
<cfset stUser = structNew() />
<cfset stTF = structNew() />
<cfset bUserEnabled = false />

<cfparam name="session.wbSecurity" default="#structNew()#" />

<cfif currentUD EQ "CLIENTUD" AND isGloballyEnabled()>
	<cfset stUser = application.fapi.getContentType("farUser").getByUserID(currentUserID) />

	<ft:processform action="Set up two-factor authentication">
		<cfset session.wbSecurity.setupSecret = generateSecret() />
	</ft:processform>

	<ft:processform action="Cancel setup">
		<cfset structDelete(session.wbSecurity, "setupSecret") />
	</ft:processform>

	<ft:processform action="Verify and turn on">
		<cfif structKeyExists(session.wbSecurity, "setupSecret")>
			<cfset verifiedStep = verifyTOTP(secret=session.wbSecurity.setupSecret, code=form.wbSecCode) />
			<cfif verifiedStep>
				<cfset aNewCodes = enableForUser(userObjectID=stUser.objectid, userid=stUser.userid, secret=session.wbSecurity.setupSecret, step=verifiedStep) />
				<cfset structDelete(session.wbSecurity, "setupSecret") />
				<skin:bubble title="Two-factor authentication is on" tags="security,info" />
			<cfelse>
				<cfset errorMessage = "That code was not correct. Check the time on your phone is set automatically, then try the current code." />
			</cfif>
		</cfif>
	</ft:processform>

	<ft:processform action="Get new emergency codes">
		<cfset stVerify = verifyUserCode(userObjectID=stUser.objectid, code=form.wbSecCode, bAllowBackup=false) />
		<cfif stVerify.bValid>
			<cfset aNewCodes = regenerateBackupCodes(userObjectID=stUser.objectid) />
			<skin:bubble title="New emergency codes created" message="Your old emergency codes no longer work." tags="security,info" />
		<cfelse>
			<cfset errorMessage = "That code was not correct." />
		</cfif>
	</ft:processform>

	<ft:processform action="Turn off two-factor authentication">
		<cfset stVerify = verifyUserCode(userObjectID=stUser.objectid, code=form.wbSecCode) />
		<cfif stVerify.bValid>
			<cfset disableForUser(userObjectID=stUser.objectid) />
			<skin:bubble title="Two-factor authentication is off" tags="security,info" />
		<cfelse>
			<cfset errorMessage = "That code was not correct." />
		</cfif>
	</ft:processform>

	<cfset stTF = getByUser(stUser.objectid) />
	<cfset bUserEnabled = NOT structIsEmpty(stTF) AND stTF.bEnabled />
</cfif>

<cfsetting enablecfoutputonly="false" />
