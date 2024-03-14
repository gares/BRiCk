(*
 * Copyright (c) 2020-2024 BedRock Systems, Inc.
 * This software is distributed under the terms of the BedRock Open-Source License.
 * See the LICENSE-BedRock file in the repository root for details.
 *)
Require Import bedrock.prelude.base.
Require Import bedrock.lang.cpp.syntax.names.
Require Import bedrock.lang.cpp.syntax.types.
Require Import bedrock.lang.cpp.syntax.expr.
Require Import bedrock.prelude.bytestring.

Set Primitive Projections.

Variant SwitchBranch : Set :=
| Exact (_ : Z)
| Range (_ _ : Z).
#[global] Instance: EqDecision SwitchBranch.
Proof. solve_decision. Defined.

Inductive VarDecl' {obj_name type Expr : Set} : Set :=
| Dvar (name : localname) (_ : type) (init : option Expr)
| Ddecompose (_ : Expr) (anon_var : ident) (_ : list VarDecl')
  (* initialization of a function-local [static]. See https://eel.is/c++draft/stmt.dcl#3 *)
| Dinit (thread_safe : bool) (name : obj_name) (_ : type) (init : option Expr).
#[global] Arguments VarDecl' _ _ _ : clear implicits, assert.
#[global] Instance VarDecl_eq_dec {obj_name type Expr : Set} `{!EqDecision obj_name, !EqDecision type, !EqDecision Expr} :
  EqDecision (VarDecl' obj_name type Expr).
Proof.
  refine (fix dec (x y : VarDecl' obj_name type Expr) : {x = y} + {x <> y} :=
            let _ : EqDecision _ := dec in
            match x as x , y as y return {x = y} + {x <> y} with
            | Ddecompose xi xx xs , Ddecompose yi yx ys =>
              match decide (xs = ys) with
              | left pf => match decide (xi = yi /\ xx = yx) with
                          | left pf' => left _
                          | right pf' => right _
                          end
              | right pf => right _
              end
            | Dvar x tx ix , Dvar y ty iy =>
              match decide (x = y /\ tx = ty /\ ix = iy) with
              | left pf => left _
              | right pf => right _
              end
            | Dinit xts x tx ix , Dinit yts y ty iy =>
              match decide (xts = yts /\ x = y /\ tx = ty /\ ix = iy) with
              | left pf => left _
              | right pf => right _
              end
            | _ , _ => right _
            end); try solve [ intro pf; inversion pf ].
  { destruct pf as [ ? [ ? ? ] ].
    subst; reflexivity. }
  { intro X; inversion X; apply pf; tauto. }
  { destruct pf' as [ ? ? ]; f_equal; assumption. }
  { intro zz; inversion zz; apply pf'; tauto. }
  { intro. apply pf. inversion H; auto. }
  { by destruct pf as [ -> [ -> [ -> -> ] ] ]. }
  { intro. apply pf. inversion H; tauto. }
Defined.
Notation VarDecl := (VarDecl' obj_name decltype Expr).

Inductive Stmt' {obj_name type Expr : Set} : Set :=
| Sseq    (_ : list Stmt')
| Sdecl   (_ : list (VarDecl' obj_name type Expr))

| Sif     (_ : option (VarDecl' obj_name type Expr)) (_ : Expr) (_ _ : Stmt')
| Swhile  (_ : option (VarDecl' obj_name type Expr)) (_ : Expr) (_ : Stmt')
| Sfor    (_ : option Stmt') (_ : option Expr) (_ : option Expr) (_ : Stmt')
| Sdo     (_ : Stmt') (_ : Expr)

| Sswitch (_ : option (VarDecl' obj_name type Expr)) (_ : Expr) (_ : Stmt')
| Scase   (_ : SwitchBranch)
| Sdefault

| Sbreak
| Scontinue

| Sreturn (_ : option Expr)

| Sexpr   (_ : Expr)

| Sattr (_ : list ident) (_ : Stmt')

| Sasm (_ : bs) (volatile : bool)
       (inputs : list (ident * Expr))
       (outputs : list (ident * Expr))
       (clobbers : list ident)

| Slabeled (_ : ident) (_ : Stmt')
| Sgoto (_ : ident)
| Sunsupported (_ : bs).
#[global] Arguments Stmt' _ _ _ : clear implicits, assert.
#[global] Instance Stmt_eq_dec {obj_name type Expr : Set} `{!EqDecision obj_name, !EqDecision type, !EqDecision Expr} :
  EqDecision (Stmt' obj_name type Expr).
Proof.
  rewrite /RelDecision /Decision.
  fix IHs 1.
  rewrite -{1}/(EqDecision _) in IHs.
  decide equality; try solve_trivial_decision.
Defined.
Notation Stmt := (Stmt' obj_name decltype Expr).

Definition Sskip {obj_name type Expr : Set} : Stmt' obj_name type Expr := Sseq nil.

Variant OrDefault {t : Set} : Set :=
| Defaulted
| UserDefined (_ : t).
Arguments OrDefault : clear implicits.

#[global] Instance OrDefault_eq_dec: forall {T: Set}, EqDecision T -> EqDecision (OrDefault T).
Proof. solve_decision. Defined.
