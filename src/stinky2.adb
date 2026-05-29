package body Stinky2
   with SPARK_Mode => On
is
    function Init (is_hosting : Boolean) return FnResult is
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
