#include <stdio.h>
#include <signal.h>
#include <enet/enet.h>

static volatile int running = 1;

void sigint_handler(int sig) {
    (void)sig;
    running = 0;
}

int main(void) {
    /* Install signal handler for graceful shutdown */
    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    /* Initialize ENet */
    if (enet_initialize() != 0) {
        fprintf(stderr, "Could not initialize ENet\n");
        return 1;
    }
    printf("ENet initialized.\n");

    ENetAddress address;
    enet_address_set_host(&address, "0.0.0.0");
    address.port = 6969;

    ENetHost *server = enet_host_create(&address, 32, 2, 0, 0);
    if (server == NULL) {
        fprintf(stderr, "Could not create server on port 6969\n");
        enet_deinitialize();
        return 1;
    }
    printf("Server listening on 0.0.0.0:6969\n");

    /* Main loop: keep running until Ctrl-C */
    while (running) {
        ENetEvent event;
        if (enet_host_service(server, &event, 100) > 0) {
            switch (event.type) {
                case ENET_EVENT_TYPE_CONNECT:
                    printf("Client connected (%s)\n",
                           event.peer->address.host);
                    break;
                case ENET_EVENT_TYPE_DISCONNECT:
                    printf("Client disconnected (%s)\n",
                           event.peer->address.host);
                    break;
                case ENET_EVENT_TYPE_RECEIVE:
                    printf("Received %lu bytes from (%s)\n",
                           event.packet->dataLength,
                           event.peer->address.host);
                    enet_packet_destroy(event.packet);
                    break;
                default:
                    break;
            }
        }
    }

    printf("Shutting down...\n");
    enet_host_destroy(server);
    enet_deinitialize();
    printf("Done.\n");
    return 0;
}
