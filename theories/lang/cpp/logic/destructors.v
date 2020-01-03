(*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 *)
Require Import Coq.Lists.List.

From bedrock.lang.cpp Require Import ast semantics.
From bedrock.lang.cpp.logic Require Import
     pred heap_pred wp.

Module Type Deinit.

  Section with_resolve.
    Context {Σ:gFunctors}.
    Variable ti : thread_info.
    Variable ρ : region.

    Local Notation wp := (wp (Σ:=Σ)  ti ρ).
    Local Notation wpe := (wpe (Σ:=Σ) ti ρ).
    Local Notation wp_lval := (wp_lval (Σ:=Σ) ti ρ).
    Local Notation wp_rval := (wp_rval (Σ:=Σ) ti ρ).
    Local Notation wp_xval := (wp_xval (Σ:=Σ) ti ρ).
    Local Notation wpAny := (wpAny (Σ:=Σ) ti ρ).
    Local Notation wpAnys := (wpAnys (Σ:=Σ) ti ρ).
    Local Notation fspec := (fspec (Σ:=Σ)).

    Local Notation mpred := (mpred Σ) (only parsing).
    Local Notation Rep := (Rep Σ) (only parsing).

    (** destructor lists
     *
     *  the opposite of initializer lists, this is just a call to the
     *  destructors *in the right order*
     *)
    Parameter wpd
      : forall (ti : thread_info) (ρ : region)
          (cls : globname) (this : val)
          (init : FieldOrBase * obj_name)
          (Q : mpred), mpred.

    Fixpoint wpds
             (cls : globname) (this : val)
             (dests : list (FieldOrBase * globname))
             (Q : mpred) : mpred :=
      match dests with
      | nil => Q
      | d :: ds => @wpd ti ρ cls this d (wpds cls this ds Q)
      end.

    Axiom wpd_deinit : forall cls this path dn Q,
        Exists dp, Exists fp,
           (_global dn &~ dp **
            _offsetL (offset_for cls path) (_eq this) &~ fp ** ltrue) //\\
                   |> fspec dp (this :: nil) ti (fun _ => Q)
        |-- wpd ti ρ cls this (path, dn) Q.

  End with_resolve.

End Deinit.

Declare Module D : Deinit.

Export D.