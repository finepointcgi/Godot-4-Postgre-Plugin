extends Node

@onready var postgre_adapter = $PostgreAdapter

# Demo state management
var async_queries_completed = 0
var expected_async_queries = 2

func _ready():
	
	# Connect signals for async operations
	postgre_adapter.query_completed.connect(_on_async_query_completed)
	postgre_adapter.non_query_completed.connect(_on_async_non_query_completed)
	postgre_adapter.async_query_failed.connect(_on_async_query_failed)
	
	# Connect transaction signals
	postgre_adapter.transaction_started.connect(_on_transaction_started)
	postgre_adapter.transaction_committed.connect(_on_transaction_committed)
	postgre_adapter.transaction_rolled_back.connect(_on_transaction_rolled_back)
	postgre_adapter.transaction_failed.connect(_on_transaction_failed)
	
	# Replace with your actual PostgreSQL connection details
	postgre_adapter.connection_string = "postgresql://finepointcgi:password@localhost:5432/postgres"
	
	if postgre_adapter.connect_to_db():
		print(" Connected to PostgreSQL successfully!")
		
		# Run comprehensive demo
		await run_comprehensive_demo()
		
		print("\n Demo completed successfully!")
		print("Check the console output above to see all features in action.")
	else:
		print("Failed to connect to PostgreSQL!")

func run_comprehensive_demo():
	print("\n📋 1. BASIC SETUP & TABLE CREATION")

	await demo_basic_setup()
	
	print("\n 2. ENHANCED PARAMETER TYPES DEMO")
	#print("-" * 40)
	await demo_enhanced_parameters()
	
	print("\n 3. TRANSACTION DEMO")
	#print("-" * 40)
	await demo_transactions()
	
	print("\n⚡ 4. ASYNC OPERATIONS DEMO")
	#print("-" * 40)
	await demo_async_operations()
	
	#print("\n🧹 5. CLEANUP")
	#print("-" * 40)
	#cleanup_demo_tables()

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
	postgre_adapter.execute_non_query("DROP TABLE IF EXISTS demo_positions;")
	postgre_adapter.execute_non_query("DROP TABLE IF EXISTS demo_users;")
	print("Demo tables cleaned up!")
	
	postgre_adapter.disconnect_from_db()
	print("Disconnected from database.")

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
	print("❌ Async query failed: ", query, " Error: ", error)
	async_queries_completed += 1

# Signal handlers for transactions
func _on_transaction_started():
	print("🔄 Transaction started successfully!")

func _on_transaction_committed():
	print("✅ Transaction committed successfully!")

func _on_transaction_rolled_back():
	print("🔄 Transaction rolled back successfully!")

func _on_transaction_failed(error: String):
	print("❌ Transaction failed: ", error)
