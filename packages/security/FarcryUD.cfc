<cfcomponent displayname="FarCry User Directory" hint="FarCry user directory with two-factor authentication" extends="farcry.core.packages.security.FarcryUD" output="false"
			key="CLIENTUD" bEncrypted="true" standardHash="none">

	<!---
	Login runs in two steps for users with two-factor authentication turned on:
	1. Username and password are checked by the core UD. If they pass, the user is held in
	   session.wbSecurity.pending instead of being logged in, and farLogin/displayLogin shows the code form.
	2. The code form posts wbSecCode. A valid authenticator or emergency code completes the login.
	--->

	<cfset variables.pendingMinutes = 5 />
	<cfset variables.maxCodeAttempts = 5 />

	<cffunction name="authenticate" access="public" output="false" returntype="struct" hint="Attempts to process a user. Runs every time the login form is loaded.">
		<cfset var stResult = structNew() />
		<cfset var stUser = "" />
		<cfset var oTwoFactor = "" />

		<!--- STEP 2: code submitted --->
		<cfif structKeyExists(form, "wbSecCode") OR structKeyExists(form, "wbSecCancel")>
			<cfreturn authenticateCode() />
		</cfif>

		<!--- STEP 1: username / password --->
		<cfset stResult = super.authenticate(argumentCollection=arguments) />

		<cfif structKeyExists(stResult, "authenticated") AND stResult.authenticated>
			<cfset oTwoFactor = application.fapi.getContentType("wbTwoFactor") />
			<cfset stUser = application.fapi.getContentType("farUser").getByUserID(stResult.userid) />

			<cfif NOT structIsEmpty(stUser) AND oTwoFactor.isEnabledForUser(stUser.objectid)>
				<cfset session.wbSecurity.pending = {
					userid = stResult.userid,
					userObjectID = stUser.objectid,
					expires = dateAdd("n", variables.pendingMinutes, now()),
					attempts = 0
				} />

				<!--- No "authenticated" key: core security treats this as no login attempt yet (nothing logged as failed) --->
				<cfreturn structNew() />
			</cfif>
		</cfif>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="authenticateCode" access="private" output="false" returntype="struct" hint="Checks the code posted from the two-factor login step">
		<cfset var stResult = structNew() />
		<cfset var stPending = "" />
		<cfset var stVerify = "" />

		<cfif NOT isPending()>
			<cfif structKeyExists(form, "wbSecCode")>
				<cfset session.fc.loginMessage = "Your verification timed out. Please log in again." />
			</cfif>
			<cfset clearPending() />
			<cfreturn stResult />
		</cfif>

		<cfset stPending = session.wbSecurity.pending />

		<cfif structKeyExists(form, "wbSecCancel")>
			<cfset clearPending() />
			<cfreturn stResult />
		</cfif>

		<cfset stResult.userid = stPending.userid />
		<cfset stResult.UD = "CLIENTUD" />
		<cfset stResult.authenticated = false />
		<cfset stResult.message = "" />

		<cfset stVerify = application.fapi.getContentType("wbTwoFactor").verifyUserCode(userObjectID=stPending.userObjectID, code=trim(form.wbSecCode)) />

		<cfif stVerify.bValid>
			<cfset clearPending() />
			<cfset stResult.authenticated = true />
			<cfif stVerify.bBackupCode>
				<cfset session.wbSecurity.backupCodeUsed = stVerify.backupCodesRemaining />
			</cfif>
		<cfelse>
			<cfset application.fapi.getContentType("farUser").addLoginFailure(objectid=stPending.userObjectID, reason="Invalid two-factor code") />
			<cfset stPending.attempts = stPending.attempts + 1 />
			<cfif stPending.attempts GTE variables.maxCodeAttempts>
				<cfset clearPending() />
				<cfset stResult.message = "Too many incorrect codes. Please log in again." />
			<cfelse>
				<cfset stResult.message = "That code was not correct. Please try again." />
			</cfif>
		</cfif>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="isPending" access="public" output="false" returntype="boolean" hint="True while a user has passed the password step and still needs to enter a code">
		<cfreturn structKeyExists(session, "wbSecurity")
			AND structKeyExists(session.wbSecurity, "pending")
			AND dateCompare(session.wbSecurity.pending.expires, now()) GT 0 />
	</cffunction>

	<cffunction name="clearPending" access="public" output="false" returntype="void">
		<cfif structKeyExists(session, "wbSecurity")>
			<cfset structDelete(session.wbSecurity, "pending") />
		</cfif>
	</cffunction>

</cfcomponent>
