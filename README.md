# PostgreSQL GDExtension for Godot

[![Build Status](https://github.com/yourusername/PostgrePlugin/workflows/Build%20PostgreSQL%20GDExtension/badge.svg)](https://github.com/yourusername/PostgrePlugin/actions/workflows/build.yml)
[![Tests](https://github.com/yourusername/PostgrePlugin/workflows/Test%20PostgreSQL%20Extension/badge.svg)](https://github.com/yourusername/PostgrePlugin/actions/workflows/test.yml)
[![Nightly](https://github.com/yourusername/PostgrePlugin/workflows/Nightly%20Builds/badge.svg)](https://github.com/yourusername/PostgrePlugin/actions/workflows/nightly.yml)

A PostgreSQL database adapter for Godot 4, implemented as a native GDExtension using C++ and libpqxx. This plugin allows PostgreSQL database connections with features like connection pooling, transaction management, and asynchronous operations.

## 📦 Pre-built Binaries

Download ready-to-use binaries for all platforms from the [Releases](https://github.com/yourusername/PostgrePlugin/releases) page:
- **Linux**: x86_64 and ARM64
- **Windows**: x86_64
- **macOS**: Universal (Intel + Apple Silicon)

## Features

### Core Database Operations
- **Parameterized Queries**: Safe SQL execution with parameter binding to prevent injection attacks
- **Connection Pooling**: Efficient connection management with configurable pool size
- **Automatic Reconnection**: Built-in retry logic for handling connection failures
- **Modern libpqxx API**: Uses the latest non-deprecated PostgreSQL C++ library features

### Advanced Features
- **Transaction Management**: Full ACID transaction support with explicit control
- **Asynchronous Operations**: Non-blocking query execution with signal-based results
- **Enhanced Parameter Types**: Support for Godot-specific types (Vector2, Vector3) and NULL values
- **Comprehensive Error Handling**: Detailed error reporting with automatic recovery

### Godot Integration
- **Signal-Based Architecture**: Event-driven programming with database operation signals
- **Property System**: Easy configuration through Godot's inspector
- **Resource Management**: Automatic cleanup and proper memory handling

## Installation

### Prerequisites
- Godot 4.x
- PostgreSQL client libraries (libpq, libpqxx)
- C++ compiler with C++17 support
- SCons build system

### macOS Installation
```bash
# Install dependencies via Homebrew
brew install postgresql libpqxx

# Clone the repository
git clone https://github.com/yourusername/PostgrePlugin.git
cd PostgrePlugin

# Build the extension
scons

# The built plugin will be available in demo/bin/
```

### Linux Installation
```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install libpqxx-dev libpq-dev

# Or for Fedora/RHEL
sudo dnf install libpqxx-devel libpq-devel

# Build as above
scons
```

## Quick Start

### Basic Setup
```gdscript
# Add PostgreAdapter node to your scene
@onready var db = $PostgreAdapter

func _ready():
    # Configure connection
    db.connection_string = "postgresql://username:password@localhost:5432/database"
    db.pool_size = 4
    
    # Connect to database
    if db.connect_to_db():
        print("Connected successfully!")
        
        # Execute a simple query
        var results = db.execute_query("SELECT * FROM users WHERE active = $1", [true])
        for row in results:
            print("User: ", row["name"])
```

### Transaction Example
```gdscript
# Start transaction
if db.begin_transaction():
    # Execute multiple operations
    db.execute_non_query_in_transaction(
        "INSERT INTO users (name, email) VALUES ($1, $2)",
        ["John Doe", "john@example.com"]
    )
    
    db.execute_non_query_in_transaction(
        "UPDATE user_stats SET login_count = login_count + 1 WHERE user_id = $1",
        [user_id]
    )
    
    # Commit or rollback
    if success_condition:
        db.commit_transaction()
    else:
        db.rollback_transaction()
```

### Asynchronous Operations
```gdscript
func _ready():
    # Connect signals
    db.query_completed.connect(_on_query_completed)
    db.async_query_failed.connect(_on_query_failed)
    
    # Execute async query
    db.execute_query_async("SELECT * FROM large_table")

func _on_query_completed(results: Array):
    print("Async query returned ", results.size(), " rows")
    process_results(results)

func _on_query_failed(query: String, error: String):
    print("Query failed: ", error)
```

## API Reference

### Core Methods
- `connect_to_db() -> bool`: Establish database connection
- `disconnect_from_db()`: Close database connection
- `execute_query(query: String, params: Array = []) -> Array`: Execute SELECT queries
- `execute_non_query(query: String, params: Array = []) -> int`: Execute INSERT/UPDATE/DELETE

### Transaction Methods
- `begin_transaction() -> bool`: Start a new transaction
- `commit_transaction() -> bool`: Commit current transaction
- `rollback_transaction() -> bool`: Rollback current transaction
- `execute_query_in_transaction(query: String, params: Array = []) -> Array`
- `execute_non_query_in_transaction(query: String, params: Array = []) -> int`

### Asynchronous Methods
- `execute_query_async(query: String, params: Array = [])`: Non-blocking query execution
- `execute_non_query_async(query: String, params: Array = [])`: Non-blocking non-query execution

### Properties
- `connection_string: String`: PostgreSQL connection string
- `pool_size: int`: Number of connections in the pool (default: 4)

### Signals
- `query_completed(results: Array)`: Emitted when async query completes
- `non_query_completed(affected_rows: int)`: Emitted when async non-query completes
- `async_query_failed(query: String, error: String)`: Emitted on async operation failure
- `transaction_started()`: Emitted when transaction begins
- `transaction_committed()`: Emitted when transaction commits
- `transaction_rolled_back()`: Emitted when transaction rolls back
- `transaction_failed(error: String)`: Emitted on transaction error

## Supported Parameter Types

The adapter supports automatic conversion for the following Godot types:
- `String`: Direct string values
- `int`/`int64`: Numeric values
- `float`/`double`: Floating-point values
- `bool`: Boolean values (converted to PostgreSQL boolean)
- `Vector2`: Converted to PostgreSQL POINT type
- `Vector3`: Converted to text representation
- `null`: Handled as PostgreSQL NULL

## Connection String Format

```
postgresql://[username[:password]@][host][:port][/database][?param1=value1&...]
```

Examples:
- `postgresql://user:pass@localhost:5432/mydb`
- `postgresql://localhost/mydb`
- `postgresql://user@remote.host:5433/mydb?sslmode=require`

## Error Handling

The adapter provides comprehensive error handling with automatic retry logic:

- **Connection Failures**: Automatic reconnection attempts
- **Query Errors**: Detailed error messages with context
- **Transaction Errors**: Automatic rollback on failure
- **Signal-Based Notifications**: Real-time error reporting

## Performance Considerations

- **Connection Pooling**: Reduces connection overhead for multiple operations
- **Prepared Statements**: Automatic preparation for repeated queries
- **Asynchronous Operations**: Prevents blocking the main thread
- **Resource Management**: Efficient memory usage with automatic cleanup

## Demo Project

The included demo project showcases all features:
- Basic CRUD operations
- Parameterized queries with various data types
- Transaction management
- Asynchronous operation handling
- Error handling and recovery

To run the demo:
1. Update the connection string in `Demo/db_test.gd`
2. Run the demo scene in Godot
3. Check the console output for detailed operation logs

## Building from Source

### Build Requirements
- Godot 4.x headers (included via godot-cpp submodule)
- PostgreSQL development libraries
- C++17 compatible compiler

### Build Process
```bash
# Initialize submodules
git submodule update --init --recursive

# Build godot-cpp
cd godot-cpp
scons platform=<platform> target=template_debug
cd ..

# Build the extension
scons platform=<platform> target=template_debug

# For release builds
scons platform=<platform> target=template_release
```

### Platform-Specific Notes

**macOS**: Requires PostgreSQL libraries from Homebrew
**Linux**: Install development packages for libpqxx and libpq
**Windows**: Requires PostgreSQL development libraries and Visual Studio

## Contributing

Contributions are welcome! Please follow these guidelines:
- Use consistent C++ coding style
- Include tests for new features
- Update documentation for API changes
- Ensure cross-platform compatibility

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Dependencies

- **godot-cpp**: Godot C++ bindings (included as submodule)
- **libpqxx**: C++ PostgreSQL library
- **libpq**: PostgreSQL client library
- **SCons**: Build system

## Support

For issues, questions, or contributions:
- GitHub Issues: Report bugs and request features
- Documentation: Check the demo project for usage examples
- PostgreSQL Documentation: For database-specific questions

## Changelog

### Latest Version
- Modern libpqxx API support (no deprecated warnings)
- Enhanced parameter type support (Vector2, Vector3, NULL)
- Full transaction management
- Asynchronous operation support
- Improved error handling and recovery
- Comprehensive signal system
- Connection pooling with configurable size