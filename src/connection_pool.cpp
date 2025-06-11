#include <godot_cpp/variant/string.hpp>
#include "connection_pool.h"
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

ConnectionPool::ConnectionPool(const String& p_connection_string, int p_pool_size) :
    connection_string(p_connection_string),
    pool_size(p_pool_size) {

    UtilityFunctions::print("Initializing connection pool with size: ", pool_size);
    for (int i = 0; i < pool_size; ++i) {
        try {
            pqxx::connection* conn = new pqxx::connection(connection_string.utf8().get_data());
            if (conn->is_open()) {
                connections.push(conn);
                UtilityFunctions::print("Connection created and added to pool.");
            } else {
                UtilityFunctions::print("Failed to create connection.");
                delete conn;
            }
        } catch (const std::exception& e) {
            UtilityFunctions::print("Exception creating connection: ", e.what());
        }
    }
    UtilityFunctions::print("Connection pool initialized.");
}

ConnectionPool::~ConnectionPool() {
    shutdown();
}

pqxx::connection* ConnectionPool::acquire() {
    std::unique_lock<std::mutex> lock(mutex);
    condition.wait(lock, [this]{ return !connections.empty() || shutting_down; });
    if (shutting_down && connections.empty()) {
        return nullptr;
    }
    pqxx::connection* conn = connections.front();
    connections.pop();
    UtilityFunctions::print("Connection acquired from pool. Pool size: ", (int)connections.size());
    return conn;
}

void ConnectionPool::release(pqxx::connection* connection) {
    std::lock_guard<std::mutex> lock(mutex);
    connections.push(connection);
    UtilityFunctions::print("Connection released to pool. Pool size: ", (int)connections.size());
    condition.notify_one();
}

void ConnectionPool::shutdown() {
    UtilityFunctions::print("Shutting down connection pool.");
    shutting_down = true;
    condition.notify_all();
    std::lock_guard<std::mutex> lock(mutex);
    while (!connections.empty()) {
        pqxx::connection* conn = connections.front();
        connections.pop();
        if (conn) {
            UtilityFunctions::print("Deleting connection.");
            delete conn;
        }
    }
    UtilityFunctions::print("Connection pool shut down.");
}

}