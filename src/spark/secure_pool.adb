with System;
with Interfaces;

package body Secure_Pool
  with SPARK_Mode,
       Refined_State => (State => (Pool, Descriptors, Initialized, High_Watermark))
is
   use type Interfaces.Unsigned_8;

   function Range_Last
     (Start  : Offset_Type;
      Length : Size_Type) return Offset_Type is
   begin
      return Offset_Type (Size_Type (Start) + Length - 1);
   end Range_Last;

   function Range_Last_Runtime
     (Start  : Offset_Type;
      Length : Size_Type) return Offset_Type is
   begin
      return Offset_Type (Size_Type (Start) + Length - 1);
   end Range_Last_Runtime;

   function Shifted_Offset_Runtime
     (Base  : Offset_Type;
      Shift : Size_Type) return Offset_Type is
   begin
      return Offset_Type (Size_Type (Base) + Shift);
   end Shifted_Offset_Runtime;

   function Shifted_Offset
     (Base  : Offset_Type;
      Shift : Size_Type) return Offset_Type is
   begin
      return Shifted_Offset_Runtime (Base, Shift);
   end Shifted_Offset;

   procedure Split_Preserves_Disjointness
     (Original_Start   : Offset_Type;
      Original_Length  : Size_Type;
      Left_Start       : Offset_Type;
      Left_Length      : Size_Type;
      Right_Start      : Offset_Type;
      Right_Length     : Size_Type) is
      pragma Unreferenced (Original_Start);
      pragma Unreferenced (Original_Length);
   begin
      pragma Assert (Right_Start = Offset_Type (Size_Type (Left_Start) + Left_Length));
      pragma Assert (Range_Last (Left_Start, Left_Length) < Right_Start);
      pragma Assert
        (Descriptors_Disjoint
           (Left_Start, Left_Length, True,
            Right_Start, Right_Length, True));
   end Split_Preserves_Disjointness;

   procedure Merge_Preserves_Disjointness
     (Left_Start    : Offset_Type;
      Left_Length   : Size_Type;
      Right_Start   : Offset_Type;
      Right_Length  : Size_Type;
      Merged_Start  : Offset_Type;
      Merged_Length : Size_Type) is
      pragma Unreferenced (Left_Start);
      pragma Unreferenced (Left_Length);
   begin
      pragma Assert
        (Descriptors_Disjoint
           (Merged_Start, Merged_Length, True,
            Right_Start, Right_Length, False));
   end Merge_Preserves_Disjointness;

   procedure Unchanged_Descriptor_Preservation
     (Start  : Offset_Type;
      Length : Size_Type;
      Active : Boolean) is
   begin
      pragma Assert (Descriptor_Valid (Start, Length, Active));
   end Unchanged_Descriptor_Preservation;

   function Is_Index_Allocated (Index : Offset_Type) return Boolean is
   begin
      if High_Watermark = 0 then
         return False;
      end if;

      for Slot in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
         if Descriptors (Slot).Active and then Descriptors (Slot).In_Use and then Descriptors (Slot).Length > 0 then
            declare
               First_Pos : constant Size_Type := Size_Type (Descriptors (Slot).Start);
               Last_Pos  : Size_Type;
               Target    : constant Size_Type := Size_Type (Index);
            begin
               if First_Pos - 1 > Pool_Size - Descriptors (Slot).Length then
                  null;
               else
                  Last_Pos := First_Pos + Descriptors (Slot).Length - 1;
                  if Target >= First_Pos and then Target <= Last_Pos then
                     return True;
                  end if;
               end if;
            end;
         end if;
      end loop;
      return False;
   end Is_Index_Allocated;

   function Descriptor_Of (Offset : Offset_Type) return Descriptor_Ref is
   begin
      if High_Watermark = 0 then
         return 0;
      end if;

      for Slot in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
         if Descriptors (Slot).Active
           and then Descriptors (Slot).In_Use
           and then Descriptors (Slot).Length > 0
           and then Descriptors (Slot).Start = Offset
         then
            return Descriptor_Ref (Slot);
         end if;
      end loop;
      return 0;
   end Descriptor_Of;

   function Allocation_Size (Offset : Offset_Type) return Size_Type is
      Slot : constant Descriptor_Ref := Descriptor_Of (Offset);
   begin
      if Slot = 0 then
         return 0;
      end if;
      return Descriptors (Descriptor_Slot (Slot)).Length;
   end Allocation_Size;

   procedure Prove_Is_Allocated
     (Offset : Offset_Type)
   is
      pragma Unreferenced (Offset);
   begin
      null;
   end Prove_Is_Allocated;

   procedure Prove_Not_Is_Allocated
     (Offset : Offset_Type)
   is
      pragma Unreferenced (Offset);
   begin
      null;
   end Prove_Not_Is_Allocated;

   procedure Prove_Range_Within
     (Offset : Offset_Type;
      Usable : Size_Type)
   is
      pragma Unreferenced (Offset);
      pragma Unreferenced (Usable);
   begin
      null;
   end Prove_Range_Within;

   function Allocated_Last (Offset : Offset_Type) return Offset_Type is
      Slot   : constant Descriptor_Ref := Descriptor_Of (Offset);
      Length : Size_Type;
   begin
      if Slot = 0 then
         return Offset;
      end if;
      Length := Descriptors (Descriptor_Slot (Slot)).Length;
      if Length = 0 then
         return Offset;
      end if;
      if not Range_Within_Pool_Runtime (Offset, Length) then
         return Offset;
      end if;
      return Range_Last_Runtime (Offset, Length);
   end Allocated_Last;

   function Old_Alloc_Size (Offset : Offset_Type) return Size_Type is
   begin
      if Is_Initialized and then Is_Allocated (Offset) and then State_Consistent then
         return Allocation_Size (Offset);
      end if;
      return 0;
   end Old_Alloc_Size;

   function Old_Alloc_Last (Offset : Offset_Type) return Offset_Type is
   begin
      if Is_Initialized and then Is_Allocated (Offset) and then State_Consistent then
         return Allocated_Last (Offset);
      end if;
      return Offset;
   end Old_Alloc_Last;

   function Disjoint_From_Actives_Runtime
     (Start    : Offset_Type;
      Length   : Size_Type;
      Excluded : Descriptor_Ref := 0) return Boolean
      with Unreferenced
   is
      Last : Offset_Type;
   begin
      if not Range_Within_Pool_Runtime (Start, Length) then
         return False;
      end if;

      Last := Range_Last_Runtime (Start, Length);

      if High_Watermark = 0 then
         return True;
      end if;

      for S in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
         if Descriptor_Ref (S) /= Excluded
           and then Descriptors (S).Active
           and then Descriptors (S).In_Use
         then
            if not Range_Within_Pool_Runtime (Descriptors (S).Start, Descriptors (S).Length) then
               return False;
            end if;

            declare
               Other_Last : constant Offset_Type :=
                 Range_Last_Runtime (Descriptors (S).Start, Descriptors (S).Length);
            begin
               if not (Last < Descriptors (S).Start or else Other_Last < Start) then
                  return False;
               end if;
            end;
         end if;
      end loop;

      return True;
   end Disjoint_From_Actives_Runtime;

   function Shrink_Tail_Zeroed
     (Offset   : Offset_Type;
      Usable   : Size_Type;
      Old_Size : Size_Type;
      Old_Last : Offset_Type) return Boolean is
   begin
      if Usable >= Old_Size then
         return True;
      end if;

      if Old_Size = 0 then
         return False;
      end if;

      if not Range_Within_Pool (Offset, Old_Size) then
         return False;
      end if;

      if Size_Type (Offset) > Pool_Size - Usable then
         return False;
      end if;

      declare
         Tail_First : constant Offset_Type := Shifted_Offset (Offset, Usable);
      begin
         if Tail_First > Old_Last then
            return False;
         end if;

         return Range_Zeroed_Bounds (Tail_First, Old_Last);
      end;
   end Shrink_Tail_Zeroed;

   function Find_Free_Descriptor return Descriptor_Ref
      with Unreferenced
   is
   begin
        if High_Watermark < Max_Blocks then
          declare
             Candidate : constant Descriptor_Ref := High_Watermark + 1;
         begin
            if not Descriptors (Descriptor_Slot (Candidate)).Active
              and then Descriptors (Descriptor_Slot (Candidate)).Length = 0
            then
               return Candidate;
            end if;
         end;
      end if;

      if High_Watermark = 0 then
         return 1;
      end if;

      for Slot in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
         if not Descriptors (Slot).Active
           and then Descriptors (Slot).Length = 0
         then
            return Descriptor_Ref (Slot);
         end if;
      end loop;
      return 0;
   end Find_Free_Descriptor;

   function Align_Up (Size : Size_Type) return Size_Type
     with Post => Align_Up'Result >= Size
   is
   begin
      if Size mod Alignment_Bytes = 0 then
         return Size;
      end if;
      return Size + (Alignment_Bytes - (Size mod Alignment_Bytes));
   end Align_Up;

   function Find_Best_Fit (Size : Size_Type) return Descriptor_Ref
      with Post =>
        (if Find_Best_Fit'Result /= 0 then
            Find_Best_Fit'Result <= High_Watermark
            and then Descriptors (Descriptor_Slot (Find_Best_Fit'Result)).Length >= Size)
   is
      Best     : Descriptor_Ref := 0;
      Best_Len : Size_Type := Pool_Size;
   begin
      if High_Watermark = 0 then
         return 0;
      end if;

      for Slot in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
         pragma Loop_Invariant (if Best /= 0 then Best <= High_Watermark);
         pragma Loop_Invariant
           (if Best /= 0 then Descriptors (Descriptor_Slot (Best)).Length >= Size);
         if Descriptors (Slot).Active
           and then not Descriptors (Slot).In_Use
             and then Descriptors (Slot).Length >= Size
           then
            if Best = 0 or else Descriptors (Slot).Length < Best_Len then
               Best := Descriptor_Ref (Slot);
               Best_Len := Descriptors (Slot).Length;
            end if;
         end if;
      end loop;
      return Best;
   end Find_Best_Fit;

   function Last_Index (D : Descriptor) return Offset_Type is
      Start_Pos : constant Size_Type := Size_Type (D.Start);
   begin
      if D.Length = 0 then
         return D.Start;
      end if;
      if Start_Pos - 1 > Pool_Size - D.Length then
         return D.Start;
      end if;
      return Offset_Type (Start_Pos + D.Length - 1);
   end Last_Index;

   function Adjacent (Left : Descriptor; Right : Descriptor) return Boolean is
      Left_Last : constant Offset_Type := Last_Index (Left);
   begin
      if Left.Length = 0 or else Right.Length = 0 then
         return False;
      end if;
      if Size_Type (Left_Last) = Pool_Size then
         return False;
      end if;
      return Offset_Type (Size_Type (Left_Last) + 1) = Right.Start;
   end Adjacent;

   procedure Merge (Into : Descriptor_Slot; From : Descriptor_Slot) is
      Into_Start_Before : constant Offset_Type := Descriptors (Into).Start;
      Into_Length_Before : constant Size_Type := Descriptors (Into).Length;
      From_Start_Before : constant Offset_Type := Descriptors (From).Start;
      From_Length_Before : constant Size_Type := Descriptors (From).Length;
   begin
      if Descriptors (Into).Length <= Pool_Size - Descriptors (From).Length then
         Descriptors (Into).Length := Descriptors (Into).Length + Descriptors (From).Length;
      else
         Descriptors (Into).Length := Pool_Size - (Size_Type (Descriptors (Into).Start) - 1);
      end if;
      Descriptors (From).Active := False;
      Descriptors (From).In_Use := False;
      Descriptors (From).Start := 1;
      Descriptors (From).Length := 0;
      if Into_Start_Before = Descriptors (Into).Start
        and then Size_Type (Into_Start_Before) <= Pool_Size - Into_Length_Before
        and then From_Start_Before = Shifted_Offset_Runtime (Into_Start_Before, Into_Length_Before)
        and then Into_Length_Before + From_Length_Before = Descriptors (Into).Length
        and then Range_Within_Pool_Runtime (Into_Start_Before, Into_Length_Before)
        and then Range_Within_Pool_Runtime (From_Start_Before, From_Length_Before)
        and then Range_Within_Pool_Runtime (Descriptors (Into).Start, Descriptors (Into).Length)
      then
         Merge_Preserves_Disjointness
           (Left_Start    => Into_Start_Before,
            Left_Length   => Into_Length_Before,
            Right_Start   => From_Start_Before,
            Right_Length  => From_Length_Before,
            Merged_Start  => Descriptors (Into).Start,
            Merged_Length => Descriptors (Into).Length);
      end if;
   end Merge;

   procedure Trim_High_Watermark is
   begin
      while High_Watermark > 0 loop
         exit when Descriptors (Descriptor_Slot (High_Watermark)).Active;
         High_Watermark := High_Watermark - 1;
      end loop;
   end Trim_High_Watermark;

   procedure Coalesce_Free (Seed : Descriptor_Slot)
      with Unreferenced
   is
      Changed : Boolean := True;
   begin
      if High_Watermark = 0 then
         return;
      end if;

      while Changed loop
         Changed := False;
         if not (Descriptors (Seed).Active and then not Descriptors (Seed).In_Use and then Descriptors (Seed).Length > 0) then
            return;
         end if;

         for J in Descriptor_Slot range 1 .. Descriptor_Slot (High_Watermark) loop
            if Seed /= J
              and then Descriptors (J).Active
              and then not Descriptors (J).In_Use
              and then Descriptors (J).Length > 0
            then
               if Adjacent (Descriptors (Seed), Descriptors (J)) then
                  Merge (Seed, J);
                  Changed := True;
                  exit;
               elsif Adjacent (Descriptors (J), Descriptors (Seed)) then
                  Descriptors (Seed).Start := Descriptors (J).Start;
                  Merge (Seed, J);
                  Changed := True;
                  exit;
               end if;
            end if;
         end loop;
      end loop;

      Trim_High_Watermark;
   end Coalesce_Free;

   procedure Zero_Range (First : Offset_Type; Last : Offset_Type)
     with Pre  => Is_Initialized and then First <= Last,
          Post => Range_Zeroed_Bounds (First, Last)
   is
   begin
      for I in First .. Last loop
         pragma Loop_Invariant (I >= First and then I <= Last);
         pragma Loop_Invariant
           (for all J in First .. Last =>
              (if J < I then Pool (J) = Byte'(0)));
         Pool (I) := Byte'(0);
      end loop;
   end Zero_Range;

   procedure Initialize is
   begin
      Pool := (others => 0);
      Descriptors :=
        (others =>
           (Start  => 1,
            Length => 0,
            In_Use => False,
            Active => False));

      Descriptors (1).Active := True;
      Descriptors (1).In_Use := False;
      Descriptors (1).Start := 1;
      Descriptors (1).Length := Pool_Size;
      High_Watermark := 1;
      Initialized := True;
   end Initialize;

   procedure Allocate
     (Size   : Size_Type;
      Offset : out Offset_Type;
      Usable : out Size_Type;
      Status : out Status_Code)
   is
      Chosen : Descriptor_Ref;
      Need   : Size_Type;
   begin
      Offset := 1;
      Usable := 0;

      if not Initialized then
         Status := Not_Initialized;
         return;
      end if;


      if Size = 0 then
         Status := Invalid_Size;
         return;
      end if;

      Need := Align_Up (Size);

      Chosen := Find_Best_Fit (Need);
      if Chosen = 0 then
         Status := Out_Of_Memory;
         return;
      end if;

      declare
         Slot : constant Descriptor_Slot := Descriptor_Slot (Chosen);
      begin
         Descriptors (Slot).In_Use := True;
         Offset := Descriptors (Slot).Start;
         Usable := Allocation_Size (Offset);

         if Usable < Size then
            Status := Out_Of_Memory;
            return;
         end if;

         if Usable > 0 then
            Prove_Range_Within (Offset, Usable);
         end if;

         if Usable > 0 then
            Zero_Range (Offset, Range_Last_Runtime (Offset, Usable));
         end if;

           end;

      Status := Ok;
   end Allocate;

   procedure Zero_Allocation
     (Offset : Offset_Type;
      Status : out Status_Code)
   is
      Slot : constant Descriptor_Ref := Descriptor_Of (Offset);
   begin
      if not Initialized then
         Status := Not_Initialized;
         return;
      end if;


      if Slot = 0 then
         Status := Invalid_Pointer;
         return;
      end if;

      declare
         E : constant Offset_Type := Allocated_Last (Offset);
      begin
         Zero_Range (Offset, E);
      end;
      Status := Ok;
   end Zero_Allocation;

   procedure Free
     (Offset        : Offset_Type;
      Cleared_First : out Offset_Type;
      Cleared_Last  : out Offset_Type;
      Status        : out Status_Code)
   is
      Slot : constant Descriptor_Ref := Descriptor_Of (Offset);
   begin
      Cleared_First := 1;
      Cleared_Last := 1;

      if not Initialized then
         Status := Not_Initialized;
         return;
      end if;


      if Slot = 0 then
         Status := Invalid_Pointer;
         return;
      end if;

      declare
         Idx : constant Descriptor_Slot := Descriptor_Slot (Slot);
      begin
         Cleared_First := Offset;
         Cleared_Last := Allocated_Last (Offset);

         Zero_Range (Cleared_First, Cleared_Last);

         Descriptors (Idx).In_Use := False;

      end;

      Status := Ok;
   end Free;

   procedure Reallocate
     (Offset     : Offset_Type;
      New_Size   : Size_Type;
      New_Offset : out Offset_Type;
      Usable     : out Size_Type;
      Status     : out Status_Code)
   is
      Slot : constant Descriptor_Ref := Descriptor_Of (Offset);
      Need : Size_Type;
   begin
      New_Offset := 1;
      Usable := 0;

      if not Initialized then
         Status := Not_Initialized;
         return;
      end if;


      if New_Size = 0 then
         Status := Invalid_Size;
         return;
      end if;

      Need := Align_Up (New_Size);

      if Slot = 0 then
         Status := Invalid_Pointer;
         return;
      end if;

      declare
         Old_Slot : constant Descriptor_Slot := Descriptor_Slot (Slot);
         Old_Size : constant Size_Type := Descriptors (Old_Slot).Length;
       begin
               if Need <= Old_Size then
                   New_Offset := Offset;
                   Usable := Allocation_Size (New_Offset);
                   if Usable < New_Size then
                      Status := Out_Of_Memory;
                      return;
                    end if;

                  if Usable > 0 then
                     Prove_Range_Within (New_Offset, Usable);
                  end if;

                  Status := Ok;
                  return;
               end if;

          null;
      end;

      declare
         Alloc_Status : Status_Code;
         Fresh_Offset : Offset_Type;
         Fresh_Usable : Size_Type;
      begin
           Allocate (Need, Fresh_Offset, Fresh_Usable, Alloc_Status);
           if Alloc_Status /= Ok then
              Status := Alloc_Status;
              return;
           end if;

           if Fresh_Usable > 0 then
              Prove_Range_Within (Fresh_Offset, Fresh_Usable);
           end if;

          declare
             Old_Ref  : constant Descriptor_Ref := Descriptor_Of (Offset);
             Old_Slot : Descriptor_Slot;
            Count    : Size_Type;
          begin
            if Old_Ref = 0 then
               Status := Invalid_Pointer;
               return;
            end if;

            Old_Slot := Descriptor_Slot (Old_Ref);
            Count := Descriptors (Old_Slot).Length;

            if Count > 0 then
               for K in 0 .. Count - 1 loop
                  declare
                     Src_Pos : constant Natural := Natural (Size_Type (Offset)) + K;
                     Dst_Pos : constant Natural := Natural (Size_Type (Fresh_Offset)) + K;
                  begin
                     if Src_Pos <= Pool_Size and then Dst_Pos <= Pool_Size then
                        Pool (Offset_Type (Dst_Pos)) := Pool (Offset_Type (Src_Pos));
                     end if;
                  end;
               end loop;
            end if;
          end;

         declare
            C_First : Offset_Type;
            C_Last  : Offset_Type;
            Free_Status : Status_Code;
         begin
            Free (Offset, C_First, C_Last, Free_Status);
            pragma Unreferenced (C_First);
            pragma Unreferenced (C_Last);
            if Free_Status /= Ok then
               Status := Free_Status;
               return;
            end if;
         end;

              New_Offset := Fresh_Offset;
               Usable := Allocation_Size (New_Offset);
              if Usable < New_Size then
                 Status := Out_Of_Memory;
                 return;
               end if;

              if Usable > 0 then
                 Prove_Range_Within (New_Offset, Usable);
              end if;

              Status := Ok;
          end;
   end Reallocate;

   function Raw_Base_Address return System.Address
     with SPARK_Mode => Off
   is
   begin
      return Pool'Address;
   end Raw_Base_Address;
end Secure_Pool;
