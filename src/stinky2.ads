-- Please note: Unlike original stinky, there are NO definitions for packet types, they must be implemented externally (in-engine) --
-- stinky2 will only handle connected players, and encryption. Everything else is DIY.--
-- todo: switch to C function exporting.

pragma SPARK_Mode (On);

with Interfaces.C; use Interfaces.C;
with System;       use System;
with Ada.Containers.Vectors;

package Stinky2
   with SPARK_Mode => On
is

    -- Probably will never change. hardcode to 32 for now.
    publicKey_size  : constant Interfaces.C.size_t := 32;
    secretKey_size  : constant Interfaces.C.size_t := 32;
    sessionKey_size : constant Interfaces.C.size_t := 32;

    type PublicKey is
       array (Interfaces.C.size_t range 0 .. 31) of Interfaces.C.unsigned_char;
    pragma Convention (C, PublicKey);

    type SecretKey is
       array (Interfaces.C.size_t range 0 .. 31) of Interfaces.C.unsigned_char;
    pragma Convention (C, SecretKey);

    type SessionKey is
       array (Interfaces.C.size_t range 0 .. 31) of Interfaces.C.unsigned_char;
    pragma Convention (C, SessionKey);

    -- This device's keys.
    HostPubkey     : aliased PublicKey;
    HostSecretKey  : aliased SecretKey;
    HostSessionKey : aliased SessionKey;

    -- ENetAddress Data
    type enet_uint32 is new Interfaces.C.unsigned;
    type enet_uint16 is new Interfaces.C.unsigned_short;
    type enet_uint8 is new Interfaces.C.unsigned_char;

    type ENetAddress is record
        host : enet_uint32;
        port : enet_uint16;
    end record;
    pragma Convention (C, ENetAddress);

    -- Hack to get a void pointer in Ada
    type ENetAddressAccess is access constant ENetAddress;

    type ClientsCount is new size_t;
    type ChannelsCount is new size_t;
    type BandwidthCount is new enet_uint32;

    -- ointers, not full impls...maybe we throw some stuff on later and convert this an access type.
    type ENetHostPtr is new System.Address;
    type ENetPeerPtr is new System.Address;

    type PeerInformation is record
        keyExCompleted      : Boolean := false;
        receive_SessionKey  : SessionKey;
        transmit_SessionKey : SessionKey;

        -- need id?
    end record;
    -- Store PeerInformation in a Vector
    package PIVector is new
       Ada.Containers.Vectors
          (Index_Type   => Natural,
           Element_Type => PeerInformation);

    HostPIVector : PIVector.Vector;

    type FnResult is (Success, Fail);

    function Init return FnResult; -- Initialize subsystems
    procedure Deinit
    with Always_Terminates, Global => Null;

    function Receive (host : ENetHostPtr) return FnResult
    with Global => HostPubkey;

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

    type ENetEventType is
       (ENET_EVENT_TYPE_NONE,
        ENET_EVENT_TYPE_CONNECT,
        ENET_EVENT_TYPE_DISCONNECT,
        ENET_EVENT_TYPE_RECEIVE);
    pragma Convention (C, ENetEventType);

    type ENetPacketFreeCallback is access procedure (Packet : System.Address)
    with Convention => C;
    type ENetPacket is record
        referenceCount : size_t; -- dont' use
        flags          : enet_uint32;
        data           : System.Address;
        dataLength     : size_t;
        freeCallback   : ENetPacketFreeCallback;
        UserData       : System.Address;
    end record
    with Convention => C;

    type ENetEvent is record
        event     :
           ENetEventType; -- note: renamed from type, due to keyword conflict
        peer      : ENetPeerPtr;
        channelID : enet_uint8;
        data      : enet_uint32;
        packet    : ENetPacket;

    end record
    with Convention => C;

    function enet_host_service
       (host : ENetHostPtr; event : ENetEvent; timeout : enet_uint32)
        return int
    with Import => True, Convention => C, Global => null;

    type ENetPacketFlag is new enet_uint32;
    ENET_PACKET_FLAG_NONE                : constant ENetPacketFlag :=
       16#0000_0000#;
    ENET_PACKET_FLAG_RELIABLE            : constant ENetPacketFlag :=
       16#0000_0001#; -- 1 << 0
    ENET_PACKET_FLAG_UNSEQUENCED         : constant ENetPacketFlag :=
       16#0000_0002#; -- 1 << 1
    ENET_PACKET_FLAG_NO_ALLOCATE         : constant ENetPacketFlag :=
       16#0000_0004#; -- 1 << 2
    ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT : constant ENetPacketFlag :=
       16#0000_0008#; -- 1 << 3
    ENET_PACKET_FLAG_SENT                : constant ENetPacketFlag :=
       16#0000_0010#; -- 1 << 4

    type ENetPacketPtr is access all ENetPacket;
    -- Don't use this raw function. use enet_packet_create_wrapper instead.
    function enet_packet_create
       (data : System.Address; dataLength : size_t; flags : ENetPacketFlag)
        return ENetPacketPtr
    with Import => True, Convention => C, Global => null;

    generic
        type T (<>) is private;
    function enet_packet_create_wrapper
       (data : T; dataLength : size_t; flags : ENetPacketFlag)
        return ENetPacketPtr
    with Global => null;

    procedure enet_packet_destroy (packet : ENetPacketPtr)
    with Import => True, Convention => C, Global => null;

    function enet_peer_send
       (peer      : ENetPeerPtr;
        channelID : enet_uint8;
        packet    : in out ENetPacketPtr)
        return int
               --with Import => True, Convention => C, Global => null;
    with Global => null, Side_Effects;

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
