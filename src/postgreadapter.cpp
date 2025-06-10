#include "postgreadapter.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <pqxx/pqxx> // For PostgreSQL interaction

using namespace godot;

void PostgreAdapter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_connection_string", "connection_string"), &PostgreAdapter::set_connection_string);
	ClassDB::bind_method(D_METHOD("get_connection_string"), &PostgreAdapter::get_connection_string);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "connection_string"), "set_connection_string", "get_connection_string");

	ClassDB::bind_method(D_METHOD("connect_to_db"), &PostgreAdapter::connect_to_db);
	ClassDB::bind_method(D_METHOD("disconnect_from_db"), &PostgreAdapter::disconnect_from_db);
	ClassDB::bind_method(D_METHOD("execute_query", "query"), &PostgreAdapter::execute_query);
	ClassDB::bind_method(D_METHOD("execute_non_query", "query"), &PostgreAdapter::execute_non_query);
	ClassDB::bind_method(D_METHOD("_to_string"), &PostgreAdapter::_to_string);
}

PostgreAdapter::PostgreAdapter() :
		conn(nullptr) {
	// Initialize connection_string
	connection_string = "";
}

PostgreAdapter::~PostgreAdapter() {
	disconnect_from_db();
}

void PostgreAdapter::_ready() {
	// Optional: Connect to DB on _ready if connection_string is already set
	if (!connection_string.is_empty()) {
		connect_to_db();
	}
}

void PostgreAdapter::_exit_tree() {
	disconnect_from_db();
}

void PostgreAdapter::set_connection_string(const String &p_connection_string) {
	connection_string = p_connection_string;
}

String PostgreAdapter::get_connection_string() const {
	return connection_string;
}

bool PostgreAdapter::connect_to_db() {
	if (conn && conn->is_open()) {
		UtilityFunctions::print("Already connected to PostgreSQL and connection is open.");
		return true;
	}

	// If conn exists but is not open, or if it's a stale pointer, clean it up.
	if (conn) {
		delete conn;
		conn = nullptr;
	}
	try {
		UtilityFunctions::print("Attempting to connect to PostgreSQL with: ", connection_string);
		conn = new pqxx::connection(connection_string.utf8().get_data());
		if (conn->is_open()) {
			UtilityFunctions::print("Successfully connected to PostgreSQL.");
			return true;
		} else {
			UtilityFunctions::print("Failed to connect to PostgreSQL: Connection not open.");
			delete conn;
			conn = nullptr;
			return false;
		}
	} catch (const pqxx::broken_connection &e) {
		UtilityFunctions::print("Failed to connect to PostgreSQL (broken connection): ", e.what());
		if (conn) {
			delete conn;
			conn = nullptr;
		}
		return false;
	} catch (const std::exception &e) {
		UtilityFunctions::print("Failed to connect to PostgreSQL: ", e.what());
		if (conn) {
			delete conn;
			conn = nullptr;
		}
		return false;
	}
}

void PostgreAdapter::disconnect_from_db() {
	if (conn) {
		UtilityFunctions::print("Disconnecting from PostgreSQL.");
		delete conn;
		conn = nullptr;
	} else {
		UtilityFunctions::print("Not connected to PostgreSQL.");
	}
}

Array PostgreAdapter::execute_query(const String &p_query) {
	Array result_array;
	UtilityFunctions::print("execute_query called with query: ", p_query);

	for (int retries = 0; retries < 2; ++retries) { // Allow one retry
		UtilityFunctions::print("Attempting query, retry #", retries);
		if (!conn || !conn->is_open()) {
			UtilityFunctions::print("Connection not open for query. Attempting to reconnect...");
			if (!connect_to_db()) {
				UtilityFunctions::print("Failed to reconnect to PostgreSQL for query. Cannot execute.");
				return result_array;
			}
			UtilityFunctions::print("Reconnection successful for query.");
		}

		// Ensure connection is valid before proceeding with transaction/query
		ERR_FAIL_COND_V_MSG(!conn || !conn->is_open(), result_array, "PostgreSQL connection is not valid or open before executing query.");

		try {
			UtilityFunctions::print("Creating pqxx::nontransaction object for query...");
			pqxx::nontransaction T(*conn);
			UtilityFunctions::print("Executing query: ", p_query);
			pqxx::result R = T.exec(p_query.utf8().get_data());

			UtilityFunctions::print("Processing query results...");
			for (pqxx::row const &row : R) {
				Dictionary godot_row;
				for (pqxx::field const &field : row) {
					godot_row[field.name()] = String(field.c_str());
				}
				result_array.append(godot_row);
			}
			UtilityFunctions::print("Query executed successfully. Rows returned: ", result_array.size());
			return result_array; // Success, exit loop
		} catch (const pqxx::broken_connection &e) {
			UtilityFunctions::print("Query execution failed (broken connection): ", e.what());
			// Connection is broken, clean up and try to reconnect on next loop iteration
			if (conn) {
				delete conn;
				conn = nullptr;
			}
			if (retries == 0) { // Only retry once
				UtilityFunctions::print("Attempting to re-establish connection and retry query...");
				continue; // Retry
			} else {
				UtilityFunctions::print("Failed to re-establish connection after retry for query. Giving up.");
				return result_array;
			}
		} catch (const std::exception &e) {
			UtilityFunctions::print("Query execution failed with std::exception: ", e.what());
			return result_array; // Other error, no retry
		} catch (...) { // Catch any other unexpected exceptions
			UtilityFunctions::print("Query execution failed with an unknown exception.");
			return result_array;
		}
	}
	UtilityFunctions::print("Query execution loop finished without returning. This should not happen.");
	return result_array; // Should not be reached if successful or failed after retries
}

int PostgreAdapter::execute_non_query(const String &p_query) {
	int affected_rows = -1;
	UtilityFunctions::print("execute_non_query called with query: ", p_query);

	for (int retries = 0; retries < 2; ++retries) { // Allow one retry
		UtilityFunctions::print("Attempting non-query, retry #", retries);
		if (!conn || !conn->is_open()) {
			UtilityFunctions::print("Connection not open for non-query. Attempting to reconnect...");
			if (!connect_to_db()) {
				UtilityFunctions::print("Failed to reconnect to PostgreSQL for non-query. Cannot execute.");
				return -1;
			}
			UtilityFunctions::print("Reconnection successful for non-query.");
		}

		// Ensure connection is valid before proceeding with transaction/query
		ERR_FAIL_COND_V_MSG(!conn || !conn->is_open(), -1, "PostgreSQL connection is not valid or open before executing non-query.");

		try {
			UtilityFunctions::print("DEBUG: Before pqxx::work W(*conn);");
			pqxx::work W(*conn);
			UtilityFunctions::print("DEBUG: After pqxx::work W(*conn); Before W.exec();");
			pqxx::result R = W.exec(p_query.utf8().get_data());
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
			return affected_rows; // Success, exit loop
		} catch (const pqxx::broken_connection &e) {
			UtilityFunctions::print("Non-query execution failed (broken connection): ", e.what());
			// Connection is broken, clean up and try to reconnect on next loop iteration
			if (conn) {
				delete conn;
				conn = nullptr;
			}
			if (retries == 0) { // Only retry once
				UtilityFunctions::print("Attempting to re-establish connection and retry non-query...");
				continue; // Retry
			} else {
				UtilityFunctions::print("Failed to re-establish connection after retry for non-query. Giving up.");
				return -1;
			}
		} catch (const std::exception &e) {
			UtilityFunctions::print("Non-query execution failed with std::exception: ", e.what());
			return -1; // Other error, no retry
		} catch (...) { // Catch any other unexpected exceptions
			UtilityFunctions::print("Non-query execution failed with an unknown exception.");
			return -1;
		}
	}
	UtilityFunctions::print("Non-query execution loop finished without returning. This should not happen.");
	return affected_rows; // Should not be reached if successful or failed after retries
}

String PostgreAdapter::_to_string() const {
	return String("PostgreAdapter (Connection: ") + (conn && conn->is_open() ? "Open" : "Closed") + String(", String: '") + connection_string + String("')");
}