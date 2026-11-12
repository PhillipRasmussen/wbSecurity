<cfsetting enablecfoutputonly="Yes">
<!--- @@displayname: Two-factor code entry --->
<!--- @@description: Second login step for users with two-factor authentication turned on --->

<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin" />

<cfparam name="arguments.stParam.message" default="" />

<!--- post back to the same login URL so returnurl etc. are kept --->
<cfset actionURL = cgi.script_name />
<cfif len(cgi.query_string)>
	<cfset actionURL = actionURL & "?" & cgi.query_string />
</cfif>

<skin:view typename="farLogin" template="displayHeaderLogin" />

<cfoutput>
	<form method="post" action="#encodeForHTMLAttribute(actionURL)#" class="clearfix" autocomplete="off">
		<cfif len(arguments.stParam.message)>
			<div class="alert alert-warning">#encodeForHTML(arguments.stParam.message)#</div>
		</cfif>

		<p>Enter the 6-digit code from your authenticator app. If you don't have your phone, enter one of your emergency codes.</p>

		<fieldset>
			<label for="wbSecCode">Verification code</label>
			<input type="text" name="wbSecCode" id="wbSecCode" inputmode="numeric" autocomplete="one-time-code" maxlength="20" autofocus="autofocus" />
		</fieldset>

		<!--- Verify comes first so pressing Enter submits it --->
		<div class="btn-group pull-right">
			<button type="submit" class="btn btn-primary btn-large">Verify</button>
		</div>
		<p class="help-inline">
			<button type="submit" name="wbSecCancel" value="1" class="btn btn-link">Cancel and log in as someone else</button>
		</p>
	</form>
</cfoutput>

<skin:view typename="farLogin" template="displayFooterLogin" />

<cfsetting enablecfoutputonly="No">
