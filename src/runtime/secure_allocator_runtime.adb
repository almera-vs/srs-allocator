with Secure_Pool;

package body Secure_Allocator_Runtime
  with SPARK_Mode => Off
is
   Initialized : Boolean := False;

   function Ensure_Initialized return Boolean is
   begin
      if not Initialized then
         Secure_Pool.Initialize;
         Initialized := Secure_Pool.Is_Initialized;
      end if;
      return Initialized;
   end Ensure_Initialized;
end Secure_Allocator_Runtime;
