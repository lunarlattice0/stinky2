with Stinky2;      use Stinky2;
with Ada.Calendar; use Ada.Calendar;

procedure Stinky2_Tests.Host_Test with SPARK_Mode => On is
begin
    -- Try init
    if Init /= Success then
        raise Program_Error with ("Subsystems didn't initialize properly!");
    end if;
    -- Try to start listener

    declare
        hostPtr   : ENetHostPtr;
        address   : ENetAddress := (0, 0);
        clients   : constant ClientsCount := 4;
        channels  : constant ChannelsCount := 4;
        bandwidth : constant BandwidthCount := 256;
    begin

        if IPToAddress (address, "127.0.0.1") /= Success then
            raise Program_Error with ("Couldn't convert ip to address");
        end if;
        address.port := 6868;
        if StartHost (True, hostPtr, address, clients, channels, bandwidth)
           /= Success
        then
            raise Program_Error with ("Couldn't start listener!");
        end if;

        declare
            Start_Time : Ada.Calendar.Time;
            Limit_Time : Ada.Calendar.Time;
        begin
            Start_Time := Ada.Calendar.Clock;
            Limit_Time := Start_Time + 15.0;
            while Ada.Calendar.Clock < Limit_Time loop
                if Receive (hostPtr) /= Success then
                    raise Program_Error
                       with ("Something failed in reception!");
                end if;
                delay 0.016;
            end loop;
        end;

        DestroyHost (hostPtr);
        Deinit;
    end;

end Stinky2_Tests.Host_Test;
