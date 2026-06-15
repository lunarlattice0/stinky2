package body Stinky2
   with SPARK_Mode => On
is

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
