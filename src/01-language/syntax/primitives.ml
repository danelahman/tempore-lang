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
  | ToString -> "to_string"
