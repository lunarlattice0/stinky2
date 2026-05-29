-- Please note: Unlike original stinky, there are NO definitions for packet types, they must be implemented externally (in-engine) --
-- stinky2 will only handle connected players, and encryption. Everything else is DIY.--
-- todo: switch to C function exporting.

pragma SPARK_Mode (On);

with Ada.Strings;  use Ada.Strings;
with Interfaces.C; use Interfaces.C;

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

    -- A transmission layer representation of a peer.
    --type PeerInformation is record

    --end record;

    -- A thin wrapper for ENetPeer *.
    -- For clients, this will be the server. For servers, this will be client.
    --type Peer is record

    --end record;

    -- Enums
    -- Function results
    type FnResult is (Success, Fail);

    -- Functions
    function Init
       (is_hosting : Boolean) return FnResult; -- Initialize subsystems
    -- TODO: Add atexit for enet_deinitialize.
    --procedure Recv; -- Receive and decrypt data
    --procedure Send; -- Encrypt and send data.

end Stinky2;
