type primitive =
  | CompareEq
  | CompareLt
  | CompareGt
  | CompareLe
  | CompareGe
  | CompareNe
  | NatAdd
  | NatMul
  | NatSub
  | NatDiv
  | NatMod
  | FloatAdd
  | FloatMul
  | FloatSub
  | FloatDiv
  | FloatPow
  | FloatNeg
  | FloatOfNat
  | NatOfFloat
  | FloatSqrt
  | FloatAtan
  | FloatAtan2
  | IntAdd
  | IntMul
  | IntSub
  | IntDiv
  | IntMod
  | IntNeg
  | IntOfNat
  | NatOfInt
  | FloatOfInt
  | IntOfFloat
  | ToString

(* Keep this list up to date with the type above, otherwise the missing primitives will not be loaded *)
let primitives =
  [
    CompareEq;
    CompareLt;
    CompareGt;
    CompareLe;
    CompareGe;
    CompareNe;
    NatAdd;
    NatMul;
    NatSub;
    NatDiv;
    NatMod;
    FloatAdd;
    FloatMul;
    FloatSub;
    FloatDiv;
    FloatPow;
    FloatNeg;
    FloatOfNat;
    NatOfFloat;
    FloatSqrt;
    FloatAtan;
    FloatAtan2;
    IntAdd;
    IntMul;
    IntSub;
    IntDiv;
    IntMod;
    IntNeg;
    IntOfNat;
    NatOfInt;
    FloatOfInt;
    IntOfFloat;
    ToString;
  ]

let primitive_name = function
  | CompareEq -> "__compare_eq__"
  | CompareLt -> "__compare_lt__"
  | CompareGt -> "__compare_gt__"
  | CompareLe -> "__compare_le__"
  | CompareGe -> "__compare_ge__"
  | CompareNe -> "__compare_ne__"
  | NatAdd -> "__nat_add__"
  | NatMul -> "__nat_mul__"
  | NatSub -> "__nat_sub__"
  | NatDiv -> "__nat_div__"
  | NatMod -> "__nat_mod__"
  | FloatAdd -> "__float_add__"
  | FloatMul -> "__float_mul__"
  | FloatSub -> "__float_sub__"
  | FloatDiv -> "__float_div__"
  | FloatPow -> "__float_pow__"
  | FloatNeg -> "__float_neg__"
  | FloatOfNat -> "__float_of_nat__"
  | NatOfFloat -> "__nat_of_float__"
  | FloatSqrt -> "__float_sqrt__"
  | FloatAtan -> "__float_atan__"
  | FloatAtan2 -> "__float_atan2__"
  | IntAdd -> "__int_add__"
  | IntMul -> "__int_mul__"
  | IntSub -> "__int_sub__"
  | IntDiv -> "__int_div__"
  | IntMod -> "__int_mod__"
  | IntNeg -> "__int_neg__"
  | IntOfNat -> "__int_of_nat__"
  | NatOfInt -> "__nat_of_int__"
  | FloatOfInt -> "__float_of_int__"
  | IntOfFloat -> "__int_of_float__"
  | ToString -> "to_string"
