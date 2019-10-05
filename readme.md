# Demo of Cosmos DB for Coldfusion / CFML / Lucee

## Introduction
A while ago I wanted to experiment with Azure's Cosmos DB. It didn't end up getting used but I had a simple proof of concept that worked and I thought other might find it useful as an introduction to using Cosmos DB with Lucee or Coldfusion. This is a very simple demo and the code is not structured how you would in a real world project, but the aim was to make the code as simple to understand as I could.

For this demo I have used created the cliched To Do application. Apologies for the lack of immagination.

## Key Files in this Demo

**Application.cfc**
Update this with your Cosmos DB variables.

**CosmosDB.cfc**
Data access functions for CosmosDB.
- Create an authorisation string to use when connecting to Cosmos DB.
- Call the Cosmos DB API
- Get a list of document IDs from a query
- Return a colleciton of documents from an array of document IDs

**ToDos.cfc**
CRUD DAO functions specific to ToDos.
- Get a document
- A simple method to return a search
- A method for paging results
- Create document
- Update document
- Delete document

**index.cfm**
Function calls and output for the To Dos.

## Setup & How To

Note that for Cosmos DB you have three levels: account, database and collection.

1. In Azure Portal create a Cosmos DB account
	- The **API** options should be set to **Core (SQL)**
	- You won't specifically need any other options (Spark, multi-region or geo-redundency)
2. Create a CosmosDB Database e.g. ToDoDB
3. Create a collection e.g. **ToDos**
	- Refer to the *Notes about Cosmos DB* section of this page
	- **Database id** will be the name of the Cosmos DB account you created in the step above.
	- Use **/userid** as the **Partition key**.
4. Update the Application.Azure.CosmosDb variables in application.cfc with your account, database and collection names and the account's primary key (found in Settings > Keys in Azure Portal). Note that names in Cosmos DB are case sensitive.
5. Run the application (e.g. use Commandbox to run a server from the CFCosmosDB directory)


## Notes
- Documents are retrieved using both by its **partition key and document key**. Therefore if you want to retrieve a particular document you must already know enough about it to know it's partition. e.g. In our example we know the user account ID of the document owner as that is the partition key. This could factor into your design decisions about what the partition key is.
- I didn't find a tidy way to do paging. So my strategy is to do this is two steps: a search returning the IDs of all documents (so that the payload isn't too large), then retriving the documents in full. This is not efficient for large datastores where the listing of IDs alone will be large.
- Cosmos DB's own timestamp (\_ts) is the timestamp of the latest version of the document. If you need to store document creation time then you need to add that to your own document specification. 

## Notes about Cosmos DB

**Cosmos DB is accessed via an API**
Essentially this demo is function that interacts with an API that has particular requirements. I've only covered the basic functions of CosmosDB in this demo but all other functions will be a case of reading the manual and updating the functions.

**Costs**
Cosmos DB pricing is largely based on a reserved usage *per container* and is charged regardless of usage. The minimum charge is about $24 per month *per container*. This is quite different from a typical database, so you need to factor this into the design. Don't think of Cosmos DB containers as equivalent to a traditional database table, as each table will increase your costs.

**Partition keys**
Partition keys are NOT the same as primary keys. In large datasets the Partition Key will be used to group data together, so is a performance consideration. It is quicker to retrieve data from a single partition, so use the partition key to group data which you'll retrieve together. e.g. a customer id. *The value of partition keys is not unique, it should be regularly reused.*

It is possible to specify **Unique keys** for a collection, to ensure data integrity (no duplicate records). However this is optional.
