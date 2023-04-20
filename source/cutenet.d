/*
 * zlib License
 * 
 * (C) 2032 XXIV
 * 
 * This software is provided *as-is*, without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module cutenet;

extern (C):

struct cn_client_t;
struct cn_server_t;

struct cn_crypto_key_t
{
    ubyte[32] key;
}

struct cn_crypto_sign_public_t
{
    ubyte[32] key;
}

struct cn_crypto_sign_secret_t
{
    ubyte[64] key;
}

struct cn_crypto_signature_t
{
    ubyte[64] bytes;
}

enum cn_address_type_t
{
    NONE = 0,
    IPV4 = 1,
    IPV6 = 2
}

struct cn_endpoint_t
{
    cn_address_type_t type;
    ushort port;

    union cn_endpoint_u_t
    {
        ubyte[4] ipv4;
        ushort[8] ipv6;
    }

    cn_endpoint_u_t u;
}

enum cn_client_state_t
{
    CONNECT_TOKEN_EXPIRED = -6,
    INVALID_CONNECT_TOKEN = -5,
    CONNECTION_TIMED_OUT = -4,
    CHALLENGE_RESPONSE_TIMED_OUT = -3,
    CONNECTION_REQUEST_TIMED_OUT = -2,
    CONNECTION_DENIED = -1,
    DISCONNECTED = 0,
    SENDING_CONNECTION_REQUEST = 1,
    SENDING_CHALLENGE_RESPONSE = 2,
    CONNECTED = 3
}

struct cn_server_config_t
{
    ulong application_id;
    int max_incoming_bytes_per_second;
    int max_outgoing_bytes_per_second;
    int connection_timeout;
    double resend_rate;
    cn_crypto_sign_public_t public_key;
    cn_crypto_sign_secret_t secret_key;
    void* user_allocator_context;
}

enum cn_server_event_type_t
{
    NEW_CONNECTION = 0,
    DISCONNECTED = 1,
    PAYLOAD_PACKET = 2
}

struct cn_server_event_t
{
    cn_server_event_type_t type;
    union cn_server_event_u_t
    {
        struct cn_server_event_new_connection_t
        {
            int client_index;
            ulong client_id;
            cn_endpoint_t endpoint;
        }

        cn_server_event_new_connection_t new_connection;

        struct cn_server_event_disconnected_t
        {
            int client_index;
        }

        cn_server_event_disconnected_t disconnected;

        struct cn_server_event_payload_packet_t
        {
            int client_index;
            void* data;
            int size;
        }

        cn_server_event_payload_packet_t payload_packet;
    }

    cn_server_event_u_t u;
}

struct cn_result_t
{
    int code;
    const(char)* details;
}

int cn_endpoint_init (cn_endpoint_t* endpoint, const(char)* address_and_port_string);
void cn_endpoint_to_string (cn_endpoint_t endpoint, char* buffer, int buffer_size);
int cn_endpoint_equals (cn_endpoint_t a, cn_endpoint_t b);
cn_crypto_key_t cn_crypto_generate_key ();
void cn_crypto_random_bytes (void* data, int byte_count);
void cn_crypto_sign_keygen (cn_crypto_sign_public_t* public_key, cn_crypto_sign_secret_t* secret_key);
cn_result_t cn_generate_connect_token (
    ulong application_id,
    ulong creation_timestamp,
    const(cn_crypto_key_t)* client_to_server_key,
    const(cn_crypto_key_t)* server_to_client_key,
    ulong expiration_timestamp,
    uint handshake_timeout,
    int address_count,
    const(char*)* address_list,
    ulong client_id,
    const(ubyte)* user_data,
    const(cn_crypto_sign_secret_t)* shared_secret_key,
    ubyte* token_ptr_out);
cn_client_t* cn_client_create (
    ushort port,
    ulong application_id,
    bool use_ipv6,
    void* user_allocator_context);
void cn_client_destroy (cn_client_t* client);
cn_result_t cn_client_connect (cn_client_t* client, const(ubyte)* connect_token);
void cn_client_disconnect (cn_client_t* client);
void cn_client_update (cn_client_t* client, double dt, ulong current_time);
bool cn_client_pop_packet (cn_client_t* client, void** packet, int* size, bool* was_sent_reliably);
void cn_client_free_packet (cn_client_t* client, void* packet);
cn_result_t cn_client_send (cn_client_t* client, const(void)* packet, int size, bool send_reliably);
cn_client_state_t cn_client_state_get (const(cn_client_t)* client);
const(char)* cn_client_state_string (cn_client_state_t state);
void cn_client_enable_network_simulator (cn_client_t* client, double latency, double jitter, double drop_chance, double duplicate_chance);
float cn_client_get_packet_loss_estimate (cn_client_t* client);
float cn_client_get_rtt_estimate (cn_client_t* client);
float cn_client_get_incoming_kbps_estimate (cn_client_t* client);
float cn_client_get_outgoing_kbps_estimate (cn_client_t* client);
cn_server_config_t cn_server_config_defaults ();
cn_server_t* cn_server_create (cn_server_config_t config);
void cn_server_destroy (cn_server_t* server);
cn_result_t cn_server_start (cn_server_t* server, const(char)* address_and_port);
void cn_server_stop (cn_server_t* server);
bool cn_server_pop_event (cn_server_t* server, cn_server_event_t* event);
void cn_server_free_packet (cn_server_t* server, int client_index, void* data);
void cn_server_update (cn_server_t* server, double dt, ulong current_time);
void cn_server_disconnect_client (cn_server_t* server, int client_index, bool notify_client);
cn_result_t cn_server_send (cn_server_t* server, const(void)* packet, int size, int client_index, bool send_reliably);
bool cn_server_is_client_connected (cn_server_t* server, int client_index);
void cn_server_set_public_ip (cn_server_t* server, const(char)* address_and_port);
void cn_server_enable_network_simulator (cn_server_t* server, double latency, double jitter, double drop_chance, double duplicate_chance);
float cn_server_get_packet_loss_estimate (cn_server_t* server, int client_index);
float cn_server_get_rtt_estimate (cn_server_t* server, int client_index);
float cn_server_get_incoming_kbps_estimate (cn_server_t* server, int client_index);
float cn_server_get_outgoing_kbps_estimate (cn_server_t* server, int client_index);
bool cn_is_error (cn_result_t result);
cn_result_t cn_error_failure (const(char)* details);
cn_result_t cn_error_success ();
