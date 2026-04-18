with Interfaces.C;
with System;

package Secure_Alloc_C
  with SPARK_Mode => Off
is
   function Secure_Allocator_Init return Interfaces.C.int
     with Export,
          Convention => C,
          External_Name => "secure_allocator_init";

   function Secure_Malloc (Size : Interfaces.C.size_t) return System.Address
     with Export,
          Convention => C,
          External_Name => "secure_malloc";

   function Secure_Calloc (Count : Interfaces.C.size_t; Size : Interfaces.C.size_t) return System.Address
     with Export,
          Convention => C,
          External_Name => "secure_calloc";

   function Secure_Realloc (Ptr : System.Address; New_Size : Interfaces.C.size_t) return System.Address
     with Export,
          Convention => C,
          External_Name => "secure_realloc";

   procedure Secure_Free (Ptr : System.Address)
     with Export,
          Convention => C,
          External_Name => "secure_free";

   function Secure_Usable_Size (Ptr : System.Address) return Interfaces.C.size_t
     with Export,
          Convention => C,
          External_Name => "secure_usable_size";

   function Secure_Pointer_Allocated (Ptr : System.Address) return Interfaces.C.int
     with Export,
          Convention => C,
          External_Name => "secure_pointer_allocated";

   function Secure_Pool_Base return System.Address
     with Export,
          Convention => C,
          External_Name => "secure_pool_base";

   function Secure_Pool_Size return Interfaces.C.size_t
     with Export,
          Convention => C,
          External_Name => "secure_pool_size";

   function Secure_Pool_Find_Pattern
     (Pattern : System.Address;
      Length  : Interfaces.C.size_t) return Interfaces.C.long_long
     with Export,
          Convention => C,
          External_Name => "secure_pool_find_pattern";
end Secure_Alloc_C;
