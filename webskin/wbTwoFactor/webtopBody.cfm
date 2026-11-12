<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Two-factor authentication admin --->
<!--- @@description: Lists users with two-factor authentication and lets admins reset it --->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/farcry" prefix="farcry" />

<cfif NOT application.security.checkPermission(permission="SecurityPolicyManagementTab")>
	<cfoutput><p>You do not have permission to manage two-factor authentication.</p></cfoutput>
	<cfsetting enablecfoutputonly="false" />
	<cfexit method="exittemplate" />
</cfif>

<!-----------------------------
ACTIONS
------------------------------>
<ft:processform action="Reset">
	<cfif structKeyExists(form, "selectedObjectID") AND len(form.selectedObjectID)>
		<cfset stReset = getData(objectid=form.selectedObjectID) />
		<cfif structKeyExists(stReset, "userObjectID")>
			<cfset disableForUser(userObjectID=stReset.userObjectID) />
			<farcry:logevent type="security" event="twofactorreset" userid="#stReset.userid#_CLIENTUD" notes="Two-factor authentication reset by #session.security.userid#" />
			<skin:bubble title="Two-factor authentication reset" message="#stReset.userid# can now log in with just their password." tags="security,info" />
		</cfif>
	</cfif>
</ft:processform>

<cfquery name="qUsers" datasource="#application.dsn#">
	SELECT objectid, userid, bEnabled, dateEnabled, backupCodes
	FROM #application.dbowner#wbTwoFactor
	ORDER BY userid
</cfquery>

<!-----------------------------
VIEW
------------------------------>
<cfoutput>
	<h1>Two-factor authentication</h1>
	<p>
		Two-factor authentication is <strong>#isGloballyEnabled() ? "on" : "off"#</strong> for this site.
		Turn it on or off under Admin &rsaquo; Configuration &rsaquo; Two-Factor Authentication.
	</p>
	<p>Users set it up themselves from their profile menu. Reset it here for a user who has lost their phone and emergency codes.</p>
</cfoutput>

<ft:form>
	<cfoutput>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Username</th>
					<th>Enabled since</th>
					<th>Emergency codes left</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
	</cfoutput>
	<cfloop query="qUsers">
		<cfoutput>
				<tr>
					<td>#encodeForHTML(qUsers.userid)#</td>
					<td>#dateFormat(qUsers.dateEnabled, "d mmm yyyy")#</td>
					<td>#isJSON(qUsers.backupCodes) ? arrayLen(deserializeJSON(qUsers.backupCodes)) : 0#</td>
					<td>
		</cfoutput>
						<ft:button value="Reset" selectedObjectID="#qUsers.objectid#" confirmText="Reset two-factor authentication for #qUsers.userid#? They will be able to log in with just their password." />
		<cfoutput>
					</td>
				</tr>
		</cfoutput>
	</cfloop>
	<cfif NOT qUsers.recordcount>
		<cfoutput><tr><td colspan="4">No users have set up two-factor authentication.</td></tr></cfoutput>
	</cfif>
	<cfoutput>
			</tbody>
		</table>
	</cfoutput>
</ft:form>

<cfsetting enablecfoutputonly="false" />
