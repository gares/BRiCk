(*
 * Copyright (c) 2024 BlueRock Security, Inc.
 * This software is distributed under the terms of the BedRock Open-Source License.
 * See the LICENSE-BedRock file in the repository root for details.
 *)

Require Import bedrock.lang.cpp.parser.prelude.
Require Import bedrock.lang.cpp.parser.lang.

(** * Derived types emitted by cpp2v *)

Module ParserType (Import Lang : PARSER_LANG).
  #[local] Notation globname := (globname' parser_lang).
  #[local] Notation type := (type' parser_lang).

  (*
  Indicate that [underlying] is used to represent alias type [name].
  Enums are treated similarly.
  *)
  Definition Talias (name : globname) {underlying : type} : type :=
    underlying.
  Definition Tunderlying (enum : type) {underlying : type} : type :=
    underlying.
  Definition Tunary_xform (name : bs) (arg : type) {result : type} : type :=
    result.

  Notation Tfunction ty cc var ret args :=
    (normalize_type (Tfunction (@FunctionType ty cc var ret args))) (only parsing).

  Notation Tdecay_type original adjusted := (adjusted) (only parsing).

End ParserType.
