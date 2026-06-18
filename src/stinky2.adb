with Ada.Text_IO; use Ada.Text_IO;

package body Stinky2
   with SPARK_Mode => On
is
    function Receive (host : ENetHostPtr) return FnResult is
        event   :
           aliased ENetEvent; -- unsure if aliased is necessary...C may behave wrong if it's in a register..?
        timeout : constant enet_uint32 := 0;
    begin
        while (enet_host_service (host, event, timeout) > 0) loop
            case event.event is
                when ENET_EVENT_TYPE_CONNECT    =>
                    Put_Line ("Connect success");
                    -- Send off our public key to the client and await public key to complete keyexchange
                    declare
                        packet        : ENetPacketPtr;
                        flags         : constant ENetPacketFlag :=
                           ENET_PACKET_FLAG_RELIABLE;
                        hostPubkeyAdr : constant System.Address :=
                           Stinky2.HostPubkey'Address;
                    begin
                        -- TODO: write a working packet_create func.
                        packet :=
                           enet_packet_create
                              (hostPubkeyAdr, Stinky2.publicKey_size, flags);

                        if enet_peer_send (event.peer, 0, packet.all) = 0 then
                            return Success;
                        else
                            return Fail;
                        end if;
                    end UnsafePublicKeySend;

                when ENET_EVENT_TYPE_RECEIVE    =>
                    Put_Line ("Received some shit");

                when ENET_EVENT_TYPE_DISCONNECT =>
                    Put_Line ("disconnect success");

                when ENET_EVENT_TYPE_NONE       =>
                    Put_Line ("nothing happened");
            end case;
        end loop;
        return Success;
    end Receive;

    procedure DestroyHost (hostPtr : in out ENetHostPtr) is
    begin
        enet_host_destroy (hostPtr);
        hostPtr := ENetHostPtr (System.Null_Address);
    end DestroyHost;

    function IPToAddress
       (address : in out ENetAddress; ip : in String) return FnResult is
    begin
        -- This MAY be unsafe if it goes out of scope...?
        -- Silence compiler warning
        address.host := 0;

        if enet_address_set_host_ip
              (address, Interfaces.C.To_C (ip, Append_Nul => True))
           /= 0
        then
            return Fail;
        end if;

        return Success;
    end IPToAddress;

    -- TODO: Bandwidth is asymmetric...
    function StartHost
       (listen    : Boolean;
        hostPtr   : out ENetHostPtr;
        address   : ENetAddress;
        clients   : ClientsCount;
        channels  : ChannelsCount;
        bandwidth : BandwidthCount) return FnResult is

    begin
        if listen then
            hostPtr :=
               enet_host_create_listen
                  (address, clients, channels, bandwidth, bandwidth);
        else
            hostPtr :=
               enet_host_create_nolisten
                  (null, clients, channels, bandwidth, bandwidth);
        end if;
        if hostPtr = ENetHostPtr (System.Null_Address) then
            return Fail;
        end if;
        return Success;
    end StartHost;

    function Connect
       (peer         : out ENetPeerPtr;
        host         : ENetHostPtr;
        address      : ENetAddress;
        channelCount : ChannelsCount;
        data         : enet_uint32) return FnResult is

    begin
        -- Need to handle retrySafe? Please investigate.
        peer := enet_host_connect (host, address, channelCount, data);
        if (peer = ENetPeerPtr (System.Null_Address)) then
            return Fail;
        end if;
        return Success;

    end Connect;

    procedure Deinit is

    begin
        enet_deinitialize;
    end Deinit;

    function Init return FnResult is

        sodium_init_result : int;
        enet_init_result   : int;
    begin
        -- Initialize crypto and enet subsystems
        sodium_init_result := sodium_init;
        enet_init_result := enet_initialize;

        if not (sodium_init_result = 0 and enet_init_result = 0) then
            return Fail;
        end if;

        if not (crypto_kx_keypair (HostPubkey, HostSecretKey) = 0) then
            return Fail;
        end if;

        return Success;
    end Init;
end Stinky2;
