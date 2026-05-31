
with Interfaces.C.Strings; use Interfaces.C.Strings;

package body Stinky2
   with SPARK_Mode => On
is


    procedure DestroyHost
    (hostPtr : in out ENetHostPtr)
    is
        procedure enet_host_destroy(host : ENetHostPtr)
        with Import=>True, Convention => C, Global => null, Always_Terminates;
    begin
        enet_host_destroy(hostPtr);
        hostPtr := ENetHostPtr(System.Null_Address);
    end DestroyHost;

    function IPToAddress(address : in out ENetAddress; ip : in String) return FnResult
    with SPARK_Mode => Off
    is
        function enet_address_set_host_ip(address : ENetAddress; ip : Interfaces.C.Strings.chars_ptr)
        return Interfaces.C.int
        with Import => True, Convention => C, Global => null;
        c_str : Interfaces.C.Strings.chars_ptr;
    begin
        -- Silence compiler warning
        address.host := 0;

        c_str := Interfaces.C.Strings.New_String(ip);

        if enet_address_set_host_ip(address, c_str) /= 0 then
            return Fail;
        end if;

        -- Violation of Spark...haha we're gonna ignore this
        Interfaces.C.Strings.Free(c_str);

        return Success;
    end IPToAddress;

    function StartHost
        (
        listen : Boolean;
        hostPtr : out ENetHostPtr;
        address   : ENetAddress;
        clients   : ClientsCount;
        channels  : ChannelsCount;
        bandwidth : BandwidthCount) return FnResult
    is
        -- Technically, this should return an ENetHost *, but we don't really use it...so it's a void *.
        function enet_host_create_listen(address : ENetAddress; clients : ClientsCount; channels : ChannelsCount; bandwidth : BandwidthCount)
        return ENetHostPtr
        with Import => True, Convention => C, Global => null, External_Name => "enet_host_create";

        function enet_host_create_nolisten(address : ENetAddressAccess; clients : ClientsCount; channels : ChannelsCount; bandwidth : BandwidthCount)
        return ENetHostPtr
        with Import => True, Convention => C, Global => null, External_Name => "enet_host_create";
    begin
        if listen then
            hostPtr := enet_host_create_listen (address, clients, channels, bandwidth);
        else
            hostPtr := enet_host_create_nolisten (null, clients, channels, bandwidth);
        end if;
        if hostPtr = ENetHostPtr(System.Null_Address) then
            return Fail;
        end if;
        return Success;
    end StartHost;

    function Connect (
        peer : out ENetPeerPtr;
        host : ENetHostPtr;
        address : ENetAddress;
        channelCount : ChannelsCount;
        data : enet_uint32
    ) return FnResult
    is
        -- stubbed impl
        function enet_host_connect(
        host : ENetHostPtr;
        address : ENetAddress;
        channelCount : ChannelsCount;
        data : enet_uint32
        )
        return ENetPeerPtr
        with Import => True, Convention => C, Global => null;

    begin
        -- Need to handle retrySafe? Please investigate.
        peer := enet_host_connect(host, address, channelCount, data);
        if (peer = ENetPeerPtr(System.Null_Address)) then
            return Fail;
        end if;
        return Success;

    end Connect;

    procedure Deinit is
        procedure enet_deinitialize
        with Import => True, Convention => C, Global => null, Always_Terminates;
    begin
        enet_deinitialize;
    end Deinit;


    function Init return FnResult is
        -- Initialize subsystems
        function sodium_init return int
        with Import => True, Convention => C, Global => null;
        function enet_initialize return int
        with Import => True, Convention => C, Global => null;

        -- generate cryptokeypairs
        function crypto_kx_keypair (pk : PublicKey; sk : SecretKey) return int
        with Import => True, Convention => C, Global => null;

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
