component output="false" {

	this.azureKey = "";
	this.azureApiVersion = "";

	public function init(required string key, string apiVersion = "2017-02-22") {

		this.azureKey = Arguments.key;
		this.azureApiVersion = Arguments.apiVersion;

		return this;
	}


	public function getAuthorizationTokenString(required string httpVerb, required string resourceType, required string resourceLink, required string requestDate) {
		/*	
			All calls to Cosmos DB require an authorisation token that is unique to the resource being called. For more information read: https://docs.microsoft.com/en-us/rest/api/cosmos-db/access-control-on-cosmosdb-resources
		*/

	    local.tokenText = lCase(Arguments.httpVerb) & chr(10) &   
	               		lCase(Arguments.resourceType) & chr(10) &   
	               		Arguments.resourceLink & chr(10) &   
	              		lCase(Arguments.requestDate) & chr(10) &   
	               		"" & chr(10);

		local.secretKey = createObject('java', 'javax.crypto.spec.SecretKeySpec' ).Init(BinaryDecode(this.azureKey, "Base64"), 'HmacSHA256');

		local.objMAC = createObject('java', "javax.crypto.Mac").getInstance("HmacSHA256");
		local.objMAC.init(local.secretKey);

		local.macHash = local.objMAC.doFinal(tokenText.GetBytes());
		local.token = BinaryEncode(local.macHash, "Base64");
		local.token = URLEncodedFormat("type=master&ver=1.0&sig=#local.token#");
		
		return local.token;
	}


	public function callCosmosDb(
		required string httpVerb,
		required string databaseAccount,
		required string resourceType,
		required string resourceLink,
		array headers = [],
		string requestBody = "",
		boolean isQuery = 0,	// Queries go across partitions, so this flags removed the partition header if one has been added.
		partitionKey = "") {
		// This is a function that handles http calls to Cosmos DB, adding the headers which are needed. 

		local.requestTime = getHTTPTimeString( Now() );
		local.authorizationString = getAuthorizationTokenString( Arguments.httpVerb, Arguments.resourceType, Arguments.resourceLink, local.requestTime );

		local.suppressPartitionRequest = 0;
		if ( Arguments.isQuery == 1 && findNoCase("order by", Arguments.requestBody) ) { local.suppressPartitionRequest = 1; }

		local.apiURL = "https://#Arguments.databaseAccount#.documents.azure.com/#Arguments.resourceLink#";

		// If POST to create a doc then the resourceLink for the auth token and URL seem to need to be different
		if ( listFind("POST", Arguments.httpVerb) ) {
			local.apiURL = local.apiURL & "/" & Arguments.resourceType;
		}

		cfhttp( url="#local.apiURL#", method=Arguments.httpVerb, result="local.requestResponse" ) {

			cfhttpparam( type = "header", name = "Authorization", value = local.authorizationString );
			cfhttpparam( type = "header", name = "x-ms-date", value = local.requestTime );
			cfhttpparam( type = "header", name = "x-ms-version", value = this.azureApiVersion );

			// If this is an order by or top query we need to get the partition ranges
			if ( listFind("POST,PUT", Arguments.httpVerb) && Arguments.isQuery == 1 ) {
			}
			if ( listFind("POST,PUT", Arguments.httpVerb) ) {
				if ( isQuery == 1 ) {
					cfhttpparam( type = "header", name = "Content-Type", value = "application/query+json" );
					cfhttpparam( type = "header", name = "x-ms-documentdb-isquery", value = true );
					if (local.suppressPartitionRequest == 0 ) {
						cfhttpparam( type = "header", name = "x-ms-documentdb-query-enablecrosspartition", value = true );
					} else {

						cfhttpparam( type = "header", name = "x-ms-documentdb-query-enablecrosspartition", value = false );
					}
					if ( findNoCase(" TOP ", Arguments.requestBody) OR findNoCase(" ORDER BY ", Arguments.requestBody) ) {
						// For now hardcoding this. TODO: get partition ID dynamically and check this includes all requests with multiple partitions
						cfhttpparam( type = "header", name = "x-ms-documentdb-partitionkeyrangeid", value = "0" );
					}
				} else {
					cfhttpparam( type = "header", name = "Content-Type", value = "application/json" );
				}
				// Any requeest body
				if (Len(Trim(Arguments.requestBody)) GT 0) {
					cfhttpparam( type = "body", value = Arguments.requestBody );
				};
			}
			// Partition Key
			if (local.suppressPartitionRequest == 0 ) {
				if ( Len(Trim(Arguments.partitionKey)) > 0 ) {
	    			cfhttpparam( type = "header", name = "x-ms-documentdb-partitionkey", value = "[""#Arguments.partitionKey#""]" );
				} else if ( Len(Trim(Arguments.requestBody)) GT 0 && isJSON(Arguments.requestBody) ) {
					structJSONRequest = deserializeJSON(Arguments.requestBody);
					if ( structKeyExists(structJSONRequest, "id") && Len(Trim(structJSONRequest.id)) > 0 ) {
						cfhttpparam( type = "header", name = "x-ms-documentdb-partitionkey", value = "[""#structJSONRequest.id#""]" );
					}
				} else if (Arguments.resourceType == "docs") {
					cfhttpparam( type = "header", name = "x-ms-documentdb-partitionkey", value = "[""#listLast(Arguments.resourceLink,"/")#""]" );
				}
			}

			// Any additional headers
			if ( arrayLen(Arguments.headers) GT 0) {
				for ( currentHeader in Arguments.headers) {
					cfhttpparam( type="header", name="#currentHeader#", value="#Arguments.headers[currentHeader]#" );
				}
			}


		};

		return local.requestResponse;

	}


	public function getDocumentList(
		string collectionName requried,
		numeric resultsToReturn = 10,
		numeric previousCount = 0,
		string lastIdOnPreviousPage = "",
		string sqlClause = ""
		) {
		// Retrieve a list of document IDs from a collection. Used as part of my paging strategy

		local.arrayDocumentIds = []
		local.structProcess = {};

		local.queryJSON = {  
		  "query": "SELECT d.id FROM #Arguments.collectionName# d #Arguments.sqlClause#"
		}  ;

		local.requestResponse = callCosmosDb(httpVerb = "POST", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#Arguments.collectionName#", requestBody = serializeJSON(local.queryJSON), isQuery = 1 );

		if ( local.requestResponse.status_code == "200" && isJSON(local.requestResponse.FileContent) ) {
			local.structResponse = deserializeJSON(local.requestResponse.FileContent);
			local.structProcess = local.structResponse.Documents;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}

		local.arrayDocumentIds = arrayMap( local.structProcess, function(item){
		   return item.id;
		});

		// If we have a previous ID remove all preceeding
		if (Arguments.lastIdOnPreviousPage != "") {

			local.foundId = arrayFind(local.arrayDocumentIds, Arguments.lastIdOnPreviousPage);

			if ( local.foundId > 0 ) {
				local.arrayDocumentIds = arraySlice(local.arrayDocumentIds,local.foundId+1,arrayLen(local.arrayDocumentIds)-local.foundId);
			}
		}

		// If we have a previous count, then trim using that
		if ( Arguments.previousCount > 0 && arrayLen(local.arrayDocumentIds) > Arguments.previousCount ) {
			local.arrayDocumentIds = arraySlice(local.arrayDocumentIds,Arguments.previousCount+1,arrayLen(local.arrayDocumentIds)-Arguments.previousCount);
		}

		return local.arrayDocumentIds;
	}


	public function getDocuments(
			string collectionName requried,
			array arrayDocumentIds requried,
			string sqlOrderByClause = ""
		) {
		// Returns all the documents whose IDs are in the supplied array.

		local.arrayToReturn = {};

		local.listDocumentIds = Arguments.arrayDocumentIds.toList();
		local.listDocumentIds = listQualify(local.listDocumentIds, """");

		local.queryJSON = {  
		  "query": "SELECT * FROM #Arguments.collectionName# d WHERE d.id IN (#local.listDocumentIds#) #Arguments.sqlOrderByClause#" 
		}  ;

		local.requestResponse = callCosmosDb(httpVerb = "POST", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#Arguments.collectionName#", requestBody = serializeJSON(local.queryJSON), isQuery = 1 );

		if ( local.requestResponse.status_code == "200" && isJSON(local.requestResponse.FileContent) ) {
			local.structResponse = deserializeJSON(local.requestResponse.FileContent);
			local.arrayToReturn = local.structResponse.Documents;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}

		return local.arrayToReturn;
	}
	
}
