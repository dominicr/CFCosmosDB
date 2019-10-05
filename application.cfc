component output="false" {

    this.name = "CFCosmosDB";
    
    // Setting a very short application timeout so that variables aren't cached whilst you're developing
    this.applicationTimeout= CreateTimeSpan(0,0,0,10)


    function onApplicationStart() {

    	// ------------------------------------------------------
    	// These are your CosmosDB variables.
		Application.Azure.CosmosDb.AccountName 		= "- - - - YOUR COSMOS DB ACCOUNT NAME - - - -";
		Application.Azure.CosmosDb.DbName 			= "- - - - YOUR COSMOS DB DATABASE NAME - - - -";
	    Application.Azure.CosmosDb.CollectionName 	= "- - - - YOUR COSMOS DB COLLECTION NAME - - - -";
	    Application.Azure.CosmosDb.SecretKey 		= "- - - - YOUR COSMOS DB SECURITY KEY - - - -";

	    // For ease I'm creating this object here but obviously this can be created as needed
		Application.objCosmosDB = createObject("component", "cfc.CosmosDB").init( key = Application.Azure.CosmosDb.SecretKey );

		// Our dummy userid to use in queries. This is used as the partition key
		Application.userid = "user1234";


    }


	function onRequestStart(targetPage) {
		// Application reload trigger
		if ( structKeyExists(Url, "init") ) {
			onApplicationStart();
		}
	}


	function onError(exception, eventName) {
		writeDump(exception);
		writeDump(eventName);
	}

}