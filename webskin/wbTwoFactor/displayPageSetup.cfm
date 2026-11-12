<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Two-factor authentication setup (site) --->
<!--- @@description: Bootstrap 4 version of webtopBodySetup for logged in users without webtop access --->
<!--- @@viewBinding: type --->
<!--- @@viewStack: page --->
<!--- @@cacheStatus: -1 --->
<!---
Link: #application.fapi.getLink(type="wbTwoFactor", view="displayPageSetup")#
--->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfif NOT application.security.isLoggedIn()>
	<cfset returnURL = cgi.script_name & (len(cgi.query_string) ? "?" & cgi.query_string : "") />
	<skin:location url="#application.fapi.getLink(href=application.url.publiclogin, urlParameters='returnurl=#urlEncodedFormat(returnURL)#')#" />
</cfif>

<!--- ACTIONS (shared with webtopBodySetup) --->
<cfinclude template="/farcry/plugins/wbSecurity/includes/setupActions.cfm" />

<!-----------------------------
VIEW
------------------------------>
<cfset stHeaderParam = structNew() />
<cfset stHeaderParam.pageTitle = "Two-factor authentication" />
<skin:view typename="wbTwoFactor" stObject="#stobj#" webskin="displayHeader2021" stParam="#stHeaderParam#" />

<cfoutput>
<section class="container g-py-50">
	<div class="row justify-content-center">
		<div class="col-lg-8">
			<h1 class="mb-4">Two-factor authentication</h1>
</cfoutput>

<cfif currentUD NEQ "CLIENTUD">
	<cfoutput><div class="alert alert-info">Two-factor authentication is only available for accounts that log in with a username and password.</div></cfoutput>

<cfelseif NOT isGloballyEnabled()>
	<cfoutput><div class="alert alert-info">Two-factor authentication has been turned off for this site by an administrator.</div></cfoutput>

<cfelse>
	<cfif len(errorMessage)>
		<cfoutput><div class="alert alert-danger" role="alert">#encodeForHTML(errorMessage)#</div></cfoutput>
	</cfif>

	<!--- Emergency codes are only ever shown once, straight after they are created --->
	<cfif arrayLen(aNewCodes)>
		<cfoutput>
			<div class="card border-warning mb-4">
				<div class="card-header bg-warning"><strong>Your emergency codes</strong></div>
				<div class="card-body">
					<p>Save or print these codes now and keep them somewhere safe. <strong>They will not be shown again.</strong>
					Each code can be used once to log in if you don't have your phone.</p>
					<ul class="list-unstyled row text-monospace mb-3" style="font-size:1.15rem;">
						<cfloop array="#aNewCodes#" index="code"><li class="col-6 py-1">#code#</li></cfloop>
					</ul>
					<button type="button" class="btn btn-outline-secondary" onclick="window.print();">Print codes</button>
				</div>
			</div>
		</cfoutput>
	</cfif>

	<ft:form>
		<cfif bUserEnabled>
			<!--- ENABLED --->
			<cfoutput>
				<div class="card mb-4">
					<div class="card-body">
						<p><span class="badge badge-success">On</span>
						Two-factor authentication has been on since #dateFormat(stTF.dateEnabled, "d mmm yyyy")#.
						You have <strong>#getBackupCodesRemaining(stTF)#</strong> unused emergency codes.</p>

						<p class="mb-3">To make a change, enter the current code from your authenticator app.</p>
						<div class="form-group">
							<label for="wbSecCode">Verification code</label>
							<input type="text" class="form-control" style="max-width:12rem;" name="wbSecCode" id="wbSecCode" inputmode="numeric" autocomplete="one-time-code" maxlength="20" />
						</div>
			</cfoutput>
						<ft:button value="Get new emergency codes" class="btn btn-primary mr-2" />
						<ft:button value="Turn off two-factor authentication" class="btn btn-outline-danger" confirmText="Turn off two-factor authentication for your account?" />
			<cfoutput>
					</div>
				</div>
			</cfoutput>

		<cfelseif structKeyExists(session.wbSecurity, "setupSecret")>
			<!--- SETUP IN PROGRESS --->
			<cfset otpURL = getOtpAuthURL(secret=session.wbSecurity.setupSecret, accountName=stUser.userid) />
			<cfoutput>
				<div class="card mb-4">
					<div class="card-body">
						<ol class="pl-3">
							<li class="mb-2">Install an authenticator app on your phone, such as Google Authenticator, Microsoft Authenticator or Authy.</li>
							<li class="mb-2">In the app, add an account and scan this QR code.</li>
						</ol>

						<div class="d-flex justify-content-center my-3">
							<div id="wbSecQR" class="p-2 bg-white border"></div>
						</div>

						<p class="text-center">Can't scan it? Enter this key in the app instead:<br />
						<code style="font-size:1.15rem;">#encodeForHTML(formatSecret(session.wbSecurity.setupSecret))#</code></p>

						<ol class="pl-3" start="3">
							<li class="mb-2">Enter the 6-digit code the app shows to finish setting up.</li>
						</ol>
						<div class="form-group">
							<label for="wbSecCode">Verification code</label>
							<input type="text" class="form-control" style="max-width:12rem;" name="wbSecCode" id="wbSecCode" inputmode="numeric" autocomplete="one-time-code" maxlength="6" />
						</div>
			</cfoutput>
						<ft:button value="Verify and turn on" class="btn btn-primary mr-2" />
						<ft:button value="Cancel setup" class="btn btn-link" validate="false" />
			<cfoutput>
					</div>
				</div>

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

		<cfelse>
			<!--- NOT ENABLED --->
			<cfoutput>
				<div class="card mb-4">
					<div class="card-body">
						<p><span class="badge badge-secondary">Off</span>
						Two-factor authentication adds a second step to logging in. After your password, you enter a code from an authenticator app on your phone.</p>
			</cfoutput>
						<ft:button value="Set up two-factor authentication" class="btn btn-primary" />
			<cfoutput>
					</div>
				</div>
			</cfoutput>
		</cfif>
	</ft:form>
</cfif>

<cfoutput>
		</div>
	</div>
</section>
</cfoutput>

<skin:view typename="wbTwoFactor" stObject="#stobj#" webskin="displayFooter2021" footerIndent="0" />

<cfsetting enablecfoutputonly="false" />
