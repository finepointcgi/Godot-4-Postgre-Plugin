#ifndef POSTGRE_ADAPTER_H
#define POSTGRE_ADAPTER_H

#include <godot_cpp/classes/node.hpp>
#include <pqxx/pqxx> // Include pqxx for connection object

namespace godot {

class PostgreAdapter : public Node {
 	GDCLASS(PostgreAdapter, Node)
 
private:
 	String connection_string;
 	pqxx::connection *conn; // Pointer to pqxx connection object
 
protected:
 	static void _bind_methods();
 
public:
 	PostgreAdapter();
 	~PostgreAdapter();
 
 	void _ready() override;
 	void _exit_tree() override;
 
 	void set_connection_string(const String &p_connection_string);
 	String get_connection_string() const;
	String _to_string() const;
 	bool connect_to_db();
 	void disconnect_from_db();
 
 	Array execute_query(const String &p_query);
 	int execute_non_query(const String &p_query);
};

}

#endif