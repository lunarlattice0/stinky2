#include <stdio.h>
#include <signal.h>
#include <enet/enet.h>

static volatile int running = 1;

void sigint_handler(int sig) {
    (void)sig;
    running = 0;
}

int main(int argc, char **argv) {
    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    const char *host = "127.0.0.1";
    unsigned short port = 6969;

    if (argc >= 2) host = argv[1];
    if (argc >= 3) port = (unsigned short)atoi(argv[2]);

    if (enet_initialize() != 0) {
        fprintf(stderr, "Could not initialize ENet\n");
        return 1;
    }
    printf("ENet initialized.\n");

    ENetAddress address;
    enet_address_set_host(&address, host);
    address.port = port;

    ENetHost *client = enet_host_create(NULL, 1, 2, 0, 0);
    if (client == NULL) {
        fprintf(stderr, "Could not create client\n");
        enet_deinitialize();
        return 1;
    }

    ENetPeer *peer = enet_host_connect(client, &address, 2, 0);
    if (peer == NULL) {
        fprintf(stderr, "No available peers for connecting to %s:%u\n", host, port);
        enet_host_destroy(client);
        enet_deinitialize();
        return 1;
    }

    /* Wait for connection to succeed */
    ENetEvent event;
    if (enet_host_service(client, &event, 3000) > 0 &&
        event.type == ENET_EVENT_TYPE_CONNECT) {
        printf("Connected to %s:%u\n", host, port);
    } else {
        printf("Failed to connect to %s:%u\n", host, port);
        enet_peer_reset(peer);
        enet_host_destroy(client);
        enet_deinitialize();
        return 1;
    }

    /* Stay connected until Ctrl-C */
    while (running) {
        if (enet_host_service(client, &event, 500) > 0) {
            switch (event.type) {
                case ENET_EVENT_TYPE_DISCONNECT:
                    printf("Disconnected from server.\n");
                    running = 0;
                    break;
                case ENET_EVENT_TYPE_RECEIVE:
                    printf("Received %lu bytes\n", event.packet->dataLength);
                    enet_packet_destroy(event.packet);
                    break;
                default:
                    break;
            }
        }
    }

    printf("Disconnecting...\n");
    enet_peer_disconnect(peer, 0);
    enet_host_service(client, &event, 1000);

    enet_host_destroy(client);
    enet_deinitialize();
    printf("Done.\n");
    return 0;
}
