#ifndef CONNECTION_POOL_H
#define CONNECTION_POOL_H

#include "godot_cpp/variant/string.hpp"
#include <pqxx/pqxx>
#include <queue>
#include <mutex>
#include <condition_variable>

namespace godot {

class ConnectionPool {
private:
    String connection_string;
    int pool_size;
    std::queue<pqxx::connection*> connections;
    std::mutex mutex;
    std::condition_variable condition;
    bool shutting_down = false;

public:
    ConnectionPool(const String& p_connection_string, int p_pool_size);
    ~ConnectionPool();

    pqxx::connection* acquire();
    void release(pqxx::connection* connection);

    void shutdown();
};

}

#endif