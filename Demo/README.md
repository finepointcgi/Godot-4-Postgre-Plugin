# PostgreSQL Adapter Demo

This demo showcases all the features of the PostgreSQL adapter for Godot.

## Features Demonstrated

### 1. **Basic Setup & Table Creation**
- Creates demo tables with various PostgreSQL data types
- Shows DDL operations (CREATE TABLE)

### 2. **Enhanced Parameter Types**
- **NULL values**: Proper handling of null parameters
- **Vector2/Vector3**: Game-specific data types for positions
- **Boolean values**: True/false parameters
- **Mixed types**: Different parameter types in single query

### 3. **Transaction Support**
- **begin_transaction()**: Start explicit transactions
- **execute_*_in_transaction()**: Run queries within transactions
- **commit_transaction()**: Commit all changes
- **rollback_transaction()**: Cancel changes on error
- **Transaction signals**: Real-time transaction status updates

### 4. **Async Operations**
- **execute_query_async()**: Non-blocking SELECT operations
- **execute_non_query_async()**: Non-blocking INSERT/UPDATE/DELETE
- **Signal-based results**: Get results via Godot signals
- **Parallel execution**: Multiple queries can run simultaneously

### 5. **Cleanup**
- Proper resource management
- Table cleanup
- Connection management

## Running the Demo

1. **Setup PostgreSQL Database**:
   - Make sure PostgreSQL is running locally
   - Update connection string in `db_test.gd` line 25:
     ```gdscript
     postgre_adapter.connection_string = "postgresql://username:password@localhost:5432/database"
     ```

2. **Run the Demo**:
   - Open the demo project in Godot
   - Run the main scene
   - Watch the console output for detailed logs

## Expected Output

The demo will output structured logs showing:
-  Successful operations
-  Async query results
-  Transaction status updates
-  Database operation details
-  Any errors (if they occur)

## Demo Database Tables

The demo creates temporary tables:
- `demo_users`: User information with various data types
- `demo_positions`: Position data demonstrating Vector2/Vector3 support

These tables are automatically cleaned up at the end of the demo.

## Key Learning Points

1. **Parameter Safety**: All queries use parameterized statements to prevent SQL injection
2. **Transaction Management**: Demonstrates ACID properties and rollback scenarios
3. **Async Programming**: Shows how to handle non-blocking database operations
4. **Error Handling**: Comprehensive error handling with user-friendly feedback
5. **Signal-Driven Architecture**: Event-driven programming with database operations