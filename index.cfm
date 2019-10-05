<cfinclude template="includes/header.cfm">

<cfscript>

// Create our data access object
objTodo = createObject("component", "cfc.ToDo").init();


// Handle CREATE form posts
if (isDefined("form.submit")) {
	if ( len(trim(form.todoText)) GT 0 ) {
		objTodo.createToDo(todoText = form.todotext, userid = Application.userid);
	}
}


// Handle marking complete/incomplete via url param
if (isDefined("url.completeID")) {
	if ( len(trim(url.completeID)) GT 0 ) {
		objTodo.completeToDo(userid = Application.userid, todoID = url.completeID);
	}
}


// Handle deleting via url param
if (isDefined("url.deleteID")) {
	if ( len(trim(url.deleteID)) GT 0 ) {
		objTodo.deleteToDo(userid = Application.userid, todoID = url.deleteID);
	}
}

// Get ToDos
arrayToDos = objTodo.getToDosPaging(userID = Application.userid);

</cfscript>

<h3 class="is-size-4 has-text-weight-bold">ToDos</h3>

<table class="table is-bordered">

	<cfloop array="#arrayToDos#" item="structToDo">
		<cfoutput>
			<tr>
				<td><a class="delete" href="?deleteID=#structToDo.id#"></a></td>
				<td><a class="button is-small" href="?completeID=#structToDo.id#">Complete</td>
				<td>
					<cfif isDefined("structToDo.complete") && structToDo.complete == 1>
						<del>#structToDo.text#</del>
					<cfelse>
						#structToDo.text#
					</cfif>
				</td>
			</tr>
		</cfoutput>
	</cfloop> 

</table>

<h3 class="is-size-4 has-text-weight-bold">Create</h3>

<form action="index.cfm" method="post">
	<div class="field">
		<label class="label">To Do Text</label>
		<div class="control">
			<input class="input" type="text" placeholder="To Do text" name="todotext">
		</div>
	</div>
	<div class="field">
		<div class="control">
			<button class="button is-link" name="submit">Create</button>
		</div>
	</div>
</form>


<cfinclude template="includes/footer.cfm">