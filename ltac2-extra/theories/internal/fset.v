(*
 * Copyright (C) BlueRock Security Inc. 2022-2024
 *
 * This software is distributed under the terms of the BedRock Open-Source
 * License. See the LICENSE-BedRock file in the repository root for details.
 *)

Require Import bedrock.ltac2.extra.internal.init.
Require Import bedrock.ltac2.extra.internal.std.

(** Minor extensions to [Ltac2.Char] *)
Module FSet.
  Import Ltac2 Init.
  Export Ltac2.FSet.

  Module Import Tags.
    Export Ltac2.FSet.Tags.

    Ltac2 @ external reference_tag : Std.reference FSet.Tags.tag :=
      "coq-core.plugins.ltac2" "fmap_reference_tag".

    Ltac2 @ external evar_tag : evar FSet.Tags.tag :=
      "coq-core.plugins.ltac2" "fmap_evar_tag".
  End Tags.
End FSet.
