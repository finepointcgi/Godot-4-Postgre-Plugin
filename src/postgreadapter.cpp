#include <godot_cpp/variant/string.hpp>
#include "postgreadapter.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <pqxx/pqxx> // For PostgreSQL interaction
#include "connection_pool.h"

using namespace godot;

void PostgreAdapter::_bind_methods() {
 	ClassDB::bind_method(D_METHOD("set_connection_string", "connection_string"), &PostgreAdapter::set_connection_string);
 	ClassDB::bind_method(D_METHOD("get_connection_string"), &PostgreAdapter::get_connection_string);
 	ADD_PROPERTY(PropertyInfo(Variant::STRING, "connection_string"), "set_connection_string", "get_connection_string");
 
 	ClassDB::bind_method(D_METHOD("set_pool_size", "pool_size"), &PostgreAdapter::set_pool_size);
 	ClassDB::bind_method(D_METHOD("get_pool_size"), &PostgreAdapter::get_pool_size);
 	ADD_PROPERTY(PropertyInfo(Variant::INT, "pool_size"), "set_pool_size", "get_pool_size");
 
 	ClassDB::bind_method(D_METHOD("connect_to_db"), &PostgreAdapter::connect_to_db);
 	ClassDB::bind_method(D_METHOD("disconnect_from_db"), &PostgreAdapter::disconnect_from_db);
 	ClassDB::bind_method(D_METHOD("execute_query", "query", "params"), &PostgreAdapter::execute_query, DEFVAL(Array()));
 	ClassDB::bind_method(D_METHOD("execute_non_query", "query", "params"), &PostgreAdapter::execute_non_query, DEFVAL(Array()));
 	ClassDB::bind_method(D_METHOD("_to_string"), &PostgreAdapter::_to_string);
 	
 	// Transaction methods
 	ClassDB::bind_method(D_METHOD("begin_transaction"), &PostgreAdapter::begin_transaction);
 	ClassDB::bind_method(D_METHOD("commit_transaction"), &PostgreAdapter::commit_transaction);
 	ClassDB::bind_method(D_METHOD("rollback_transaction"), &PostgreAdapter::rollback_transaction);
 	ClassDB::bind_method(D_METHOD("execute_query_in_transaction", "query", "params"), &PostgreAdapter::execute_query_in_transaction, DEFVAL(Array()));
 	ClassDB::bind_method(D_METHOD("execute_non_query_in_transaction", "query", "params"), &PostgreAdapter::execute_non_query_in_transaction, DEFVAL(Array()));
 	
 	// Async methods
 	ClassDB::bind_method(D_METHOD("execute_query_async", "query", "params"), &PostgreAdapter::execute_query_async, DEFVAL(Array()));
 	ClassDB::bind_method(D_METHOD("execute_non_query_async", "query", "params"), &PostgreAdapter::execute_non_query_async, DEFVAL(Array()));

	// Bind signals
	ADD_SIGNAL(MethodInfo("query_failed", PropertyInfo(Variant::STRING, "query"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("non_query_failed", PropertyInfo(Variant::STRING, "query"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("connection_error", PropertyInfo(Variant::STRING, "error_message")));
	
	// Async signals
	ADD_SIGNAL(MethodInfo("query_completed", PropertyInfo(Variant::ARRAY, "results")));
	ADD_SIGNAL(MethodInfo("non_query_completed", PropertyInfo(Variant::INT, "affected_rows")));
	ADD_SIGNAL(MethodInfo("async_query_failed", PropertyInfo(Variant::STRING, "query"), PropertyInfo(Variant::STRING, "error_message")));
	
	// Transaction signals
	ADD_SIGNAL(MethodInfo("transaction_started"));
	ADD_SIGNAL(MethodInfo("transaction_committed"));
	ADD_SIGNAL(MethodInfo("transaction_rolled_back"));
	ADD_SIGNAL(MethodInfo("transaction_failed", PropertyInfo(Variant::STRING, "error_message")));
}
 
PostgreAdapter::PostgreAdapter() :
 		connection_pool(nullptr), transaction_connection(nullptr), current_transaction(nullptr), in_transaction(false) {
 	// Initialize connection_string
 	connection_string = "";
 	// Don't create connection pool with empty connection string
 }
 
void PostgreAdapter::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_POSTINITIALIZE: {
			// This is called after the object is created and initialized.
			// Good place for one-time setup that doesn't depend on being in the scene tree.
		} break;
		case NOTIFICATION_PREDELETE: {
			// This is called before the object is deleted.
			// Good place for cleanup that needs to happen before destruction.
		} break;
	}
}

PostgreAdapter::~PostgreAdapter() {
	// Clean up any active transaction
	if (current_transaction) {
		try {
			current_transaction->abort();
		} catch (...) {
			// Ignore errors during cleanup
		}
		delete current_transaction;
		current_transaction = nullptr;
	}
	
	if (transaction_connection) {
		if (connection_pool) {
			connection_pool->release(transaction_connection);
		}
		transaction_connection = nullptr;
	}
	
	if (connection_pool) {
		delete connection_pool;
		connection_pool = nullptr;
	}
}

void PostgreAdapter::_ready() {
	// Optional: Connect to DB on _ready if connection_string is already set
	if (!connection_string.is_empty()) {
		connect_to_db();
	}
}

void PostgreAdapter::_exit_tree() {
	// Connection pool cleanup handled in destructor
}

void PostgreAdapter::set_connection_string(const String &p_connection_string) {
	connection_string = p_connection_string;
	if (connection_pool) {
		delete connection_pool;
		connection_pool = nullptr;
	}
	// Create new connection pool with updated connection string
	if (!connection_string.is_empty()) {
		connection_pool = new ConnectionPool(connection_string, pool_size);
	}
}

String PostgreAdapter::get_connection_string() const {
 	return connection_string;
 }
 
void PostgreAdapter::set_pool_size(int p_pool_size) {
	if (p_pool_size > 0) {
		pool_size = p_pool_size;
		if (connection_pool) {
			// Re-initialize pool with new size if already connected
			delete connection_pool;
			connection_pool = new ConnectionPool(connection_string, pool_size);
		}
	} else {
		UtilityFunctions::print("Pool size must be greater than 0.");
	}
}
 
int PostgreAdapter::get_pool_size() const {
	return pool_size;
}

bool PostgreAdapter::connect_to_db() {
	if (!connection_pool) {
		UtilityFunctions::print("Connection pool is not initialized. Set connection_string first.");
		return false;
	}
	
	UtilityFunctions::print("Connection pool is available with connections.");
	return true;
}

void PostgreAdapter::disconnect_from_db() {
	if (connection_pool) {
		UtilityFunctions::print("Shutting down connection pool.");
		delete connection_pool;
		connection_pool = nullptr;
	} else {
		UtilityFunctions::print("No connection pool to disconnect.");
	}
}

Array PostgreAdapter::execute_query(const String &p_query, const Array& p_params /*= Array()*/) {
    Array result_array;
    UtilityFunctions::print("execute_query called with query: ", p_query);
    if (!p_params.is_empty()) {
        UtilityFunctions::print("execute_query called with params: ", p_params);
    }

    pqxx::connection* conn = connection_pool->acquire();
    if (!conn) {
        UtilityFunctions::print("Failed to acquire connection from pool.");
        return result_array;
    }

    for (int retries = 0; retries < 2; ++retries) { // Allow one retry
        UtilityFunctions::print("Attempting query, retry #", retries);
        if (!conn || !conn->is_open()) {
            UtilityFunctions::print("Connection not open for query, will need new connection.");
            // Return this connection to pool and get a new one
            if (conn) {
                connection_pool->release(conn);
            }
            conn = connection_pool->acquire();
            if (!conn) {
                UtilityFunctions::print("Failed to acquire new connection from pool.");
                return result_array;
            }
        }

        // Ensure connection is valid before proceeding with transaction/query
        ERR_FAIL_COND_V_MSG(!conn->is_open(), result_array, "PostgreSQL connection is not valid or open before executing query.");

        try {
            UtilityFunctions::print("Creating pqxx::work object for query...");
            pqxx::work W(*conn);
            UtilityFunctions::print("Executing query: ", p_query);

            pqxx::result R;
            // Bind parameters using modern API
            if (p_params.size() > 0) {
                std::vector<std::string> params_vec;
                for (int i = 0; i < p_params.size(); ++i) {
                    Variant param = p_params[i];
                    if (param.get_type() == Variant::NIL) {
                        params_vec.push_back("");  // Handle NULL values
                    } else if (param.get_type() == Variant::INT) {
                        params_vec.push_back(std::to_string(param.operator int64_t()));
                    } else if (param.get_type() == Variant::STRING) {
                        params_vec.push_back(param.operator String().utf8().get_data());
                    } else if (param.get_type() == Variant::FLOAT) {
                        params_vec.push_back(std::to_string(param.operator double()));
                    } else if (param.get_type() == Variant::BOOL) {
                        params_vec.push_back(param.operator bool() ? "true" : "false");
                    } else if (param.get_type() == Variant::VECTOR2) {
                        Vector2 v = param.operator Vector2();
                        params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + ")");
                    } else if (param.get_type() == Variant::VECTOR3) {
                        Vector3 v = param.operator Vector3();
                        params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + "," + std::to_string(v.z) + ")");
                    } else {
                        UtilityFunctions::print("Unsupported parameter type: ", param.get_type());
                        connection_pool->release(conn);
                        return result_array;
                    }
                }
                
                // Use exec_params for parameter binding
                if (params_vec.size() == 1) {
                    R = W.exec_params(p_query.utf8().get_data(), params_vec[0]);
                } else if (params_vec.size() == 2) {
                    R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1]);
                } else if (params_vec.size() == 3) {
                    R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2]);
                } else if (params_vec.size() == 4) {
                    R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3]);
                } else if (params_vec.size() == 5) {
                    R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3], params_vec[4]);
                } else {
                    UtilityFunctions::print("Error: Too many parameters (max 5 supported)");
                    return Array();
                }
            } else {
                R = W.exec(p_query.utf8().get_data());
            }
   W.commit();


            UtilityFunctions::print("Processing query results...");
            for (pqxx::row const &row : R) {
                Dictionary godot_row;
                for (pqxx::field const &field : row) {
                    godot_row[field.name()] = String(field.c_str());
                }
                result_array.append(godot_row);
            }
            UtilityFunctions::print("Query executed successfully. Rows returned: ", (int)result_array.size());
            connection_pool->release(conn);
            return result_array; // Success, exit loop
        } catch (const pqxx::broken_connection &e) {
            UtilityFunctions::print("Query execution failed (broken connection): ", e.what());
            // Connection is broken, don't return it to pool
            conn = nullptr;
            if (retries == 0) { // Only retry once
                UtilityFunctions::print("Attempting to get new connection and retry query...");
                continue; // Retry
            } else {
                UtilityFunctions::print("Failed after retry for query. Giving up.");
                return result_array;
            }
        } catch (const std::exception &e) {
            UtilityFunctions::print("Query execution failed with std::exception: ", e.what());
            connection_pool->release(conn);
            return result_array; // Other error, no retry
        } catch (...) { // Catch any other unexpected exceptions
            UtilityFunctions::print("Query execution failed with an unknown exception.");
            connection_pool->release(conn);
            return result_array;
        }
    }
    UtilityFunctions::print("Query execution loop finished without returning. This should not happen.");
    connection_pool->release(conn);
    return result_array; // Should not be reached if successful or failed after retries
}

int PostgreAdapter::execute_non_query(const String &p_query, const Array& p_params /*= Array()*/) {
	int affected_rows = -1;
	UtilityFunctions::print("execute_non_query called with query: ", p_query);
    if (!p_params.is_empty()) {
        UtilityFunctions::print("execute_non_query called with params: ", p_params);
    }

    pqxx::connection* conn = connection_pool->acquire();
    if (!conn) {
        UtilityFunctions::print("Failed to acquire connection from pool.");
        return affected_rows;
    }

	for (int retries = 0; retries < 2; ++retries) { // Allow one retry
		UtilityFunctions::print("Attempting non-query, retry #", retries);
		if (!conn || !conn->is_open()) {
			UtilityFunctions::print("Connection not open for non-query, will need new connection.");
			// Return this connection to pool and get a new one
			if (conn) {
				connection_pool->release(conn);
			}
			conn = connection_pool->acquire();
			if (!conn) {
				UtilityFunctions::print("Failed to acquire new connection from pool.");
				return -1;
			}
		}

		// Ensure connection is valid before proceeding with transaction/query
		ERR_FAIL_COND_V_MSG(!conn->is_open(), -1, "PostgreSQL connection is not valid or open before executing non-query.");

		try {
			UtilityFunctions::print("DEBUG: Before pqxx::work W(*conn);");
			pqxx::work W(*conn);
			UtilityFunctions::print("DEBUG: After pqxx::work W(*conn); Before W.exec();");
			         pqxx::result R; // Declare R here
			         if (p_params.size() > 0) {
			             std::vector<std::string> params_vec;
			             for (int i = 0; i < p_params.size(); ++i) {
			                 Variant param = p_params[i];
			                 if (param.get_type() == Variant::INT) {
			                     params_vec.push_back(std::to_string(param.operator int64_t()));
			                 } else if (param.get_type() == Variant::STRING) {
			                     params_vec.push_back(param.operator String().utf8().get_data());
			                 } else if (param.get_type() == Variant::FLOAT) {
			                     params_vec.push_back(std::to_string(param.operator double()));
			                 } else if (param.get_type() == Variant::BOOL) {
			                     params_vec.push_back(param.operator bool() ? "true" : "false");
			                 } else {
			                     UtilityFunctions::print("Unsupported parameter type for non-query: ", param.get_type());
			                     connection_pool->release(conn);
			                     return -1;
			                 }
			             }
			             // Use exec_params for parameter binding
			             if (params_vec.size() == 1) {
			                 R = W.exec_params(p_query.utf8().get_data(), params_vec[0]);
			             } else if (params_vec.size() == 2) {
			                 R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1]);
			             } else if (params_vec.size() == 3) {
			                 R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2]);
			             } else if (params_vec.size() == 4) {
			                 R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3]);
			             } else if (params_vec.size() == 5) {
			                 R = W.exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3], params_vec[4]);
			             } else {
			                 UtilityFunctions::print("Error: Too many parameters (max 5 supported)");
			                 connection_pool->release(conn);
			                 return -1;
			             }
			         } else {
			             R = W.exec(p_query.utf8().get_data());
			         }
			UtilityFunctions::print("DEBUG: After W.exec(); Before W.commit();");
			W.commit();
			UtilityFunctions::print("DEBUG: After W.commit();");
			
			// Check if this is a DDL statement that doesn't support affected_rows()
			String query_upper = p_query.to_upper().strip_edges();
			bool is_ddl = query_upper.begins_with("CREATE") ||
						  query_upper.begins_with("DROP") ||
						  query_upper.begins_with("ALTER") ||
						  query_upper.begins_with("TRUNCATE");
			
			if (is_ddl) {
				UtilityFunctions::print("DEBUG: DDL statement detected, skipping affected_rows()");
				affected_rows = 0; // DDL statements executed successfully
			} else {
				UtilityFunctions::print("DEBUG: Before R.affected_rows();");
				try {
					affected_rows = R.affected_rows();
					UtilityFunctions::print("DEBUG: After R.affected_rows(); Before final print.");
				} catch (const std::exception &e) {
					UtilityFunctions::print("DEBUG: Exception caught when calling R.affected_rows(): ", e.what());
					affected_rows = 0;
				} catch (...) {
					UtilityFunctions::print("DEBUG: Unknown exception caught when calling R.affected_rows().");
					affected_rows = 0;
				}
			}
			UtilityFunctions::print("Non-query executed successfully. Affected rows: ", affected_rows);
			UtilityFunctions::print("DEBUG: Before returning affected_rows.");
			         connection_pool->release(conn);
			return affected_rows; // Success, exit loop
		} catch (const pqxx::broken_connection &e) {
			UtilityFunctions::print("Non-query execution failed (broken connection): ", e.what());
			// Connection is broken, don't return it to pool
			conn = nullptr;
			if (retries == 0) { // Only retry once
				UtilityFunctions::print("Attempting to get new connection and retry non-query...");
				continue; // Retry
			} else {
				UtilityFunctions::print("Failed after retry for non-query. Giving up.");
				return -1;
			}
		} catch (const std::exception &e) {
			UtilityFunctions::print("Non-query execution failed with std::exception: ", e.what());
            connection_pool->release(conn);
			return -1; // Other error, no retry
		} catch (...) { // Catch any other unexpected exceptions
			UtilityFunctions::print("Non-query execution failed with an unknown exception.");
            connection_pool->release(conn);
			return -1;
		}
	}
	UtilityFunctions::print("Non-query execution loop finished without returning. This should not happen.");
    connection_pool->release(conn);
	return affected_rows; // Should not be reached if successful or failed after retries
}

String PostgreAdapter::_to_string() const {
	return String("PostgreAdapter (Pool: ") + (connection_pool ? "Available" : "Not initialized") + String(", String: '") + connection_string + String("')");
}

// Transaction support methods
bool PostgreAdapter::begin_transaction() {
	if (in_transaction) {
		UtilityFunctions::print("Transaction already in progress");
		return false;
	}
	
	if (!connection_pool) {
		UtilityFunctions::print("Connection pool not initialized");
		emit_signal("transaction_failed", "Connection pool not initialized");
		return false;
	}
	
	transaction_connection = connection_pool->acquire();
	if (!transaction_connection || !transaction_connection->is_open()) {
		UtilityFunctions::print("Failed to acquire connection for transaction");
		emit_signal("transaction_failed", "Failed to acquire connection");
		return false;
	}
	
	try {
		current_transaction = new pqxx::work(*transaction_connection);
		in_transaction = true;
		UtilityFunctions::print("Transaction started successfully");
		emit_signal("transaction_started");
		return true;
	} catch (const std::exception &e) {
		UtilityFunctions::print("Failed to start transaction: ", e.what());
		connection_pool->release(transaction_connection);
		transaction_connection = nullptr;
		emit_signal("transaction_failed", String(e.what()));
		return false;
	}
}

bool PostgreAdapter::commit_transaction() {
	if (!in_transaction || !current_transaction) {
		UtilityFunctions::print("No active transaction to commit");
		emit_signal("transaction_failed", "No active transaction");
		return false;
	}
	
	try {
		current_transaction->commit();
		delete current_transaction;
		current_transaction = nullptr;
		
		connection_pool->release(transaction_connection);
		transaction_connection = nullptr;
		
		in_transaction = false;
		UtilityFunctions::print("Transaction committed successfully");
		emit_signal("transaction_committed");
		return true;
	} catch (const std::exception &e) {
		UtilityFunctions::print("Failed to commit transaction: ", e.what());
		// Clean up failed transaction
		rollback_transaction();
		emit_signal("transaction_failed", String(e.what()));
		return false;
	}
}

bool PostgreAdapter::rollback_transaction() {
	if (!in_transaction || !current_transaction) {
		UtilityFunctions::print("No active transaction to rollback");
		return false;
	}
	
	try {
		current_transaction->abort();
		delete current_transaction;
		current_transaction = nullptr;
		
		connection_pool->release(transaction_connection);
		transaction_connection = nullptr;
		
		in_transaction = false;
		UtilityFunctions::print("Transaction rolled back successfully");
		emit_signal("transaction_rolled_back");
		return true;
	} catch (const std::exception &e) {
		UtilityFunctions::print("Error during rollback: ", e.what());
		// Force cleanup even on error
		delete current_transaction;
		current_transaction = nullptr;
		if (transaction_connection) {
			connection_pool->release(transaction_connection);
			transaction_connection = nullptr;
		}
		in_transaction = false;
		emit_signal("transaction_failed", String(e.what()));
		return false;
	}
}

Array PostgreAdapter::execute_query_in_transaction(const String &p_query, const Array& p_params) {
	Array result_array;
	
	if (!in_transaction || !current_transaction) {
		UtilityFunctions::print("No active transaction");
		emit_signal("query_failed", p_query, "No active transaction");
		return result_array;
	}
	
	try {
		pqxx::result R;
		
		// Handle parameters
		if (p_params.size() > 0) {
			std::vector<std::string> params_vec;
			for (int i = 0; i < p_params.size(); ++i) {
				Variant param = p_params[i];
				if (param.get_type() == Variant::NIL) {
					params_vec.push_back("");
				} else if (param.get_type() == Variant::INT) {
					params_vec.push_back(std::to_string(param.operator int64_t()));
				} else if (param.get_type() == Variant::STRING) {
					params_vec.push_back(param.operator String().utf8().get_data());
				} else if (param.get_type() == Variant::FLOAT) {
					params_vec.push_back(std::to_string(param.operator double()));
				} else if (param.get_type() == Variant::BOOL) {
					params_vec.push_back(param.operator bool() ? "true" : "false");
				} else if (param.get_type() == Variant::VECTOR2) {
					Vector2 v = param.operator Vector2();
					params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + ")");
				} else if (param.get_type() == Variant::VECTOR3) {
					Vector3 v = param.operator Vector3();
					params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + "," + std::to_string(v.z) + ")");
				}
			}
			// Use exec_params for parameter binding
			if (params_vec.size() == 1) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0]);
			} else if (params_vec.size() == 2) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1]);
			} else if (params_vec.size() == 3) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2]);
			} else if (params_vec.size() == 4) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3]);
			} else if (params_vec.size() == 5) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3], params_vec[4]);
			} else {
				UtilityFunctions::print("Error: Too many parameters (max 5 supported)");
				return Array();
			}
		} else {
			R = current_transaction->exec(p_query.utf8().get_data());
		}
		
		// Process results
		for (pqxx::row const &row : R) {
			Dictionary godot_row;
			for (pqxx::field const &field : row) {
				godot_row[field.name()] = String(field.c_str());
			}
			result_array.append(godot_row);
		}
		
		UtilityFunctions::print("Query in transaction executed successfully. Rows returned: ", (int)result_array.size());
		return result_array;
		
	} catch (const std::exception &e) {
		UtilityFunctions::print("Query in transaction failed: ", e.what());
		emit_signal("query_failed", p_query, String(e.what()));
		return result_array;
	}
}

int PostgreAdapter::execute_non_query_in_transaction(const String &p_query, const Array& p_params) {
	if (!in_transaction || !current_transaction) {
		UtilityFunctions::print("No active transaction");
		emit_signal("non_query_failed", p_query, "No active transaction");
		return -1;
	}
	
	try {
		pqxx::result R;
		
		// Handle parameters
		if (p_params.size() > 0) {
			std::vector<std::string> params_vec;
			for (int i = 0; i < p_params.size(); ++i) {
				Variant param = p_params[i];
				if (param.get_type() == Variant::NIL) {
					params_vec.push_back("");
				} else if (param.get_type() == Variant::INT) {
					params_vec.push_back(std::to_string(param.operator int64_t()));
				} else if (param.get_type() == Variant::STRING) {
					params_vec.push_back(param.operator String().utf8().get_data());
				} else if (param.get_type() == Variant::FLOAT) {
					params_vec.push_back(std::to_string(param.operator double()));
				} else if (param.get_type() == Variant::BOOL) {
					params_vec.push_back(param.operator bool() ? "true" : "false");
				} else if (param.get_type() == Variant::VECTOR2) {
					Vector2 v = param.operator Vector2();
					params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + ")");
				} else if (param.get_type() == Variant::VECTOR3) {
					Vector3 v = param.operator Vector3();
					params_vec.push_back("(" + std::to_string(v.x) + "," + std::to_string(v.y) + "," + std::to_string(v.z) + ")");
				}
			}
			// Use exec_params for parameter binding
			if (params_vec.size() == 1) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0]);
			} else if (params_vec.size() == 2) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1]);
			} else if (params_vec.size() == 3) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2]);
			} else if (params_vec.size() == 4) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3]);
			} else if (params_vec.size() == 5) {
				R = current_transaction->exec_params(p_query.utf8().get_data(), params_vec[0], params_vec[1], params_vec[2], params_vec[3], params_vec[4]);
			} else {
				UtilityFunctions::print("Error: Too many parameters (max 5 supported)");
				return -1;
			}
		} else {
			R = current_transaction->exec(p_query.utf8().get_data());
		}
		
		// Check affected rows
		String query_upper = p_query.to_upper().strip_edges();
		bool is_ddl = query_upper.begins_with("CREATE") ||
					  query_upper.begins_with("DROP") ||
					  query_upper.begins_with("ALTER") ||
					  query_upper.begins_with("TRUNCATE");
		
		int affected_rows = is_ddl ? 0 : R.affected_rows();
		UtilityFunctions::print("Non-query in transaction executed successfully. Affected rows: ", affected_rows);
		return affected_rows;
		
	} catch (const std::exception &e) {
		UtilityFunctions::print("Non-query in transaction failed: ", e.what());
		emit_signal("non_query_failed", p_query, String(e.what()));
		return -1;
	}
}

// Async query methods (using call_deferred for simplicity)
void PostgreAdapter::execute_query_async(const String &p_query, const Array& p_params) {
	// For now, we'll execute synchronously and emit the signal
	// In a real async implementation, you'd use threading or Godot's WorkerThreadPool
	Array result = execute_query(p_query, p_params);
	if (result.size() >= 0) {  // Even empty results are successful
		call_deferred("emit_signal", "query_completed", result);
	} else {
		call_deferred("emit_signal", "async_query_failed", p_query, "Query execution failed");
	}
}

void PostgreAdapter::execute_non_query_async(const String &p_query, const Array& p_params) {
	// For now, we'll execute synchronously and emit the signal
	// In a real async implementation, you'd use threading or Godot's WorkerThreadPool
	int result = execute_non_query(p_query, p_params);
	if (result >= 0) {
		call_deferred("emit_signal", "non_query_completed", result);
	} else {
		call_deferred("emit_signal", "async_query_failed", p_query, "Non-query execution failed");
	}
}