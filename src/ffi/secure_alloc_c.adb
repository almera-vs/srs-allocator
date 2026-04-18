with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with Secure_Allocator_Runtime;
with Secure_Pool;
with System;
with System.Storage_Elements;

package body Secure_Alloc_C
  with SPARK_Mode => Off
is
   use type System.Storage_Elements.Integer_Address;
   use type Interfaces.Unsigned_8;
   use type Secure_Pool.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.C.long_long;
   use type System.Address;
   use type System.Storage_Elements.Storage_Offset;

   subtype Size_T is Interfaces.C.size_t;

   type Byte_Ptr is access all Secure_Pool.Byte;
   function To_Byte_Ptr is new Ada.Unchecked_Conversion (System.Address, Byte_Ptr);

   function To_Size_Type (Value : Size_T; Valid : out Boolean) return Secure_Pool.Size_Type is
   begin
      if Value = 0 then
         Valid := False;
         return 0;
      elsif Value > Size_T (Secure_Pool.Pool_Size) then
         Valid := False;
         return 0;
      else
         Valid := True;
         return Secure_Pool.Size_Type (Value);
      end if;
   end To_Size_Type;

   function Offset_To_Address (Offset : Secure_Pool.Offset_Type) return System.Address is
      Base : constant System.Address := Secure_Pool.Raw_Base_Address;
      Base_Int : constant System.Storage_Elements.Integer_Address := System.Storage_Elements.To_Integer (Base);
   begin
      return System.Storage_Elements.To_Address
        (Base_Int + System.Storage_Elements.Integer_Address (Secure_Pool.Size_Type (Offset) - 1));
   end Offset_To_Address;

   function Address_To_Offset (Ptr : System.Address; Valid : out Boolean) return Secure_Pool.Offset_Type is
      Base : constant System.Address := Secure_Pool.Raw_Base_Address;
      Base_Int : constant System.Storage_Elements.Integer_Address := System.Storage_Elements.To_Integer (Base);
      Ptr_Int  : constant System.Storage_Elements.Integer_Address := System.Storage_Elements.To_Integer (Ptr);
   begin
      if Ptr = System.Null_Address then
         Valid := False;
         return 1;
      end if;

      if Ptr_Int < Base_Int then
         Valid := False;
         return 1;
      end if;

      if Ptr_Int - Base_Int >= System.Storage_Elements.Integer_Address (Secure_Pool.Pool_Size) then
         Valid := False;
         return 1;
      end if;

      Valid := True;
      return Secure_Pool.Offset_Type (Natural (Ptr_Int - Base_Int) + 1);
   end Address_To_Offset;

   function Secure_Allocator_Init return Interfaces.C.int is
   begin
      if Secure_Allocator_Runtime.Ensure_Initialized then
         return 1;
      end if;
      return 0;
   exception
      when others =>
         return 0;
   end Secure_Allocator_Init;

   function Secure_Malloc (Size : Interfaces.C.size_t) return System.Address is
      Is_Valid : Boolean;
      Ada_Size : Secure_Pool.Size_Type;
      Offset   : Secure_Pool.Offset_Type;
      Usable   : Secure_Pool.Size_Type;
      Status   : Secure_Pool.Status_Code;
   begin
      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return System.Null_Address;
      end if;

      Ada_Size := To_Size_Type (Size, Is_Valid);
      if not Is_Valid then
         return System.Null_Address;
      end if;

      Secure_Pool.Allocate (Ada_Size, Offset, Usable, Status);
      if Status /= Secure_Pool.Ok then
         return System.Null_Address;
      end if;

      return Offset_To_Address (Offset);
   exception
      when others =>
         return System.Null_Address;
   end Secure_Malloc;

   function Secure_Calloc (Count : Interfaces.C.size_t; Size : Interfaces.C.size_t) return System.Address is
      Bytes : Interfaces.C.size_t;
      Ptr   : System.Address;
      Is_Valid : Boolean;
      Off   : Secure_Pool.Offset_Type;
      Status : Secure_Pool.Status_Code;
   begin
      if Count = 0 or else Size = 0 then
         return System.Null_Address;
      end if;

      if Count > Size_T (Secure_Pool.Pool_Size) / Size then
         return System.Null_Address;
      end if;

      Bytes := Count * Size;
      Ptr := Secure_Malloc (Bytes);
      if Ptr = System.Null_Address then
         return System.Null_Address;
      end if;

      Off := Address_To_Offset (Ptr, Is_Valid);
      if not Is_Valid then
         return System.Null_Address;
      end if;

      Secure_Pool.Zero_Allocation (Off, Status);
      if Status /= Secure_Pool.Ok then
         return System.Null_Address;
      end if;

      return Ptr;
   exception
      when others =>
         return System.Null_Address;
   end Secure_Calloc;

   procedure Secure_Free (Ptr : System.Address) is
      Is_Valid : Boolean;
      Offset   : Secure_Pool.Offset_Type;
      C_First  : Secure_Pool.Offset_Type;
      C_Last   : Secure_Pool.Offset_Type;
      Status   : Secure_Pool.Status_Code;
   begin
      if Ptr = System.Null_Address then
         return;
      end if;

      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return;
      end if;

      Offset := Address_To_Offset (Ptr, Is_Valid);
      if not Is_Valid then
         return;
      end if;

      Secure_Pool.Free (Offset, C_First, C_Last, Status);
      pragma Unreferenced (C_First);
      pragma Unreferenced (C_Last);
   exception
      when others =>
         null;
   end Secure_Free;

   function Secure_Realloc (Ptr : System.Address; New_Size : Interfaces.C.size_t) return System.Address is
      Is_Valid : Boolean;
      Offset   : Secure_Pool.Offset_Type;
      Ada_Size : Secure_Pool.Size_Type;
      New_Off  : Secure_Pool.Offset_Type;
      Usable   : Secure_Pool.Size_Type;
      Status   : Secure_Pool.Status_Code;
   begin
      if Ptr = System.Null_Address then
         return Secure_Malloc (New_Size);
      end if;

      if New_Size = 0 then
         Secure_Free (Ptr);
         return System.Null_Address;
      end if;

      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return System.Null_Address;
      end if;

      Offset := Address_To_Offset (Ptr, Is_Valid);
      if not Is_Valid then
         return System.Null_Address;
      end if;

      Ada_Size := To_Size_Type (New_Size, Is_Valid);
      if not Is_Valid then
         return System.Null_Address;
      end if;

      Secure_Pool.Reallocate (Offset, Ada_Size, New_Off, Usable, Status);
      if Status /= Secure_Pool.Ok then
         return System.Null_Address;
      end if;

      return Offset_To_Address (New_Off);
   exception
      when others =>
         return System.Null_Address;
   end Secure_Realloc;

   function Secure_Usable_Size (Ptr : System.Address) return Interfaces.C.size_t is
      Is_Valid : Boolean;
      Offset   : Secure_Pool.Offset_Type;
   begin
      if Ptr = System.Null_Address then
         return 0;
      end if;

      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return 0;
      end if;

      Offset := Address_To_Offset (Ptr, Is_Valid);
      if not Is_Valid then
         return 0;
      end if;

      if not Secure_Pool.Is_Allocated (Offset) then
         return 0;
      end if;

      return Interfaces.C.size_t (Secure_Pool.Allocation_Size (Offset));
   exception
      when others =>
         return 0;
   end Secure_Usable_Size;

   function Secure_Pointer_Allocated (Ptr : System.Address) return Interfaces.C.int is
      Is_Valid : Boolean;
      Offset   : Secure_Pool.Offset_Type;
   begin
      if Ptr = System.Null_Address then
         return 0;
      end if;

      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return 0;
      end if;

      Offset := Address_To_Offset (Ptr, Is_Valid);
      if not Is_Valid then
         return 0;
      end if;

      if Secure_Pool.Is_Index_Allocated (Offset) then
         return 1;
      end if;
      return 0;
   exception
      when others =>
         return 0;
   end Secure_Pointer_Allocated;

   function Secure_Pool_Find_Pattern
     (Pattern : System.Address;
      Length  : Interfaces.C.size_t) return Interfaces.C.long_long
   is
      Pattern_Len : Natural;
      Last_Start  : Secure_Pool.Size_Type;
      Found       : Boolean;
   begin
      if Pattern = System.Null_Address or else Length = 0 then
         return -1;
      end if;

      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return -1;
      end if;

      if Length > Size_T (Secure_Pool.Pool_Size) then
         return -1;
      end if;

      Pattern_Len := Natural (Length);
      Last_Start := Secure_Pool.Pool_Size - Secure_Pool.Size_Type (Length) + 1;

      for Start_Pos in 1 .. Last_Start loop
         Found := True;
         for K in 0 .. Pattern_Len - 1 loop
            declare
               Pool_Index   : constant Secure_Pool.Offset_Type :=
                 Secure_Pool.Offset_Type (Start_Pos + Secure_Pool.Size_Type (K));
               Pattern_Byte : constant Secure_Pool.Byte := To_Byte_Ptr
                 (System.Storage_Elements.To_Address
                    (System.Storage_Elements.To_Integer (Pattern) +
                     System.Storage_Elements.Integer_Address (K))).all;
            begin
               if Secure_Pool.Byte_At (Pool_Index) /= Pattern_Byte then
                  Found := False;
                  exit;
               end if;
            end;
         end loop;

         if Found then
            return Interfaces.C.long_long (Start_Pos - 1);
         end if;
      end loop;

      return -1;
   exception
      when others =>
         return -1;
   end Secure_Pool_Find_Pattern;

   function Secure_Pool_Base return System.Address is
   begin
      if not Secure_Allocator_Runtime.Ensure_Initialized then
         return System.Null_Address;
      end if;
      return Secure_Pool.Raw_Base_Address;
   exception
      when others =>
         return System.Null_Address;
   end Secure_Pool_Base;

   function Secure_Pool_Size return Interfaces.C.size_t is
   begin
      return Interfaces.C.size_t (Secure_Pool.Pool_Size);
   end Secure_Pool_Size;
end Secure_Alloc_C;
