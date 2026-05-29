with Stinky2; use Stinky2;

procedure Stinky2_Tests.Init_Test is
begin
    if Init (False) /= Success then
        raise Program_Error with ("Subsystems didn't initialize properly!");
    end if;
end Stinky2_Tests.Init_Test;
