<cfcomponent extends="farcry.core.packages.types.types" displayname="Two-Factor Authentication" hint="Per-user two-factor (TOTP) settings and emergency codes" output="false"
	bObjectBroker="false" bRefObjects="true" icon="fa-shield">

	<cfproperty name="userObjectID" type="string" default="" ftLabel="User objectid" hint="objectid of the farUser this belongs to" />
	<cfproperty name="userid" type="string" default="" ftLabel="Username" hint="farUser.userid, for admin listings" />
	<cfproperty name="secret" type="string" default="" ftLabel="Secret" hint="Base32 TOTP shared secret" />
	<cfproperty name="bEnabled" type="boolean" default="0" ftLabel="Enabled" />
	<cfproperty name="backupCodes" type="longchar" default="[]" ftLabel="Emergency codes" hint="JSON array of salted SHA-256 hashes of unused emergency codes" />
	<cfproperty name="lastStep" type="integer" default="0" ftLabel="Last TOTP step" hint="Last accepted 30 second step, so a code cannot be reused" />
	<cfproperty name="dateEnabled" type="datetime" default="" ftLabel="Date enabled" />

	<cfset variables.base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" />
	<!--- emergency codes avoid look-alike characters (0/o, 1/l/i) --->
	<cfset variables.backupAlphabet = "abcdefghjkmnpqrstuvwxyz23456789" />
	<cfset variables.period = 30 />
	<cfset variables.digits = 6 />
	<cfset variables.backupCodeCount = 10 />


	<!--- ====================
	  SETTINGS
	===================== --->
	<cffunction name="isGloballyEnabled" access="public" output="false" returntype="boolean" hint="True if 2FA is turned on site-wide and the type has been deployed">
		<cfif NOT application.fapi.getConfig("wbSecurity", "bEnabled", true)>
			<cfreturn false />
		</cfif>
		<cfreturn isTypeDeployed() />
	</cffunction>

	<cffunction name="isTypeDeployed" access="public" output="false" returntype="boolean" hint="True once the wbTwoFactor table has been deployed through COAPI">
		<!--- only cache a positive result, so deploying the type takes effect without a reload --->
		<cfif NOT structKeyExists(application, "wbSecurityDeployed")>
			<cfif application.fc.lib.db.isDeployed(typename=application.stCOAPI.wbTwoFactor.packagePath)>
				<cfset application.wbSecurityDeployed = true />
			<cfelse>
				<cfreturn false />
			</cfif>
		</cfif>
		<cfreturn true />
	</cffunction>

	<cffunction name="getIssuer" access="public" output="false" returntype="string">
		<cfset var issuer = trim(application.fapi.getConfig("wbSecurity", "issuer", "")) />
		<cfif NOT len(issuer)>
			<cfset issuer = application.displayName />
		</cfif>
		<cfreturn issuer />
	</cffunction>


	<!--- ====================
	  USER RECORDS
	===================== --->
	<cffunction name="getByUser" access="public" output="false" returntype="struct" hint="Returns the 2FA record for a farUser objectid, or an empty struct">
		<cfargument name="userObjectID" type="string" required="true" />

		<cfset var q = "" />

		<cfquery name="q" datasource="#application.dsn#">
			SELECT objectid
			FROM #application.dbowner#wbTwoFactor
			WHERE userObjectID = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.userObjectID#" />
		</cfquery>

		<cfif q.recordcount>
			<cfreturn getData(objectid=q.objectid[1]) />
		</cfif>
		<cfreturn structNew() />
	</cffunction>

	<cffunction name="isEnabledForUser" access="public" output="false" returntype="boolean" hint="True if the user has completed setup and 2FA applies to them right now">
		<cfargument name="userObjectID" type="string" required="true" />

		<cfset var stTF = "" />

		<cfif NOT isGloballyEnabled()>
			<cfreturn false />
		</cfif>
		<cfset stTF = getByUser(arguments.userObjectID) />
		<cfreturn NOT structIsEmpty(stTF) AND stTF.bEnabled AND len(stTF.secret) />
	</cffunction>

	<cffunction name="enableForUser" access="public" output="false" returntype="array" hint="Saves a verified secret for the user, and returns a fresh set of plain-text emergency codes to show once">
		<cfargument name="userObjectID" type="string" required="true" />
		<cfargument name="userid" type="string" required="true" />
		<cfargument name="secret" type="string" required="true" />
		<cfargument name="step" type="numeric" required="true" hint="The step the setup code was verified at" />

		<cfset var stTF = getByUser(arguments.userObjectID) />
		<cfset var aCodes = generateBackupCodes() />
		<cfset var bNew = structIsEmpty(stTF) />

		<cfif bNew>
			<cfset stTF = structNew() />
			<cfset stTF.objectid = application.fc.utils.createJavaUUID() />
		</cfif>
		<cfset stTF.userObjectID = arguments.userObjectID />
		<cfset stTF.userid = arguments.userid />
		<cfset stTF.label = arguments.userid />
		<cfset stTF.secret = arguments.secret />
		<cfset stTF.bEnabled = 1 />
		<cfset stTF.lastStep = arguments.step />
		<cfset stTF.dateEnabled = now() />
		<cfset stTF.backupCodes = serializeJSON(hashBackupCodes(aCodes)) />

		<cfif bNew>
			<cfset createData(stProperties=stTF) />
		<cfelse>
			<cfset setData(stProperties=stTF) />
		</cfif>

		<cfreturn aCodes />
	</cffunction>

	<cffunction name="disableForUser" access="public" output="false" returntype="void" hint="Removes the user's 2FA setup (user turning it off, or admin reset)">
		<cfargument name="userObjectID" type="string" required="true" />

		<cfset var stTF = getByUser(arguments.userObjectID) />

		<cfif NOT structIsEmpty(stTF)>
			<cfset deleteData(objectid=stTF.objectid) />
		</cfif>
	</cffunction>

	<cffunction name="regenerateBackupCodes" access="public" output="false" returntype="array" hint="Replaces the user's emergency codes and returns the new plain-text codes">
		<cfargument name="userObjectID" type="string" required="true" />

		<cfset var stTF = getByUser(arguments.userObjectID) />
		<cfset var aCodes = generateBackupCodes() />

		<cfset stTF.backupCodes = serializeJSON(hashBackupCodes(aCodes)) />
		<cfset setData(stProperties=stTF) />

		<cfreturn aCodes />
	</cffunction>

	<cffunction name="getBackupCodesRemaining" access="public" output="false" returntype="numeric">
		<cfargument name="stTF" type="struct" required="true" />

		<cfif isJSON(arguments.stTF.backupCodes)>
			<cfreturn arrayLen(deserializeJSON(arguments.stTF.backupCodes)) />
		</cfif>
		<cfreturn 0 />
	</cffunction>


	<!--- ====================
	  VERIFICATION
	===================== --->
	<cffunction name="verifyUserCode" access="public" output="false" returntype="struct" hint="Checks an authenticator or emergency code for an enrolled user. Accepted codes are used up.">
		<cfargument name="userObjectID" type="string" required="true" />
		<cfargument name="code" type="string" required="true" />
		<cfargument name="bAllowBackup" type="boolean" required="false" default="true" />

		<cfset var stResult = { bValid=false, bBackupCode=false, backupCodesRemaining=0 } />
		<cfset var stTF = getByUser(arguments.userObjectID) />
		<cfset var step = 0 />
		<cfset var aHashes = arrayNew(1) />
		<cfset var i = 0 />

		<cfif structIsEmpty(stTF) OR NOT len(stTF.secret)>
			<cfreturn stResult />
		</cfif>

		<cfset step = verifyTOTP(secret=stTF.secret, code=arguments.code, lastStep=val(stTF.lastStep)) />
		<cfif step GT 0>
			<cfset stTF.lastStep = step />
			<cfset setData(stProperties=stTF) />
			<cfset stResult.bValid = true />
		<cfelseif arguments.bAllowBackup AND isJSON(stTF.backupCodes)>
			<cfset aHashes = deserializeJSON(stTF.backupCodes) />
			<cfloop from="1" to="#arrayLen(aHashes)#" index="i">
				<cfif backupCodeMatches(arguments.code, aHashes[i])>
					<cfset arrayDeleteAt(aHashes, i) />
					<cfset stTF.backupCodes = serializeJSON(aHashes) />
					<cfset setData(stProperties=stTF) />
					<cfset stResult.bValid = true />
					<cfset stResult.bBackupCode = true />
					<cfbreak />
				</cfif>
			</cfloop>
		</cfif>

		<cfif isJSON(stTF.backupCodes)>
			<cfset stResult.backupCodesRemaining = arrayLen(deserializeJSON(stTF.backupCodes)) />
		</cfif>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="verifyTOTP" access="public" output="false" returntype="numeric" hint="Returns the matching time step (allowing one step of clock drift either way), or 0 if the code is invalid or already used">
		<cfargument name="secret" type="string" required="true" />
		<cfargument name="code" type="string" required="true" />
		<cfargument name="lastStep" type="numeric" required="false" default="0" />

		<cfset var cleanCode = reReplace(arguments.code, "[^0-9]", "", "all") />
		<cfset var currentStep = getCurrentStep() />
		<cfset var step = 0 />
		<cfset var offset = 0 />

		<cfif len(cleanCode) NEQ variables.digits>
			<cfreturn 0 />
		</cfif>

		<cfloop from="-1" to="1" index="offset">
			<cfset step = currentStep + offset />
			<cfif step GT arguments.lastStep AND generateTOTP(arguments.secret, step) EQ cleanCode>
				<cfreturn step />
			</cfif>
		</cfloop>

		<cfreturn 0 />
	</cffunction>

	<cffunction name="getCurrentStep" access="public" output="false" returntype="numeric">
		<cfset var millis = createObject("java", "java.lang.System").currentTimeMillis() />
		<cfreturn int(millis / 1000 / variables.period) />
	</cffunction>

	<cffunction name="generateTOTP" access="public" output="false" returntype="string" hint="RFC 6238 TOTP (HMAC-SHA1, 6 digits) for a base32 secret at a given time step">
		<cfargument name="secret" type="string" required="true" />
		<cfargument name="step" type="numeric" required="true" />

		<cfset var key = base32Decode(arguments.secret) />
		<cfset var message = createObject("java", "java.nio.ByteBuffer").allocate(javaCast("int", 8)).putLong(javaCast("long", arguments.step)).array() />
		<cfset var mac = createObject("java", "javax.crypto.Mac").getInstance("HmacSHA1") />
		<cfset var hmacHex = "" />
		<cfset var offset = 0 />
		<cfset var binaryCode = 0 />

		<cfset mac.init(createObject("java", "javax.crypto.spec.SecretKeySpec").init(key, "HmacSHA1")) />
		<cfset hmacHex = binaryEncode(mac.doFinal(message), "hex") />

		<!--- dynamic truncation: low 4 bits of the last byte give the offset of 4 bytes, top bit masked off --->
		<cfset offset = bitAnd(inputBaseN(right(hmacHex, 1), 16), 15) />
		<cfset binaryCode = bitAnd(inputBaseN(mid(hmacHex, offset * 2 + 1, 2), 16), 127) * 16777216
			+ inputBaseN(mid(hmacHex, offset * 2 + 3, 6), 16) />

		<cfreturn numberFormat(binaryCode MOD 1000000, "000000") />
	</cffunction>


	<!--- ====================
	  SECRETS AND CODES
	===================== --->
	<cffunction name="generateSecret" access="public" output="false" returntype="string" hint="A new random 160 bit secret, base32 encoded">
		<cfreturn randomString(variables.base32Alphabet, 32) />
	</cffunction>

	<cffunction name="getOtpAuthURL" access="public" output="false" returntype="string" hint="The otpauth:// URI that authenticator apps read from the QR code">
		<cfargument name="secret" type="string" required="true" />
		<cfargument name="accountName" type="string" required="true" />

		<cfset var issuer = getIssuer() />

		<cfreturn "otpauth://totp/" & urlEncode(issuer & ":" & arguments.accountName)
			& "?secret=" & arguments.secret
			& "&issuer=" & urlEncode(issuer)
			& "&algorithm=SHA1&digits=#variables.digits#&period=#variables.period#" />
	</cffunction>

	<cffunction name="formatSecret" access="public" output="false" returntype="string" hint="Secret split into groups of 4 for manual entry">
		<cfargument name="secret" type="string" required="true" />

		<cfreturn trim(reReplace(arguments.secret, "(.{4})", "\1 ", "all")) />
	</cffunction>

	<cffunction name="generateBackupCodes" access="private" output="false" returntype="array">
		<cfset var aCodes = arrayNew(1) />
		<cfset var i = 0 />
		<cfset var code = "" />

		<cfloop from="1" to="#variables.backupCodeCount#" index="i">
			<cfset code = randomString(variables.backupAlphabet, 10) />
			<cfset arrayAppend(aCodes, left(code, 5) & "-" & right(code, 5)) />
		</cfloop>

		<cfreturn aCodes />
	</cffunction>

	<cffunction name="hashBackupCodes" access="private" output="false" returntype="array">
		<cfargument name="aCodes" type="array" required="true" />

		<cfset var aHashes = arrayNew(1) />
		<cfset var i = 0 />
		<cfset var salt = "" />

		<cfloop from="1" to="#arrayLen(arguments.aCodes)#" index="i">
			<cfset salt = randomString(variables.base32Alphabet, 16) />
			<cfset arrayAppend(aHashes, salt & ":" & hash(salt & normaliseBackupCode(arguments.aCodes[i]), "SHA-256")) />
		</cfloop>

		<cfreturn aHashes />
	</cffunction>

	<cffunction name="backupCodeMatches" access="private" output="false" returntype="boolean">
		<cfargument name="code" type="string" required="true" />
		<cfargument name="storedHash" type="string" required="true" />

		<cfset var salt = listFirst(arguments.storedHash, ":") />

		<cfreturn compare(hash(salt & normaliseBackupCode(arguments.code), "SHA-256"), listLast(arguments.storedHash, ":")) EQ 0 />
	</cffunction>

	<cffunction name="normaliseBackupCode" access="private" output="false" returntype="string">
		<cfargument name="code" type="string" required="true" />

		<cfreturn lCase(reReplace(arguments.code, "[^A-Za-z0-9]", "", "all")) />
	</cffunction>

	<cffunction name="randomString" access="private" output="false" returntype="string" hint="Cryptographically random string from the given alphabet">
		<cfargument name="alphabet" type="string" required="true" />
		<cfargument name="length" type="numeric" required="true" />

		<cfset var random = createObject("java", "java.security.SecureRandom").init() />
		<cfset var result = "" />
		<cfset var i = 0 />

		<cfloop from="1" to="#arguments.length#" index="i">
			<cfset result = result & mid(arguments.alphabet, random.nextInt(javaCast("int", len(arguments.alphabet))) + 1, 1) />
		</cfloop>

		<cfreturn result />
	</cffunction>

	<cffunction name="base32Decode" access="private" output="false" returntype="any" hint="Decodes RFC 4648 base32 to a Java byte array">
		<cfargument name="input" type="string" required="true" />

		<cfset var clean = uCase(reReplace(arguments.input, "[\s=-]", "", "all")) />
		<cfset var out = createObject("java", "java.io.ByteArrayOutputStream").init() />
		<cfset var buffer = 0 />
		<cfset var bitsLeft = 0 />
		<cfset var value = 0 />
		<cfset var i = 0 />

		<cfloop from="1" to="#len(clean)#" index="i">
			<cfset value = find(mid(clean, i, 1), variables.base32Alphabet) - 1 />
			<cfif value LT 0>
				<cfthrow type="wbSecurity" message="Invalid base32 secret" />
			</cfif>
			<cfset buffer = bitOr(bitSHLN(buffer, 5), value) />
			<cfset bitsLeft = bitsLeft + 5 />
			<cfif bitsLeft GTE 8>
				<cfset out.write(javaCast("int", bitAnd(bitSHRN(buffer, bitsLeft - 8), 255))) />
				<cfset bitsLeft = bitsLeft - 8 />
				<cfset buffer = bitAnd(buffer, bitSHLN(1, bitsLeft) - 1) />
			</cfif>
		</cfloop>

		<cfreturn out.toByteArray() />
	</cffunction>

	<cffunction name="urlEncode" access="private" output="false" returntype="string" hint="Percent-encodes with %20 for spaces, as authenticator apps expect">
		<cfargument name="value" type="string" required="true" />

		<cfreturn replace(createObject("java", "java.net.URLEncoder").encode(arguments.value, "UTF-8"), "+", "%20", "all") />
	</cffunction>

</cfcomponent>
