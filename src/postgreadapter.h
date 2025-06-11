#ifndef POSTGRE_ADAPTER_H
#define POSTGRE_ADAPTER_H

#include <godot_cpp/classes/node.hpp>
#include <pqxx/pqxx> // Include pqxx for connection object
#include "connection_pool.h"

namespace godot {

class PostgreAdapter : public Node {
 	GDCLASS(PostgreAdapter, Node)
 
private:
 	String connection_string;
	ConnectionPool* connection_pool;
	int pool_size = 4;
	
	// Transaction state
	pqxx::connection* transaction_connection;
	pqxx::work* current_transaction;
	bool in_transaction;
	
protected:
		static void _bind_methods();
	
public:
		PostgreAdapter();
		~PostgreAdapter();
	
		void _ready() override;
		void _exit_tree() override;
		void _notification(int p_what);
	
		void set_connection_string(const String &p_connection_string);
		String get_connection_string() const;
	void set_pool_size(int p_pool_size);
	int get_pool_size() const;
	String _to_string() const;
		bool connect_to_db();
		void disconnect_from_db();
	
		Array execute_query(const String &p_query, const Array& p_params = Array());
		int execute_non_query(const String &p_query, const Array& p_params = Array());
		
		// Transaction support
		bool begin_transaction();
		bool commit_transaction();
		bool rollback_transaction();
		Array execute_query_in_transaction(const String &p_query, const Array& p_params = Array());
		int execute_non_query_in_transaction(const String &p_query, const Array& p_params = Array());
		
		// Async query support
		void execute_query_async(const String &p_query, const Array& p_params = Array());
		void execute_non_query_async(const String &p_query, const Array& p_params = Array());

	// Signals for error reporting
	void _query_failed(const String &p_query, const String &p_error_message);
	void _non_query_failed(const String &p_query, const String &p_error_message);
	void _connection_error(const String &p_error_message);
};

}

#endif