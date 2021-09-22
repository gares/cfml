(** This file is intended to be used as [Require] by every file
    generated by CFMLC. *)

Set Implicit Arguments.
From TLC Require Import LibTactics.
From CFML Require Import WPBuiltin SepBase SepLifted.


(* ********************************************************************** *)
(** ** Additional definitions *)

(** Type of representation predicates *)

Definition htype (A a:Type) : Type :=
  A -> a -> hprop.

(* ********************************************************************** *)

(** We hardcode the fact that for every OCaml type translated to an Coq type
    satisfyies the typeclass Enc. This is essentially equivalent to what
    the older version CFML was doing, because it was reflecting OCaml polymorphic
    type variables as Coq polymorphic type variable, without imposing any
    constraint. This quantification over Type was justified in Section 6.4
    from Arthur Charguéraud's PhD thesis. *)

Parameter Enc_any : forall A, Enc A.


(* ********************************************************************** *)
(** ** Tooling for registering a CF with each toplevel definition *)

(** Registration of CF axioms for use by [xwp] tactic.
    CFMLC generates lines of the form
[[
    Hint Extern 1 (RegisterCF myfunc) => WPHeader_Provide myfunc__cf.
]]

   Then the [xwp] tactic can call [ltac_database_get database_cf myfunc]
   to retrieve [myfunc__cf] as hypothesis as head of the goal. *)

Declare Scope wptactics_scope.
Open Scope wptactics_scope.

Definition database_cf := True.

Notation "'WPHeader_Register_CF' T" := (ltac_database (boxer database_cf) (boxer T) _)
  (at level 69, T at level 0) : wptactics_scope.

Ltac WPHeader_Provide T := Provide T.


(* ********************************************************************** *)
(** ** Tooling for registering a Spec with each toplevel definition *)

Definition database_spec := True. (* TODO: check it needs to be here *)

