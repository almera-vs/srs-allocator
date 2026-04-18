with Interfaces;
with System;

package Secure_Pool
  with SPARK_Mode,
       Abstract_State => State
is
   pragma Unevaluated_Use_Of_Old (Allow);
   use type Interfaces.Unsigned_8;

   Pool_Size        : constant := 268_435_456;
   Max_Blocks       : constant := 262_144;
   Alignment_Bytes  : constant := 16;

   subtype Size_Type   is Natural range 0 .. Pool_Size;
   subtype Offset_Type is Size_Type range 1 .. Pool_Size;
   subtype Byte        is Interfaces.Unsigned_8;

   type Status_Code is (Ok, Not_Initialized, Out_Of_Memory, Invalid_Pointer, Invalid_Size);

   function Is_Initialized return Boolean
     with Global => (Input => State);

   function Is_Allocated (Offset : Offset_Type) return Boolean
      with Global => (Input => State);

   function Allocation_Size (Offset : Offset_Type) return Size_Type
       with Global => (Input => State),
            Post   =>
              (if Is_Allocated (Offset) then
                  Allocation_Size'Result > 0
                  and then
                  (if Is_Initialized and then Descriptors_Valid then
                      Range_Within_Pool (Offset, Allocation_Size'Result)
                   else
                      True)
               else
                  Allocation_Size'Result = 0);

   function Allocated_Last (Offset : Offset_Type) return Offset_Type
      with Global => (Input => State),
           Post   => (if Is_Allocated (Offset) then Allocated_Last'Result >= Offset);

   function Byte_At (Index : Offset_Type) return Byte
     with Global => (Input => State),
          Pre    => Is_Initialized;

   function Is_Index_Allocated (Index : Offset_Type) return Boolean
     with Global => (Input => State),
          Pre    => Is_Initialized;

   function Range_Within_Pool
     (Start  : Offset_Type;
      Length : Size_Type) return Boolean
     with Ghost;

   function Range_Within_Pool_Runtime
     (Start  : Offset_Type;
      Length : Size_Type) return Boolean;

   function Range_Last
     (Start  : Offset_Type;
      Length : Size_Type) return Offset_Type
      with Ghost,
           Pre  => Range_Within_Pool (Start, Length),
           Post => Range_Last'Result = Offset_Type (Size_Type (Start) + Length - 1);

   function Range_Last_Runtime
     (Start  : Offset_Type;
      Length : Size_Type) return Offset_Type
     with Pre => Range_Within_Pool (Start, Length),
          Post => Range_Last_Runtime'Result = Offset_Type (Size_Type (Start) + Length - 1);

   function Range_Zeroed
     (Start  : Offset_Type;
      Length : Size_Type) return Boolean
     with Ghost,
          Global => (Input => State),
          Pre    => Is_Initialized and then Range_Within_Pool (Start, Length);

   function Range_Zeroed_Bounds
     (First : Offset_Type;
      Last  : Offset_Type) return Boolean
     with Ghost,
          Global => (Input => State),
          Pre    => Is_Initialized and then First <= Last;

   function Descriptor_Valid (Start : Offset_Type; Length : Size_Type; Active : Boolean) return Boolean
     with Ghost;

   procedure Split_Preserves_Disjointness
     (Original_Start   : Offset_Type;
      Original_Length  : Size_Type;
      Left_Start       : Offset_Type;
      Left_Length      : Size_Type;
      Right_Start      : Offset_Type;
      Right_Length     : Size_Type)
     with Ghost,
            Pre  => Range_Within_Pool (Original_Start, Original_Length)
                    and then Range_Within_Pool (Left_Start, Left_Length)
                    and then Range_Within_Pool (Right_Start, Right_Length)
                    and then Left_Start = Original_Start
                    and then Size_Type (Original_Start) <= Pool_Size - Left_Length
                    and then Right_Start = Offset_Type (Size_Type (Original_Start) + Left_Length),
           Post => Descriptors_Disjoint
                     (Left_Start, Left_Length, True,
                      Right_Start, Right_Length, True);

   procedure Merge_Preserves_Disjointness
     (Left_Start    : Offset_Type;
      Left_Length   : Size_Type;
      Right_Start   : Offset_Type;
      Right_Length  : Size_Type;
      Merged_Start  : Offset_Type;
      Merged_Length : Size_Type)
     with Ghost,
           Pre  => Range_Within_Pool (Left_Start, Left_Length)
                   and then Range_Within_Pool (Right_Start, Right_Length)
                   and then Left_Start = Merged_Start
                   and then Size_Type (Left_Start) <= Pool_Size - Left_Length
                   and then Right_Start = Offset_Type (Size_Type (Left_Start) + Left_Length)
                   and then Merged_Length = Left_Length + Right_Length
                   and then Range_Within_Pool (Merged_Start, Merged_Length),
           Post => Descriptors_Disjoint
                     (Merged_Start, Merged_Length, True,
                      Right_Start, Right_Length, False);

   procedure Unchanged_Descriptor_Preservation
     (Start  : Offset_Type;
      Length : Size_Type;
      Active : Boolean)
     with Ghost,
          Pre  => (if Active then Range_Within_Pool (Start, Length) else True),
          Post => Descriptor_Valid (Start, Length, Active);

   function Shrink_Tail_Zeroed
     (Offset   : Offset_Type;
      Usable   : Size_Type;
      Old_Size : Size_Type;
      Old_Last : Offset_Type) return Boolean
     with Ghost,
          Global => (Input => State),
          Pre    => Is_Initialized;

   function Descriptors_Disjoint
     (L_Start  : Offset_Type;
      L_Length : Size_Type;
      L_Active : Boolean;
      R_Start  : Offset_Type;
      R_Length : Size_Type;
      R_Active : Boolean) return Boolean
     with Ghost;

   function Descriptors_Valid return Boolean
     with Ghost,
          Global => (Input => State),
          Pre    => Is_Initialized;

   function State_Consistent return Boolean
      with Ghost,
           Global => (Input => State),
           Pre    => Is_Initialized;

   function Active_Disjointness return Boolean
     with Ghost,
          Global => (Input => State),
          Pre    => Is_Initialized;

   function Old_Alloc_Size (Offset : Offset_Type) return Size_Type
      with Ghost,
           Global => (Input => State),
           Pre    => Is_Initialized,
           Post   =>
             (if Is_Allocated (Offset) and then State_Consistent then
                Old_Alloc_Size'Result = Allocation_Size (Offset));

   function Old_Alloc_Last (Offset : Offset_Type) return Offset_Type
      with Ghost,
           Global => (Input => State),
           Pre    => Is_Initialized,
           Post   => Old_Alloc_Last'Result >= Offset
                     and then
                     (if Is_Allocated (Offset) and then State_Consistent then
                        Old_Alloc_Last'Result = Allocated_Last (Offset));

   function Shifted_Offset_Runtime
     (Base  : Offset_Type;
      Shift : Size_Type) return Offset_Type
     with Pre  => Size_Type (Base) <= Pool_Size - Shift,
          Post => Shifted_Offset_Runtime'Result = Offset_Type (Size_Type (Base) + Shift);

   function Shifted_Offset
     (Base  : Offset_Type;
      Shift : Size_Type) return Offset_Type
     with Ghost,
          Pre  => Size_Type (Base) <= Pool_Size - Shift,
          Post => Shifted_Offset'Result = Offset_Type (Size_Type (Base) + Shift);

   procedure Initialize
     with Global  => (Output => State),
          Depends => (State => null),
          Post    => Is_Initialized;

   procedure Allocate
     (Size   : Size_Type;
      Offset : out Offset_Type;
      Usable : out Size_Type;
      Status : out Status_Code)
      with Global  => (In_Out => State),
            Depends => ((State, Offset, Usable, Status) => (State, Size)),
            Pre     => Is_Initialized and then State_Consistent and then Descriptors_Valid,
             Post    =>
               State_Consistent and then Descriptors_Valid and then
               (if Status = Ok then
                  Is_Allocated (Offset)
                  and then (if Usable > 0 then Range_Within_Pool (Offset, Usable) else True)
                  and then Usable = Allocation_Size (Offset)
                  and then (if Usable > 0 then Range_Zeroed (Offset, Usable) else True)
                   and then Usable >= Size
                 elsif Status = Invalid_Size then
                   Size = 0
                 else
                   Status = Out_Of_Memory);

   procedure Zero_Allocation
     (Offset : Offset_Type;
      Status : out Status_Code)
     with Global  => (In_Out => State),
           Depends => ((State, Status) => (State, Offset)),
           Pre     => Is_Initialized and then State_Consistent,
             Post    =>
               State_Consistent and then
               (if Status = Ok then
                   Is_Allocated (Offset)
                   and then Range_Zeroed_Bounds (Offset, Allocated_Last (Offset))
                  else
                    Status = Invalid_Pointer);

   procedure Free
     (Offset        : Offset_Type;
      Cleared_First : out Offset_Type;
      Cleared_Last  : out Offset_Type;
      Status        : out Status_Code)
      with Global  => (In_Out => State),
            Depends => ((State, Cleared_First, Cleared_Last, Status) => (State, Offset)),
             Pre     => Is_Initialized and then State_Consistent and then Descriptors_Valid,
             Post    =>
               State_Consistent and then Descriptors_Valid and then
                (if Status = Ok then
                    Cleared_First = Offset
                    and then Cleared_Last = Old_Alloc_Last (Offset)'Old
                    and then
                    Cleared_First <= Cleared_Last
                    and then Range_Zeroed_Bounds (Cleared_First, Cleared_Last)
                  else
                    Status = Invalid_Pointer);

   procedure Reallocate
     (Offset     : Offset_Type;
      New_Size   : Size_Type;
      New_Offset : out Offset_Type;
      Usable     : out Size_Type;
      Status     : out Status_Code)
      with Global  => (In_Out => State),
            Depends => ((State, New_Offset, Usable, Status) => (State, Offset, New_Size)),
            Pre     => Is_Initialized and then State_Consistent and then Descriptors_Valid,
            Post    =>
              State_Consistent and then Descriptors_Valid and then
              (if Status = Ok then
                   Is_Allocated (New_Offset)
                   and then (if Usable > 0 then Range_Within_Pool (New_Offset, Usable) else True)
                   and then Usable = Allocation_Size (New_Offset)
                    and then Usable >= New_Size
                 elsif Status = Invalid_Size then
                   New_Size = 0
                 else
                   Status = Invalid_Pointer or else Status = Out_Of_Memory);

   function Raw_Base_Address return System.Address
     with SPARK_Mode => Off;

private
   subtype Descriptor_Slot is Positive range 1 .. Max_Blocks;
   subtype Descriptor_Ref  is Natural range 0 .. Max_Blocks;

   type Descriptor is record
      Start  : Offset_Type;
      Length : Size_Type;
      In_Use : Boolean;
      Active : Boolean;
   end record;

   type Descriptor_Array is array (Descriptor_Slot) of Descriptor;
   type Pool_Array is array (Offset_Type) of Byte;

   function Range_Within_Pool
     (Start  : Offset_Type;
      Length : Size_Type) return Boolean is
     (Length > 0 and then Size_Type (Start) - 1 <= Pool_Size - Length);

   function Range_Within_Pool_Runtime
     (Start  : Offset_Type;
      Length : Size_Type) return Boolean is
     (Length > 0 and then Size_Type (Start) - 1 <= Pool_Size - Length);

   function Descriptor_Valid (Start : Offset_Type; Length : Size_Type; Active : Boolean) return Boolean is
       (if Active then (Length = 0 or else Range_Within_Pool (Start, Length)) else True);

   function Descriptors_Disjoint
     (L_Start  : Offset_Type;
      L_Length : Size_Type;
      L_Active : Boolean;
      R_Start  : Offset_Type;
      R_Length : Size_Type;
      R_Active : Boolean) return Boolean is
      (if L_Active
          and then R_Active
          and then Range_Within_Pool (L_Start, L_Length)
          and then Range_Within_Pool (R_Start, R_Length)
       then
          Range_Last (L_Start, L_Length) < R_Start
          or else Range_Last (R_Start, R_Length) < L_Start
       else
          True);

   Pool : Pool_Array
     with Part_Of => State,
          Alignment => Alignment_Bytes;

    function Range_Zeroed
      (Start  : Offset_Type;
       Length : Size_Type) return Boolean is
      (Range_Zeroed_Bounds (Start, Range_Last (Start, Length)));

   function Range_Zeroed_Bounds
     (First : Offset_Type;
      Last  : Offset_Type) return Boolean is
     (for all I in First .. Last => Pool (I) = Byte'(0));

   Descriptors : Descriptor_Array
     with Part_Of => State;

   Initialized : Boolean := False
     with Part_Of => State;

   High_Watermark : Descriptor_Ref := 1
     with Part_Of => State;

   function Active_Disjointness return Boolean is
      (if High_Watermark = 0 then
          True
       else
          (for all I in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) =>
             (for all J in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) =>
                (if I < J then
                   Descriptors_Disjoint
                     (Descriptors (I).Start,
                      Descriptors (I).Length,
                      Descriptors (I).Active,
                      Descriptors (J).Start,
                      Descriptors (J).Length,
                      Descriptors (J).Active)))));

    function State_Consistent return Boolean is
       (Active_Disjointness);

    function Descriptors_Valid return Boolean is
       (for all I in Descriptor_Slot =>
          Descriptor_Valid
            (Descriptors (I).Start,
             Descriptors (I).Length,
             Descriptors (I).Active));

   function Is_Initialized return Boolean is (Initialized);

   function Byte_At (Index : Offset_Type) return Byte is (Pool (Index));

    function Descriptor_Of (Offset : Offset_Type) return Descriptor_Ref
      with Global => (Input => State),
           Post   =>
             (if Descriptor_Of'Result /= 0 then
                 Descriptor_Of'Result <= High_Watermark
                 and then Descriptors (Descriptor_Slot (Descriptor_Of'Result)).Start = Offset
                 and then Descriptors (Descriptor_Slot (Descriptor_Of'Result)).Active
                 and then Descriptors (Descriptor_Slot (Descriptor_Of'Result)).In_Use
                 and then Descriptors (Descriptor_Slot (Descriptor_Of'Result)).Length > 0);

   function Is_Allocated (Offset : Offset_Type) return Boolean is
      (Descriptor_Of (Offset) /= 0);

   procedure Prove_Is_Allocated
     (Offset : Offset_Type)
      with Ghost,
           Global => (Proof_In => State),
           Pre    => Descriptor_Of (Offset) /= 0,
           Post   => Is_Allocated (Offset);

   procedure Prove_Not_Is_Allocated
     (Offset : Offset_Type)
      with Ghost,
           Global => (Proof_In => State),
           Pre    => Descriptor_Of (Offset) = 0,
           Post   => not Is_Allocated (Offset);

    procedure Prove_Range_Within
      (Offset : Offset_Type;
       Usable : Size_Type)
       with Ghost,
            Global => (Proof_In => State),
            Pre    => Descriptor_Of (Offset) /= 0
                      and then Usable = Allocation_Size (Offset)
                      and then Usable > 0;

end Secure_Pool;
