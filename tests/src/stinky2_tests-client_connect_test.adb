with Stinky2; use Stinky2;
with Ada.Text_IO; use Ada.Text_IO;

procedure Stinky2_Tests.Client_Connect_Test
with SPARK_Mode => On
is
begin
    -- Try init
    if Init /= Success then
        raise Program_Error with ("Subsystems didn't initialize properly!");
    end if;
    -- Try to start listener

    declare
        hostPtr : ENetHostPtr;
        -- fakeAddress is ignored.
        fakeAddress : constant ENetAddress := (0,0);
        address : ENetAddress := (0,6969);
        clients : constant ClientsCount := 1;
        channels : constant ChannelsCount := 1;
        bandwidth : constant BandwidthCount := 256;

        peer : ENetPeerPtr;
    begin
        if IPToAddress(address, "127.0.0.1") /= Success then
            raise Program_Error with ("Couldn't convert ip to address");
        end if;

        Put_Line(address.host'Image);
        Put_Line(address.port'Image);
        if StartHost(False, hostPtr, fakeAddress, clients, channels, bandwidth) /= Success then
            raise Program_Error with ("Couldn't start host!");
        end if;

        if Connect(peer, hostPtr, address, channels, enet_uint32(0)) /= Success then
            raise Program_Error with ("Couldn't connect!");
        end if;

        Put_Line(address.host'Image);
        Put_Line(address.port'Image);

        DestroyHost(hostPtr);
        Deinit;
    end;

end Stinky2_Tests.Client_Connect_Test;
