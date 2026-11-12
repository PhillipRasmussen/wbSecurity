<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Two-factor authentication setup --->
<!--- @@description: Lets the logged in user turn two-factor authentication on or off and manage emergency codes --->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfif NOT application.security.isLoggedIn()>
	<cfthrow message="Not logged in" />
</cfif>

<!--- ACTIONS (shared with displayPageSetup) --->
<cfinclude template="/farcry/plugins/wbSecurity/includes/setupActions.cfm" />

<!-----------------------------
VIEW
------------------------------>
<admin:header>

<cfoutput><h1>Two-factor authentication</h1></cfoutput>

<cfif currentUD NEQ "CLIENTUD">
	<cfoutput><p>Two-factor authentication is only available for accounts that log in with a FarCry username and password.</p></cfoutput>

<cfelseif NOT isGloballyEnabled()>
	<cfoutput><p>Two-factor authentication has been turned off for this site by an administrator.</p></cfoutput>

<cfelse>
	<cfif len(errorMessage)>
		<cfoutput><div class="alert alert-error">#encodeForHTML(errorMessage)#</div></cfoutput>
	</cfif>

	<!--- Emergency codes are only ever shown once, straight after they are created --->
	<cfif arrayLen(aNewCodes)>
		<cfoutput>
			<div class="alert alert-warning">
				<h3>Your emergency codes</h3>
				<p>Save or print these codes now and keep them somewhere safe. <strong>They will not be shown again.</strong>
				Each code can be used once to log in if you don't have your phone.</p>
				<pre style="font-size:1.2em;line-height:1.8em;"><cfloop array="#aNewCodes#" index="code">#code#
</cfloop></pre>
				<button type="button" class="btn" onclick="window.print();">Print codes</button>
			</div>
		</cfoutput>
	</cfif>

	<ft:form>
		<cfif bUserEnabled>
			<!--- ENABLED --->
			<cfoutput>
				<p><span class="label label-success">On</span>
				Two-factor authentication has been on since #dateFormat(stTF.dateEnabled, "d mmm yyyy")#.
				You have <strong>#getBackupCodesRemaining(stTF)#</strong> unused emergency codes.</p>

				<p>To make a change, enter the current code from your authenticator app.</p>
				<fieldset>
					<label for="wbSecCode">Verification code</label>
					<input type="text" name="wbSecCode" id="wbSecCode" inputmode="numeric" autocomplete="one-time-code" maxlength="20" />
				</fieldset>
			</cfoutput>
			<ft:buttonPanel>
				<ft:button value="Get new emergency codes" />
				<ft:button value="Turn off two-factor authentication" confirmText="Turn off two-factor authentication for your account?" />
			</ft:buttonPanel>

		<cfelseif structKeyExists(session.wbSecurity, "setupSecret")>
			<!--- SETUP IN PROGRESS --->
			<cfset otpURL = getOtpAuthURL(secret=session.wbSecurity.setupSecret, accountName=stUser.userid) />
			<cfoutput>
				<ol>
					<li>Install an authenticator app on your phone, such as Google Authenticator, Microsoft Authenticator or Authy.</li>
					<li>In the app, add an account and scan this QR code.</li>
				</ol>

				<div id="wbSecQR" style="margin:15px 0;"></div>

				<p>Can't scan it? Enter this key in the app instead:<br />
				<code style="font-size:1.2em;">#encodeForHTML(formatSecret(session.wbSecurity.setupSecret))#</code></p>

				<ol start="3">
					<li>Enter the 6-digit code the app shows to finish setting up.</li>
				</ol>
				<fieldset>
					<label for="wbSecCode">Verification code</label>
					<input type="text" name="wbSecCode" id="wbSecCode" inputmode="numeric" autocomplete="one-time-code" maxlength="6" />
				</fieldset>

				<script src="/farcry/plugins/wbSecurity/www/js/qrcode.min.js"></script>
				<script>
					new QRCode(document.getElementById("wbSecQR"), {
						text: "#encodeForJavaScript(otpURL)#",
						width: 200,
						height: 200,
						correctLevel: QRCode.CorrectLevel.M
					});
				</script>
			</cfoutput>
			<ft:buttonPanel>
				<ft:button value="Verify and turn on" />
				<ft:button value="Cancel setup" validate="false" />
			</ft:buttonPanel>

		<cfelse>
			<!--- NOT ENABLED --->
			<cfoutput>
				<p><span class="label">Off</span>
				Two-factor authentication adds a second step to logging in. After your password, you enter a code from an authenticator app on your phone.</p>
			</cfoutput>
			<ft:buttonPanel>
				<ft:button value="Set up two-factor authentication" />
			</ft:buttonPanel>
		</cfif>
	</ft:form>
</cfif>

<admin:footer>

<cfsetting enablecfoutputonly="false" />
