(*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier: LGPL-2.1 WITH BedRock Exception for use over network, see repository root for details.
 *)
Require Import Coq.Lists.List.

From iris.base_logic.lib Require Import
     fancy_updates invariants cancelable_invariants wsat.
Import invG.

From bedrock Require Import ChargeCompat.
From bedrock.lang.cpp Require Import ast semantics.
From bedrock.lang.cpp.logic Require Import
     pred path_pred heap_pred wp call.

Local Open Scope Z_scope.

Section with_Σ.
  Context `{Σ : cpp_logic thread_info, !invG Σ} {resolve:genv}.
  Variables (M : coPset) (ti : thread_info) (ρ : region).

  Local Notation wp_prval := (wp_prval (resolve:=resolve) M ti ρ).
  Local Notation wp_args := (wp_args (σ:=resolve) M ti ρ).

  Local Notation glob_def := (glob_def resolve) (only parsing).
  Local Notation eval_unop := (@eval_unop resolve) (only parsing).
  Local Notation eval_binop := (@eval_binop resolve) (only parsing).
  Local Notation size_of := (@size_of resolve) (only parsing).
  Local Notation align_of := (@align_of resolve) (only parsing).
  Local Notation primR := (@primR _ _ resolve) (only parsing).
  Local Notation anyR := (@anyR _ _ resolve) (only parsing).

  Definition wrap_shift (F : (val -> mpred) -> mpred) (Q : val -> mpred) : mpred :=
    Exists mid, (|={M,mid}=> F (fun result => |={mid,M}=> Q result))%I.

  (* Builtins for Atomic operations. We follow those provided by GCC.
   * https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html
   * LLVM also provides similar builtins.
   * http://llvm.org/docs/Atomics.html#libcalls-atomic
   *)
  (****** Wp Semantics for atomic operations
   * These are given in the style of function call axioms
   *)
  Parameter wp_atom :
      forall {resolve:genv}, coPset -> thread_info ->
        AtomicOp -> type (* the access type of the atomic operation *) ->
        list val -> (val -> mpred) -> mpred.

  Local Notation wp_atom' := (@wp_atom resolve M ti) (only parsing).

  Definition pointee_type (t : type) : option type :=
    match t with
    | Tpointer t => Some t
    | _ => None
    end.

  Definition get_acc_type (ao : AtomicOp) (ret : type) (ts : list type) : option type :=
    match ts with
    | t :: _ => pointee_type (erase_qualifiers t)
    | _ => None
    end.

  (* note that this rule captures all of the interesting reasoning about atomics
   * through the use of [wrap_shift]
   *)
  (* note(hai)
    This allows opening general Iris invariants around atomic operations.
    This means resource trading can happen around atomic accesses.
    This does not hold for non-SC accesses: in general, non-SC accesses can only
    trade objective resources: those whose meaning does not depend on a thread's
    view. This is because non-SC accesses may not provide enough synchronization.

    Arbitrary resource trading holds for sequential consistency, but sequential
    consistency is only guaranteed if all accesses in a program are also SC.

    We conjecture that if arbitrary resource trading holds for SC-only locations
    even in the present of other non-SC locations. Intuitively, this is because,
    assuming that there is no location that has mixed SC and non-SC accesses,
    the total order S among accesses to SC locations must be consistent with the
    happens-before relation, so every access is synchronized with the next one
    in S and thus can observe any previous changes made to the invariant.

    In hardware, the synchonization is backed up by the fact that SC accesses
    are compiled such that there is at least a full barrier betwen an SC load
    and an SC store.
    See https://www.cl.cam.ac.uk/~pes20/cpp/cpp0xmappings.html *)
  Axiom wp_prval_atomic: forall ao es ty Q,
      match get_acc_type ao ty (map (fun x => type_of (snd x)) es) with
      | None => lfalse
      | Some acc_type =>
        wp_args es (fun (vs : list val) (free : FreeTemps) =>
          wrap_shift (wp_atom' ao acc_type vs) (fun v => Q v free))
      end
      |-- wp_prval (Eatomic ao es ty) Q.

  (* Memory Ordering Patterns: Now we only have _SEQ_CST *)
  Definition _SEQ_CST := Vint 5.

  (* note: the following axioms have laters earlier than they should be.
   * it is ok, because these are provable given the timelessness of points
   * to, but in truth, these should be proven from more primitive axioms.
   *)

  (* note(gmm): these are used for reading and writing values shared between
   * threads.
   * note(gmm): these look exactly like the standard read and write assertions
   * because all of the invariant reasoning is encapsulated in [wp_shift].
   *)

  (* (hai) Semantics of SEQ_CST (SC) accesses:
    - SC load has at least ACQUIRE load semantics.
    - SC store has at least RELEASE store semantics.
    - Additionally, there exists a total order S among all SC accesses
      (across all locations) and SC fences (REL_ACQ fences).
      S needs to respect strong happens-before [shb] but not happens-before
      [hb]. The two coincide when there is no mixing of SC and non-SC accesses
      to the same location.
      Not requiring S to respect hb allows for more optimizations on some
      architecture (see [RC11], and [C++draft,atomics#6])
      [shb] : https://eel.is/c++draft/intro.races#12
      [hb]  : https://eel.is/c++draft/intro.races#10
      [C++draft, atomics#6] : https://eel.is/c++draft/atomics#order-6
      [RC11] : https://plv.mpi-sws.org/scfix/

    Mixing SC and non-SC accesses is not recommended, because then even the
    usually expected semantics of SC accesses are not guaranteed (see below). *)

  (* An SC load Ld reads a value that is written by:
    (1) the latest SEQ_CST store that is immediately before Ld in S, *or*
    (2) some non-SC store that is racing with (does not happen-before) any
      stores that is before Ld in S.
    To have the expected SC behavior (1), we need to exclude (2) by simply
    require the location to be used with SC access only.
    In other words, the following rule only holds for SC-only locations. *)
  (* An SC load on the SC-only location p reads the latest value v of p. *)
  Axiom wp_atom_load_cst :
    forall q memorder (acc_type:type) (p : val) (Q : val -> mpred),
      [| memorder = _SEQ_CST |] **
      |> (Exists v,  _at (_eqv p) (primR acc_type q v) **
                    (_at (_eqv p) (primR acc_type q v) -* Q v))
      |-- wp_atom' AO__atomic_load_n acc_type (p :: memorder :: nil) Q.

  (* An SC store writes the latest value, unless there are racing (no hb)
    non-SC stores. The following rule only holds for SC-only locations. *)
  (* An SC store on the SC-only location p writes the latest value v of p. *)
  Axiom wp_atom_store_cst :
    forall memorder acc_type p Q v,
      [| memorder = _SEQ_CST |] **
      [| has_type v acc_type |] **
      |> ( _at (_eqv p) (anyR acc_type 1) **
          (_at (_eqv p) (primR acc_type 1 v) -* Q Vundef))
      |-- wp_atom' AO__atomic_store_n acc_type (p :: memorder :: v :: nil) Q.

  (* The following rule holds for SC-only locations, or no-racing-store
    locations.
    No-racing-store locations are those whose stores are properly synchronized
    among themselves and with RMWs. For example, RMW-only locations are
    no-racing-store locations. RELEASE-ACQUIRE RMWs on a RMW-only location
    always read and write the latest value. *)
  (* An SC atomic exchange sets the latest value to v and returns the previous
    latest value w *)
  Axiom wp_atom_exchange_n_cst :
    forall memorder acc_type p Q w v,
      [| memorder = _SEQ_CST |] **
      [| has_type v acc_type |] **
      |> ( _at (_eqv p) (primR acc_type 1 w) **
          (_at (_eqv p) (primR acc_type 1 v) -* Q w))
      |-- wp_atom' AO__atomic_exchange_n acc_type (p :: memorder :: v :: nil) Q.

  (* Again, all of the RMWs rules only read and write latest values if the
  location is SC-only or no-racing-store. *)
  Axiom wp_atom_exchange_cst :
    forall memorder acc_type p Q v new_p q ret new_v,
      [| memorder = _SEQ_CST |] **
      |> ((* latest value of p is v *)
          _at (_eqv p) (primR acc_type 1 v) **
          (* new value new_v for p *)
          _at (_eqv new_p) (primR acc_type q new_v) **
          (* placeholder for the original value of p *)
          _at (_eqv ret) (anyR acc_type 1) **
         ((* latest value updated to new_v *)
          _at (_eqv p) (primR acc_type 1 new_v) **
          _at (_eqv new_v) (primR acc_type q new_v) **
          (* ret stores the previous latest value v *)
          _at (_eqv ret) (primR acc_type 1 v) -* Q v))
      |-- wp_atom' AO__atomic_exchange acc_type (p :: memorder :: new_p :: ret :: nil) Q.

  (* A successful SC compare and exchange n *)
  (* It succeeds because the location p has the expected value v, which is
    stored in expected. This holds true for both weak and strong CMPXCHG, thus
    weak can be any bool. *)
  Axiom wp_atom_compare_exchange_n_cst_suc :
    forall p expected_p desired weak succmemord failmemord Q ty v b,
      [| weak = Vbool b |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      |> ((* placeholder for the expected value, which is v *)
          _at (_eqv expected_p) (primR ty 1 v) **
          (* latest value of p, which is also v, because this is successful *)
          _at (_eqv p) (primR ty 1 v) **
          ((_at (_eqv expected_p) (primR ty 1 v) **
          (* afterwards, val_p has value desired *)
            _at (_eqv p) (primR ty 1 desired)) -* Q (Vbool true)))
      |-- wp_atom' AO__atomic_compare_exchange_n ty
                  (* TODO(hai): I don't see why the order of arguments is like this *)
                  (p::succmemord::expected_p::failmemord::desired::weak::nil) Q.

  (* A failed SC strong compare exchange, which tell us that the values are
    truly different. *)
  Axiom wp_atom_compare_exchange_n_cst_fail :
    forall p val_p desired weak succmemord failmemord Q
           (ty : type) v expected_v,
      [| weak = Vbool false |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      (* we know that the values are different *)
      [| v <> expected_v |] **
      |> ((* before, val_p stores the value expected_v to be compared *)
          _at (_eqv val_p) (primR ty 1 expected_v) **
          _at (_eqv p) (primR ty 1 v) **
          (* afterwards, val_p stores the value read v, which is the latest one
              due to failmemord being SC *)
          ((_at (_eqv val_p) (primR ty 1 v) **
            _at (_eqv p) (primR ty 1 v)) -* Q (Vbool false)))
      |-- wp_atom' AO__atomic_compare_exchange_n ty
                  (p::succmemord::val_p::failmemord::desired::weak::nil) Q.

  (* An SC weak compare exchange. This rule combines the postcondition for both
    success and failure case (using a conjunction). Since a weak CMPXCHG can
    fail spuriously, we do not know that the values are different. *)
  Axiom wp_atom_compare_exchange_n_cst_weak :
    forall p expected_p expected_v desired weak succmemord failmemord Q ty v,
      [| weak = Vbool true |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      |> (_at (_eqv expected_p) (primR ty 1 expected_v) **
          _at (_eqv p) (primR ty 1 v) **
          (* postcond for success case *)
          (((_at (_eqv expected_p) (primR ty 1 expected_v) **
             _at (_eqv p) (primR ty 1 desired) **
             [| v = expected_v |]) -* Q (Vbool true)) //\\
          (* postcond for failure case *)
           ((_at (_eqv expected_p) (primR ty 1 v) **
             _at (_eqv p) (primR ty 1 v)) -* Q (Vbool false))))
      |-- wp_atom' AO__atomic_compare_exchange_n ty
                  (p::succmemord::expected_p::failmemord::desired::weak::nil) Q.

  (* An SC compare and exchange *)
  Axiom wp_atom_compare_exchange_cst_suc :
    forall q p expected_p desired_p weak succmemord failmemord Q
      (ty : type)
      expected desired b,
      [| weak = Vbool b |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      |> ((* before, we know that p and expected_p have the same value *)
          (_at (_eqv expected_p) (primR ty 1 expected) **
           _at (_eqv desired_p) (primR ty q desired) **
           _at (_eqv p) (primR ty 1 expected)) **
          (* afterwards, p is updated to desired *)
         ((_at (_eqv expected_p) (primR ty 1 expected) **
           _at (_eqv desired_p) (primR ty q desired) **
           _at (_eqv p) (primR ty 1 desired)) -* Q (Vbool true)))
      |-- wp_atom' AO__atomic_compare_exchange ty
                  (p::succmemord::expected_p::failmemord::desired_p::weak::nil) Q.

  Axiom wp_atom_compare_exchange_cst_fail :
    forall q p expected_p desired_p weak succmemord failmemord Q
      (ty : type)
      actual expected desired,
      expected <> actual ->
      [| weak = Vbool false |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      |> ((_at (_eqv expected_p) (primR ty 1 expected) **
           _at (_eqv desired_p) (primR ty q desired) **
           _at (_eqv p) (primR ty 1 actual)) **
          ((_at (_eqv expected_p) (primR ty 1 actual) **
            _at (_eqv desired_p) (primR ty q desired) **
            _at (_eqv p) (primR ty 1 actual)) -* Q (Vbool false)))
      |-- wp_atom' AO__atomic_compare_exchange ty
                  (p::succmemord::expected_p::failmemord::desired_p::weak::nil) Q.

  Axiom wp_atom_compare_exchange_cst_weak :
    forall q p expected_p desired_p weak succmemord failmemord Q
      (ty : type)
      actual expected desired,
      [| weak = Vbool true |] **
      [| succmemord = _SEQ_CST |] ** [| failmemord = _SEQ_CST |] **
      |> ((_at (_eqv expected_p) (primR ty 1 expected) **
           _at (_eqv desired_p) (primR ty q desired) **
           _at (_eqv p) (primR ty 1 actual)) **
          (((_at (_eqv expected_p) (primR ty 1 expected) **
             _at (_eqv desired_p) (primR ty q desired) **
             _at (_eqv p) (primR ty 1 desired)) **
             [| actual = expected |] -* Q (Vbool true)) //\\
           ((_at (_eqv expected_p) (primR ty 1 actual) **
             _at (_eqv desired_p) (primR ty q desired) **
             _at (_eqv p) (primR ty 1 actual)) -* Q (Vbool false))))
      |-- wp_atom' AO__atomic_compare_exchange ty
                  (p::succmemord::expected_p::failmemord::desired_p::weak::nil) Q.

  (** Atomic operations use two's complement arithmetic. This
  definition presupposes that the [n_i] satisfy [n_i = n_i `mod` 2 ^
  bitsZ sz], which the following axioms ensure via typing
  side-conditions. *)
  Definition atomic_eval (sz : bitsize) (sgn : signed)
      (op : Z -> Z -> Z) (n1 n2 : Z) : Z :=
    let r := op n1 n2 in
    if sgn is Signed then to_signed sz r else to_unsigned sz r.

  Local Notation Unfold x tm :=
    ltac:(let H := eval unfold x in tm in exact H) (only parsing).
  Local Notation at_eval sz sgn op n1 n2 :=
    (Unfold atomic_eval (atomic_eval sz sgn op n1 n2)) (only parsing).

  (* atomic fetch and xxx rule *)
  Definition wp_fetch_xxx_cst (ao : AtomicOp) (op : Z -> Z -> Z) : Prop :=
    forall p arg memorder Q sz sgn,
      let acc_type := Tint sz sgn in
      [| memorder = _SEQ_CST |] **
      [| has_type (Vint arg) acc_type |] **
      |>  (Exists n,
            _at (_eqv p) (primR acc_type 1 (Vint n)) **
            let n' := at_eval sz sgn op n arg in
            _at (_eqv p) (primR acc_type 1 (Vint n')) -* Q (Vint n))
      |-- wp_atom' ao acc_type (p::memorder::Vint arg::nil) Q.

  Local Notation fetch_xxx ao op :=
    (Unfold wp_fetch_xxx_cst (wp_fetch_xxx_cst ao op)) (only parsing).

  Let nand (a b : Z) : Z := Z.lnot (Z.land a b).

  Axiom wp_atom_fetch_add_cst  : fetch_xxx AO__atomic_fetch_add  Z.add.
  Axiom wp_atom_fetch_sub_cst  : fetch_xxx AO__atomic_fetch_sub  Z.sub.
  Axiom wp_atom_fetch_and_cst  : fetch_xxx AO__atomic_fetch_and  Z.land.
  Axiom wp_atom_fetch_xor_cst  : fetch_xxx AO__atomic_fetch_xor  Z.lxor.
  Axiom wp_atom_fetch_or_cst   : fetch_xxx AO__atomic_fetch_or   Z.lor.
  Axiom wp_atom_fetch_nand_cst : fetch_xxx AO__atomic_fetch_nand nand.

  (* atomic xxx and fetch rule *)
  Definition wp_xxx_fetch_cst (ao : AtomicOp) (op : Z -> Z -> Z) : Prop :=
    forall p arg memorder Q sz sgn,
      let acc_type := Tint sz sgn in
      [| memorder = _SEQ_CST |] **
      [| has_type (Vint arg) acc_type |] **
      |> (Exists n,
          _at (_eqv p) (primR acc_type 1 (Vint n)) **
          let n' := at_eval sz sgn op n arg in
          _at (_eqv p) (primR acc_type 1 (Vint n')) -* Q (Vint n'))
      |-- wp_atom' ao acc_type (p::memorder::Vint arg::nil) Q.

  Local Notation xxx_fetch ao op :=
    (Unfold wp_xxx_fetch_cst (wp_xxx_fetch_cst ao op)) (only parsing).

  Axiom wp_atom_add_fetch_cst  : xxx_fetch AO__atomic_add_fetch  Z.add.
  Axiom wp_atom_sub_fetch_cst  : xxx_fetch AO__atomic_sub_fetch  Z.sub.
  Axiom wp_atom_and_fetch_cst  : xxx_fetch AO__atomic_and_fetch  Z.land.
  Axiom wp_atom_xor_fetch_cst  : xxx_fetch AO__atomic_xor_fetch  Z.lxor.
  Axiom wp_atom_or_fetch_cst   : xxx_fetch AO__atomic_or_fetch   Z.lor.
  Axiom wp_atom_nand_fetch_cst : xxx_fetch AO__atomic_nand_fetch nand.

End with_Σ.
