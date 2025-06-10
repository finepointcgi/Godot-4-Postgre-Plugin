extends Node

@onready var postgre_adapter = $PostgreAdapter

func _ready():
	# Replace with your actual PostgreSQL connection details
	# For a local PostgreSQL server, it might look like:
	# "postgresql://user:password@localhost:5432/mydatabase"
	# Make sure the database 'mydatabase' exists and 'user' has access with 'password'.
	postgre_adapter.connection_string = "postgresql://finepointcgi:password@localhost:5432/postgres"
	
	if postgre_adapter.connect_to_db():
		print("Connected to PostgreSQL successfully from GDScript!")

		# Example: Execute a non-query (CREATE TABLE if not exists)
		var create_table_query = "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name VARCHAR(100), age INT);"
		var affected_rows = postgre_adapter.execute_non_query(create_table_query)
		print("CREATE TABLE query result: ", affected_rows)
		if affected_rows != -1:
			print("CREATE TABLE query executed successfully. Affected rows: ", affected_rows)
		else:
			print("CREATE TABLE query failed.")
		
		# Verify table was created
		var table_check_query = "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users');"
		var table_exists = postgre_adapter.execute_query(table_check_query)
		print("Table exists check result: ", table_exists)
		if table_exists.size() > 0 and table_exists[0].has("exists") and table_exists[0]["exists"] == "t":
			print("Table 'users' confirmed to exist in database")
		else:
			print("Table 'users' was NOT created or doesn't exist")

		# Example: Execute a non-query (INSERT data)
		var insert_query = "INSERT INTO users (name, age) VALUES ('Alice', 30), ('Bob', 25);"
		affected_rows = postgre_adapter.execute_non_query(insert_query)
		if affected_rows != -1:
			print("INSERT query executed. Affected rows: ", affected_rows)
		else:
			print("INSERT query failed.")

		# Example: Execute a query (SELECT data)
		var select_query = "SELECT id, name, age FROM users;"
		var results = postgre_adapter.execute_query(select_query)
		print("Query results:")
		for row in results:
			print(row)

		# Example: Execute a non-query (UPDATE data)
		var update_query = "UPDATE users SET age = 31 WHERE name = 'Alice';"
		affected_rows = postgre_adapter.execute_non_query(update_query)
		if affected_rows != -1:
			print("UPDATE query executed. Affected rows: ", affected_rows)
		else:
			print("UPDATE query failed.")

		# Example: Execute another query to see updated data
		results = postgre_adapter.execute_query(select_query)
		print("Query results after update:")
		for row in results:
			print(row)

		# Example: Execute a non-query (DELETE data)
		var delete_query = "DELETE FROM users WHERE name = 'Bob';"
		affected_rows = postgre_adapter.execute_non_query(delete_query)
		if affected_rows != -1:
			print("DELETE query executed. Affected rows: ", affected_rows)
		else:
			print("DELETE query failed.")
		
		# Final verification - check remaining data
		print("Final table contents:")
		results = postgre_adapter.execute_query(select_query)
		for row in results:
			print(row)

		# Disconnect from the database
		postgre_adapter.disconnect_from_db()
	else:
		print("Failed to connect to PostgreSQL from GDScript!")
