(*
 * The following code is derived from code original to the
 * Iris project. That original code is
 *
 *	Copyright Iris developers and contributors
 *
 * and used according to the following license.
 *
 *	SPDX-License-Identifier: BSD-3-Clause
 *
 * Original Iris License:
 * https://gitlab.mpi-sws.org/iris/iris/-/blob/26ebf1eed7d99a02683996e1b06c5f28870bf0a0/LICENSE-CODE
 *)

(* Load both ssreflect and stdpp, using the same settings as Iris. *)
From Coq.ssr Require Export ssreflect.
From stdpp Require Export prelude.
Global Open Scope general_if_scope.
Global Set SsrOldRewriteGoalsOrder. (* See Coq issue #5706 *)
Ltac done := stdpp.tactics.done.

(* TODO: to enable after the Iris bump. *)
(*
(** Iris itself and many dependencies still rely on this coercion. *)
Coercion Z.of_nat : nat >-> Z.

(* No Hint Mode set in stdpp because of Coq bugs #5735 and #9058, only
fixed in Coq >= 8.12, which Iris depends on. *)
Global Hint Mode Equiv ! : typeclass_instances. *)
