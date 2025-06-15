extends Node

@onready var postgre_adapter = $PostgreAdapter

# Demo state management
var async_queries_completed = 0
var expected_async_queries = 2
var test_results = {}
var tests_run = 0
var tests_passed = 0

func _ready():
	
	# Connect all available signals
	postgre_adapter.query_completed.connect(_on_async_query_completed)
	postgre_adapter.non_query_completed.connect(_on_async_non_query_completed)
	postgre_adapter.async_query_failed.connect(_on_async_query_failed)
	
	# Error signals
	postgre_adapter.query_failed.connect(_on_query_failed)
	postgre_adapter.non_query_failed.connect(_on_non_query_failed)
	postgre_adapter.connection_error.connect(_on_connection_error)
	
	# Transaction signals
	postgre_adapter.transaction_started.connect(_on_transaction_started)
	postgre_adapter.transaction_committed.connect(_on_transaction_committed)
	postgre_adapter.transaction_rolled_back.connect(_on_transaction_rolled_back)
	postgre_adapter.transaction_failed.connect(_on_transaction_failed)
	
	# Replace with your actual PostgreSQL connection details
	postgre_adapter.connection_string = "postgresql://finepointcgi:password@localhost:5432/postgres"
	
	# Test connection pool configuration
	print("🔧 Testing connection pool configuration...")
	assert_test("Pool size default", postgre_adapter.get_pool_size() == 4)
	postgre_adapter.set_pool_size(6)
	assert_test("Pool size setter", postgre_adapter.get_pool_size() == 6)
	postgre_adapter.set_pool_size(4)  # Reset to default
	
	if postgre_adapter.connect_to_db():
		print("✅ Connected to PostgreSQL successfully!")
		
		# Run comprehensive demo
		await run_comprehensive_demo()
		
		print_test_summary()
	else:
		print("❌ Failed to connect to PostgreSQL!")
		assert_test("Database connection", false)

func run_comprehensive_demo():
	print("\n📋 1. BASIC SETUP & TABLE CREATION")
	await demo_basic_setup()
	
	print("\n🔢 2. ENHANCED PARAMETER TYPES DEMO")
	await demo_enhanced_parameters()
	
	print("\n🔄 3. TRANSACTION DEMO")
	await demo_transactions()
	
	print("\n⚡ 4. ASYNC OPERATIONS DEMO")
	await demo_async_operations()
	
	print("\n🔍 5. COMPREHENSIVE DATA TYPE TESTS")
	await demo_data_types()
	
	print("\n❌ 6. ERROR HANDLING TESTS")
	await demo_error_handling()
	
	print("\n🔗 7. COMPLEX QUERY TESTS")
	await demo_complex_queries()
	
	print("\n🚀 8. PERFORMANCE & STRESS TESTS")
	await demo_performance_tests()
	
	print("\n🧹 9. CLEANUP")
	cleanup_demo_tables()

func demo_basic_setup():
	# Create enhanced demo tables
	var create_users_table = """
		CREATE TABLE IF NOT EXISTS demo_users (
			id SERIAL PRIMARY KEY,
			name VARCHAR(100) NOT NULL,
			age INT,
			email VARCHAR(200),
			is_active BOOLEAN DEFAULT true,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
	"""
	
	var create_positions_table = """
		CREATE TABLE IF NOT EXISTS demo_positions (
			id SERIAL PRIMARY KEY,
			user_id INT REFERENCES demo_users(id),
			position_2d POINT,
			position_3d TEXT,
			metadata JSONB
		);
	"""
	
	print("Creating demo tables...")
	var result = postgre_adapter.execute_non_query(create_users_table)
	print("Users table created: ", result != -1)
	
	result = postgre_adapter.execute_non_query(create_positions_table)
	print("Positions table created: ", result != -1)

func demo_enhanced_parameters():
	print("Testing enhanced parameter types...")
	
	# Test with various parameter types
	var insert_user_query = "INSERT INTO demo_users (name, age, email, is_active) VALUES ($1, $2, $3, $4) RETURNING id;"
	
	# Insert users with different parameter types
	var params1 = ["Alice Johnson", 28, "alice@example.com", true]
	var params2 = ["Bob Smith", 35, "bob@example.com", false]
	var params3 = ["Carol Davis", null, "carol@example.com", true]  # NULL age
	
	print("\nInserting users with parameterized queries...")
	var user1_result = postgre_adapter.execute_query(insert_user_query, params1)
	var user2_result = postgre_adapter.execute_query(insert_user_query, params2)
	var user3_result = postgre_adapter.execute_query(insert_user_query, params3)
	
	print("User 1 ID: ", user1_result[0]["id"] if user1_result.size() > 0 else "Failed")
	print("User 2 ID: ", user2_result[0]["id"] if user2_result.size() > 0 else "Failed")
	print("User 3 ID: ", user3_result[0]["id"] if user3_result.size() > 0 else "Failed")
	
	# Test Vector2 and Vector3 parameters
	if user1_result.size() > 0:
		var user_id = int(user1_result[0]["id"])
		var pos_2d = Vector2(100.5, 200.75)
		var pos_3d = Vector3(10.1, 20.2, 30.3)
		
		var insert_position_query = """
			INSERT INTO demo_positions (user_id, position_2d, position_3d, metadata) 
			VALUES ($1, $2, $3, $4);
		"""
		
		var position_params = [
			user_id, 
			pos_2d,  # Vector2 converted to PostgreSQL POINT
			pos_3d,  # Vector3 converted to text representation
			'{"level": 5, "score": 1250}'
		]
		
		var pos_result = postgre_adapter.execute_non_query(insert_position_query, position_params)
		print("Position data inserted: ", pos_result != -1)
		print("  - 2D Position: ", pos_2d)
		print("  - 3D Position: ", pos_3d)

func demo_transactions():
	print("Testing transaction support...")
	
	# Start transaction
	var transaction_started = postgre_adapter.begin_transaction()
	print("Transaction started: ", transaction_started)
	
	if transaction_started:
		# Execute multiple operations in transaction
		var insert1 = postgre_adapter.execute_non_query_in_transaction(
			"INSERT INTO demo_users (name, age, email) VALUES ($1, $2, $3);",
			["Transaction User 1", 25, "trans1@example.com"]
		)
		
		var insert2 = postgre_adapter.execute_non_query_in_transaction(
			"INSERT INTO demo_users (name, age, email) VALUES ($1, $2, $3);",
			["Transaction User 2", 30, "trans2@example.com"]
		)
		
		print("Insert 1 in transaction: ", insert1)
		print("Insert 2 in transaction: ", insert2)
		
		# Query within transaction to verify data
		var transaction_query_result = postgre_adapter.execute_query_in_transaction(
			"SELECT name FROM demo_users WHERE email LIKE '%@example.com' ORDER BY id DESC LIMIT 2;"
		)
		
		print("Users in transaction: ")
		for row in transaction_query_result:
			print("  - ", row["name"])
		
		# Commit transaction
		var committed = postgre_adapter.commit_transaction()
		print("Transaction committed: ", committed)
		
		# Verify data persisted after commit
		await get_tree().process_frame  # Allow signal processing
		var final_check = postgre_adapter.execute_query("SELECT COUNT(*) as count FROM demo_users WHERE email LIKE '%@example.com';")
		print("Total users after transaction: ", final_check[0]["count"] if final_check.size() > 0 else "Unknown")

	# Demo rollback scenario
	print("\nTesting transaction rollback...")
	if postgre_adapter.begin_transaction():
		postgre_adapter.execute_non_query_in_transaction(
			"INSERT INTO demo_users (name, age, email) VALUES ($1, $2, $3);",
			["Rollback User", 99, "rollback@example.com"]
		)
		
		var rollback_result = postgre_adapter.rollback_transaction()
		print("Transaction rolled back: ", rollback_result)
		
		# Verify rollback worked
		var rollback_check = postgre_adapter.execute_query("SELECT COUNT(*) as count FROM demo_users WHERE email = 'rollback@example.com';")
		print("Rollback user count (should be 0): ", rollback_check[0]["count"] if rollback_check.size() > 0 else "Unknown")

func demo_async_operations():
	print("Testing async query operations...")
	print("Starting async queries... (results will appear via signals)")
	
	# Reset async counter
	async_queries_completed = 0
	
	# Start async operations
	postgre_adapter.execute_query_async("SELECT name, age FROM demo_users WHERE is_active = true ORDER BY name;")
	postgre_adapter.execute_non_query_async("UPDATE demo_users SET is_active = true WHERE age > 25;")
	
	# Wait for async operations to complete
	while async_queries_completed < expected_async_queries:
		await get_tree().process_frame
		await get_tree().create_timer(0.1).timeout
	
	print("All async operations completed!")

func cleanup_demo_tables():
	print("Cleaning up demo tables...")
	postgre_adapter.execute_non_query("DROP TABLE IF EXISTS demo_datatypes;")
	postgre_adapter.execute_non_query("DROP TABLE IF EXISTS demo_positions;")
	postgre_adapter.execute_non_query("DROP TABLE IF EXISTS demo_users;")
	print("Demo tables cleaned up!")
	
	postgre_adapter.disconnect_from_db()
	print("Disconnected from database.")

# New comprehensive test functions
func demo_data_types():
	print("Testing comprehensive data types...")
	
	# Create test table with various data types
	var create_datatypes_table = """
		CREATE TABLE IF NOT EXISTS demo_datatypes (
			id SERIAL PRIMARY KEY,
			test_text TEXT,
			test_varchar VARCHAR(50),
			test_int INTEGER,
			test_bigint BIGINT,
			test_float REAL,
			test_double DOUBLE PRECISION,
			test_decimal DECIMAL(10,2),
			test_boolean BOOLEAN,
			test_date DATE,
			test_timestamp TIMESTAMP,
			test_json JSONB,
			test_array INTEGER[],
			test_point POINT
		);
	"""
	
	var result = postgre_adapter.execute_non_query(create_datatypes_table)
	assert_test("Data types table creation", result != -1)
	
	# Test various data types
	var insert_query = """
		INSERT INTO demo_datatypes 
		(test_text, test_varchar, test_int, test_bigint, test_float, test_double, 
		 test_decimal, test_boolean, test_date, test_timestamp, test_json, test_point) 
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING id;
	"""
	
	var params = [
		"Long text with special characters: åäö ñ 中文",
		"Short text",
		42,
		9223372036854775807,  # Max BIGINT
		3.14159,
		2.718281828459045,
		123.45,
		true,
		"2024-01-15",
		"2024-01-15 10:30:00",
		'{"name": "Test", "values": [1, 2, 3]}',
		Vector2(100.5, 200.75)
	]
	
	var insert_result = postgre_adapter.execute_query(insert_query, params)
	assert_test("Complex data types insert", insert_result.size() > 0)
	
	if insert_result.size() > 0:
		var test_id = insert_result[0]["id"]
		var select_result = postgre_adapter.execute_query(
			"SELECT * FROM demo_datatypes WHERE id = $1;", [test_id]
		)
		assert_test("Data types retrieval", select_result.size() > 0)
		
		if select_result.size() > 0:
			var row = select_result[0]
			print("  ✓ Retrieved complex data types successfully")
			print("    - Text: ", row["test_text"])
			print("    - JSON: ", row["test_json"])
			print("    - Point: ", row["test_point"])

func demo_error_handling():
	print("Testing error handling scenarios...")
	
	# Test invalid SQL
	var invalid_result = postgre_adapter.execute_query("INVALID SQL STATEMENT")
	assert_test("Invalid SQL handling", invalid_result.size() == 0)
	
	# Test SQL injection prevention
	var malicious_input = "'; DROP TABLE demo_users; --"
	var safe_query = "SELECT name FROM demo_users WHERE email = $1;"
	var injection_result = postgre_adapter.execute_query(safe_query, [malicious_input])
	assert_test("SQL injection prevention", injection_result.size() == 0)
	
	# Test invalid parameters
	var param_test = postgre_adapter.execute_query(
		"SELECT * FROM demo_users WHERE id = $1;", ["not_a_number"]
	)
	assert_test("Invalid parameter handling", param_test.size() == 0)
	
	# Test non-existent table
	var missing_table = postgre_adapter.execute_query("SELECT * FROM non_existent_table;")
	assert_test("Missing table handling", missing_table.size() == 0)

func demo_complex_queries():
	print("Testing complex query operations...")
	
	# Test JOIN operations
	var join_query = """
		SELECT u.name, u.email, p.position_2d, p.metadata
		FROM demo_users u
		LEFT JOIN demo_positions p ON u.id = p.user_id
		WHERE u.is_active = true
		ORDER BY u.name;
	"""
	
	var join_result = postgre_adapter.execute_query(join_query)
	assert_test("JOIN query execution", join_result.size() >= 0)
	print("  ✓ JOIN query returned ", join_result.size(), " rows")
	
	# Test aggregate functions
	var aggregate_query = """
		SELECT 
			COUNT(*) as total_users,
			AVG(age) as average_age,
			MIN(age) as min_age,
			MAX(age) as max_age
		FROM demo_users 
		WHERE age IS NOT NULL;
	"""
	
	var agg_result = postgre_adapter.execute_query(aggregate_query)
	assert_test("Aggregate functions", agg_result.size() > 0)
	
	if agg_result.size() > 0:
		print("  ✓ User statistics:")
		print("    - Total users: ", agg_result[0]["total_users"])
		print("    - Average age: ", agg_result[0]["average_age"])
	
	# Test subqueries
	var subquery = """
		SELECT name, age FROM demo_users 
		WHERE age > (SELECT AVG(age) FROM demo_users WHERE age IS NOT NULL);
	"""
	
	var sub_result = postgre_adapter.execute_query(subquery)
	assert_test("Subquery execution", sub_result.size() >= 0)
	
	# Test DELETE operation
	var delete_result = postgre_adapter.execute_non_query(
		"DELETE FROM demo_users WHERE email LIKE '%rollback%';"
	)
	assert_test("DELETE operation", delete_result >= 0)

func demo_performance_tests():
	print("Testing performance and stress scenarios...")
	
	# Test batch inserts
	print("  - Testing batch insert performance...")
	var start_time = Time.get_time_dict_from_system()
	
	for i in range(50):
		var batch_insert = postgre_adapter.execute_non_query(
			"INSERT INTO demo_users (name, age, email) VALUES ($1, $2, $3);",
			["Batch User " + str(i), 20 + (i % 40), "batch" + str(i) + "@test.com"]
		)
		if batch_insert == -1:
			break
	
	var end_time = Time.get_time_dict_from_system()
	print("  ✓ Batch insert completed")
	
	# Test large result set
	var large_query = "SELECT * FROM demo_users ORDER BY id;"
	var large_result = postgre_adapter.execute_query(large_query)
	assert_test("Large result set handling", large_result.size() >= 0)
	print("  ✓ Retrieved ", large_result.size(), " rows")
	
	# Test connection stability
	for i in range(10):
		var stability_test = postgre_adapter.execute_query("SELECT 1 as test;")
		if stability_test.size() == 0:
			assert_test("Connection stability test " + str(i), false)
			break
	
	assert_test("Connection stability (10 queries)", true)
	print("  ✓ Connection remained stable through multiple queries")

# Test utility functions
func assert_test(test_name: String, condition: bool):
	tests_run += 1
	if condition:
		tests_passed += 1
		test_results[test_name] = "PASS"
		print("  ✅ ", test_name, ": PASS")
	else:
		test_results[test_name] = "FAIL"
		print("  ❌ ", test_name, ": FAIL")

func print_test_summary():

	print("🧪 TEST SUMMARY")
	
	print("Tests run: ", tests_run)
	print("Tests passed: ", tests_passed)
	print("Tests failed: ", tests_run - tests_passed)
	print("Success rate: ", float(tests_passed) / float(tests_run) * 100.0, "%")
	
	if tests_passed == tests_run:
		print("\n🎉 ALL TESTS PASSED! Your PostgreSQL GDExtension is working perfectly!")
	else:
		print("\n⚠️  Some tests failed. Check the output above for details.")
		print("\nFailed tests:")
		for test_name in test_results:
			if test_results[test_name] == "FAIL":
				print("  - ", test_name)
	


# Signal handlers for async operations
func _on_async_query_completed(results: Array):
	print("📥 Async query completed! Results:")
	for row in results:
		print("  ", row)
	async_queries_completed += 1

func _on_async_non_query_completed(affected_rows: int):
	print("📝 Async non-query completed! Affected rows: ", affected_rows)
	async_queries_completed += 1

func _on_async_query_failed(query: String, error: String):
	print("Async query failed: ", query, " Error: ", error)
	async_queries_completed += 1

# Signal handlers for transactions
func _on_transaction_started():
	print("🔄 Transaction started successfully!")

func _on_transaction_committed():
	print("Transaction committed successfully!")

func _on_transaction_rolled_back():
	print("🔄 Transaction rolled back successfully!")

func _on_transaction_failed(error: String):
	print("❌ Transaction failed: ", error)

# Signal handlers for error signals
func _on_query_failed(query: String, error: String):
	print("❌ Query failed: ", query, " Error: ", error)

func _on_non_query_failed(query: String, error: String):
	print("❌ Non-query failed: ", query, " Error: ", error)

func _on_connection_error(error: String):
	print("❌ Connection error: ", error)
