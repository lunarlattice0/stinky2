-- Please note: Unlike original stinky, there are NO definitions for packet types, they must be implemented externally (in-engine) --
-- stinky2 will only handle connected players, and encryption. Everything else is DIY.--
-- todo: switch to C function exporting.

pragma SPARK_Mode (On);

with Interfaces.C; use Interfaces.C;
with System;       use System;

package Stinky2
   with SPARK_Mode => On
is

    -- Change the nickname limit as you need.
    --package Nickname is new
    --    Ada.Strings.Bounded.Generic_Bounded_Length(Max => 32);
    --use Nickname;

    -- Call libsodium to get publickey, secretkey, sessionkey sizes.
    function crypto_kx_publickeybytes return size_t
    with Import => True, Convention => C, Global => null;
    function crypto_kx_secretkeybytes return size_t
    with Import => True, Convention => C, Global => null;
    function crypto_kx_sessionkeybytes return size_t
    with Import => True, Convention => C, Global => null;

    publicKey_size  : constant Interfaces.C.size_t := crypto_kx_publickeybytes;
    secretKey_size  : constant Interfaces.C.size_t := crypto_kx_secretkeybytes;
    sessionKey_size : constant Interfaces.C.size_t :=
       crypto_kx_sessionkeybytes;

    type PublicKey is
       array (Interfaces.C.size_t range <>) of Interfaces.C.unsigned_char;
    pragma Convention (C, PublicKey);

    type SecretKey is
       array (Interfaces.C.size_t range <>) of Interfaces.C.unsigned_char;
    pragma Convention (C, SecretKey);

    type SessionKey is
       array (Interfaces.C.size_t range <>) of Interfaces.C.unsigned_char;
    pragma Convention (C, SessionKey);

    -- This device's keys.
    HostPubkey     : PublicKey (0 .. crypto_kx_publickeybytes - 1);
    HostSecretKey  : SecretKey (0 .. crypto_kx_secretkeybytes - 1);
    HostSessionKey : SessionKey (0 .. crypto_kx_sessionkeybytes - 1);

    -- ENetAddress Data
    type enet_uint32 is new Interfaces.C.unsigned;
    type enet_uint16 is new Interfaces.C.unsigned_short;
    type enet_uint8 is new Interfaces.C.unsigned_char;

    type ENetAddress is record
        host : enet_uint32;
        port : enet_uint16;
    end record;
    pragma Convention (C, ENetAddress);

    -- Hack to get a null pointer in Ada
    type ENetAddressAccess is access constant ENetAddress;

    type ClientsCount is new size_t;
    type ChannelsCount is new size_t;
    type BandwidthCount is new enet_uint32;

    -- ointers, not full impls...maybe we throw some stuff on later and convert this an access type.
    type ENetHostPtr is new System.Address;
    type ENetPeerPtr is new System.Address;

    -- A transmission layer representation of a peer.
    --type PeerInformation is record

    --ed record;

    -- A thin wrapper for ENetPeer *.
    -- For clients, this will be the server. For servers, this will be client.
    --type Peer is record

    --nd record;

    -- Enums
    -- Function results
    type FnResult is (Success, Fail);

    --Functions
    function Init return FnResult; -- Initialize subsystems
    procedure Deinit
    with Always_Terminates, Global => Null;

    -- tility
    function IPToAddress
       (address : in out ENetAddress; ip : in String) return FnResult
    with Side_Effects, Pre => ip'Length /= 0;

    procedure DestroyHost (hostPtr : in out ENetHostPtr)
    with
       Global => Null,
       Pre    => hostPtr /= ENetHostPtr (System.Null_Address),
       Post   => hostPtr = ENetHostPtr (System.Null_Address);

    function StartHost
       (listen    : Boolean;
        hostPtr   : out ENetHostPtr;
        -- CAUTION, may be Null_Address...insert checks for this.
        address   : ENetAddress;
        clients   : ClientsCount;
        channels  : ChannelsCount;
        bandwidth : BandwidthCount) return FnResult
    with Side_Effects, Global => Null;

    function Connect
       (peer         : out ENetPeerPtr;
        host         : ENetHostPtr;
        address      : ENetAddress;
        channelCount : ChannelsCount;
        data         : enet_uint32) return FnResult
    with
       Side_Effects,
       Global => Null,
       Pre    => host /= ENetHostPtr (System.Null_Address);
    --procedure Recv; -- Receive and decrypt data
    --procedure Send; -- Encrypt an send data.

private
    -- IMPORTED C FUNCTIONS
    -- hey make sure these fn sigs are correct

    -- void enet_host_destroy 	( 	ENetHost *  	host	)
    procedure enet_host_destroy (host : ENetHostPtr)
    with Import => True, Convention => C, Global => null, Always_Terminates;

    -- nt 	enet_address_set_host_ip (ENetAddress *address, const char *hostName)
    function enet_address_set_host_ip
       (address : ENetAddress; ip : Interfaces.C.char_array)
        return Interfaces.C.int
    with
       Import     => True,
       Convention => C,
       Global     =>
          null;        -- Technically, this should return an ENetHost *, but we don't really use it...so it's a void *.

    -- ENetHost * 	enet_host_create
    -- (const ENetAddress *address, size_t peerCount, size_t channelLimit, enet_uint32 incomingBandwidth, enet_uint32 outgoingBandwidth)
    --
    function enet_host_create_listen
       (address      : ENetAddress;
        clients      : ClientsCount;
        channels     : ChannelsCount;
        bandwidthIn  : BandwidthCount;
        bandwidthOut : BandwidthCount) return ENetHostPtr
    with
       Import        => True,
       Convention    => C,
       Global        => null,
       External_Name => "enet_host_create";

    -- ENetHost * 	enet_host_create
    -- (const ENetAddress *address, size_t peerCount, size_t channelLimit, enet_uint32 incomingBandwidth, enet_uint32 outgoingBandwidth)
    function enet_host_create_nolisten
       (address      : ENetAddressAccess;
        clients      : ClientsCount;
        channels     : ChannelsCount;
        bandwidthIn  : BandwidthCount;
        bandwidthOut : BandwidthCount) return ENetHostPtr
    with
       Import        => True,
       Convention    => C,
       Global        => null,
       External_Name => "enet_host_create";
    -- stubbed impl

    -- ENetPeer * 	enet_host_connect
    -- (ENetHost *host, const ENetAddress *address, size_t channelCount, enet_uint32 data)
    --
    function enet_host_connect
       (host         : ENetHostPtr;
        address      : ENetAddress;
        channelCount : ChannelsCount;
        data         : enet_uint32) return ENetPeerPtr
    with Import => True, Convention => C, Global => null;

    -- int 	enet_host_service (ENetHost *host, ENetEvent *event, enet_uint32 timeout)
    type ENetEventType is
       (ENET_EVENT_TYPE_NONE,
        ENET_EVENT_TYPE_CONNECT,
        ENET_EVENT_TYPE_DISCONNECT,
        ENET_EVENT_TYPE_RECEIVE);

    type ENetPacketFreeCallback is access procedure (Packet : System.Address)
    with Convention => C;
    type ENetPacket is record
        data           : System.Address;
        dataLength     : size_t;
        flags          : enet_uint32;
        freeCallback   : ENetPacketFreeCallback;
        referenceCount : size_t;
        UserData       : System.Address;
    end record;

    type ENetEvent is record
        channelID : enet_uint8;
        data      : enet_uint32;
        packet    : ENetPacket;
        peer      : ENetPeerPtr;
        event     : ENetEventType;
    end record;

    procedure enet_deinitialize
    with Import => True, Convention => C, Global => null, Always_Terminates;
    function sodium_init return int
    with Import => True, Convention => C, Global => null;
    function enet_initialize return int
    with
       Import     => True,
       Convention => C,
       Global     => null;        -- generate cryptokeypairs
    function crypto_kx_keypair (pk : PublicKey; sk : SecretKey) return int
    with Import => True, Convention => C, Global => null;

end Stinky2;
