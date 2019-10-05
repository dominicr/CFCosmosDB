component output="false" {

	// In other projects each CFC maps to a collection, so I have set this within the CFC
	this.collectionName = Application.Azure.CosmosDb.CollectionName;

	public function init(){
		return this;
	}

	public function emptyToDo() {
		// I use structures which match the Cosmos DB document to manipulate document data, which is then serialized into JSON and stored on Cosmos DB.

		local.structToDo = {
		  "id": "#createUUID()#", //If the ID were blank then Cosmos DB will assign the document on at creation.
		  "userid": "",
		  "text": "",
		  "timestamp": DateDiff("s", CreateDate(1970,1,1), now()), //Epoch timestamp
		  "complete": false
		};

		return local.structToDo;
	}


	public function getToDo(string userID requried, string todoID requried) {
		// Get a single ToDo

		local.structToReturn = {};

		// To get a single document we call the URL for that document.
		local.requestResponse = Application.objCosmosDB.callCosmosDb( httpVerb = "get", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#this.collectionName#/docs/#Arguments.todoID#", partitionKey=Arguments.userid);

		if ( local.requestResponse.status_code == "200" && isJSON(local.requestResponse.FileContent) ) {
			local.structToReturn = deserializeJSON(local.requestResponse.FileContent);
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}

		return local.structToReturn;
	}


	public function getToDosSimple(string userID requried, numeric resultsToReturn = 10) {
		// Simple version of getting all ToDos, with no paging

		local.structToReturn = {};

		// Queries are posted to Cosmos DB as JSON strings
		local.queryJSON = {  
		  "query": "SELECT TOP #Arguments.resultsToReturn# * FROM #this.collectionName# d WHERE d.userid = @userID",  
		  "parameters": [  
		    {  
		      "name": "@userID",  
		      "value": "#Arguments.userID#"  
		    }
		  ]  
		};

		local.requestResponse = Application.objCosmosDB.callCosmosDb(httpVerb = "POST", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#this.collectionName#", requestBody = serializeJSON(local.queryJSON), isQuery = 1 );

		if ( local.requestResponse.status_code == "200" && isJSON(local.requestResponse.FileContent) ) {
			// Success
			local.structResponse = deserializeJSON(local.requestResponse.FileContent);
			local.structToReturn = local.structResponse.Documents;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}

		return local.structToReturn;
	}


	public function getToDosPaging(string userID requried, numeric resultsToReturn = 10, numeric previousCount = 0, string lastIdOnPreviousPage = "") {
		/*	
			A more advanced paging of documents. Accepts either the count of the previous page, or the last ID that was retrieved.
			I didn't find a tidy way to do paging. So my strategy is to do this is two steps: a search returning the IDs of all documents (so that the payload isn't too large), then retriving the documents in full. This is not efficient for large datastores where the listing of IDs alone will be large.
		*/

		local.structToReturn = {};

		local.sqlOrderByClause = " ORDER BY d.timestamp DESC";

		local.arrayDocumentList = Application.objCosmosDB.getDocumentList(
			collectionName = this.collectionName,
			resultsToReturn = Arguments.resultsToReturn,
			previousCount=Arguments.previousCount,
			lastIdOnPreviousPage = Arguments.lastIdOnPreviousPage,
			sqlClause = "WHERE d.userid = ""#Arguments.userid#""" & local.sqlOrderByClause);

		local.arrayToReturn = Application.objCosmosDB.getDocuments(
			collectionName = this.collectionName,
			arrayDocumentIds = local.arrayDocumentList,
			sqlOrderByClause = local.sqlOrderByClause)

		return local.arrayToReturn;
	}


	public function createToDo(string todoText requried, string userid requried) {
		// New documents are created by posting the document JSON to the collection

		local.structToDo = emptyToDo();
		local.structToDo.userid = Arguments.userid;
		local.structToDo.text = Arguments.todoText;

		local.requestResponse = Application.objCosmosDB.callCosmosDb(httpVerb = "POST", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#this.collectionName#", requestBody = serializeJSON(local.structToDo), partitionKey=Application.userid );

		if ( local.requestResponse.status_code == "201" ) {
			return true;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}
	}

	
	public function completeToDo(string userID requried, string todoID requried) {
		// An update in CosmosDB expects the full document to be submitted again. Therefore load the full doc, edit it, and submit it back to itself.

		local.structToDo = getToDo(Arguments.userID, Arguments.todoID);
		local.structToDo["complete"] = local.structToDo["complete"] ? false : true;

		local.requestResponse = Application.objCosmosDB.callCosmosDb(httpVerb = "PUT", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#this.collectionName#/docs/#Arguments.todoID#", requestBody = serializeJSON(local.structToDo), partitionKey=Application.userid );

		if ( local.requestResponse.status_code == "200" ) {
			return true;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}
	}

	
	public function deleteToDo(string userID requried, string todoID requried) {
		// Deleting a document is via a DELETE call to the document 

		local.requestResponse = Application.objCosmosDB.callCosmosDb(httpVerb = "DELETE", databaseAccount = Application.Azure.CosmosDb.AccountName, resourceType = "docs", resourceLink = "dbs/#Application.Azure.CosmosDb.DbName#/colls/#this.collectionName#/docs/#Arguments.todoID#", partitionKey=Application.userid );

		// Note that for deletion the HTTP status code is 204 (No Content) instead of 200
		if ( local.requestResponse.status_code == "204" ) {
			return true;
		} else {
			// Error: log exception here
			writeDump(local.requestResponse);
		}
	}

}