(** This file is intended to be used as [Require] by every file
    that contains proofs with respect to characteristic formulae
    generated by CFMLC. *)

Require Export LibTactics LibCore LibListZ LibInt LibSet LibMap.
Require Export CFHeader (* CFBuiltin TODO? *) CFTactics.
(* Open Scope heap_scope. *)



(* ********************************************************************** *)
(* ********************************************************************** *)
(* ********************************************************************** *)
(** * Additional notation for more concise specifications at scale. *)

(** The following notation is only used for parsing. *)

(** [\[= v]] is short for [fun x => \[x = v]].
    It typically appears in a postcondition, after then [POST] keyword. *)

Notation "\[= v ]" := (fun x => \[x = v])
  (at level 0, only parsing) : triple_scope.

(** [H1 ==+> H2] is short for [H1 ==> (H1 \* H2)].
    Typical usage is for extracting a pure fact from a heap predicate. *)

Notation "H1 ==+> H2" := (pred_incl P%hprop (heap_is_star H1 H2))
  (at level 55, only parsing) : triple_scope.

(** [TRIPLE t PRE H POSTUNIT H2] is short for [POST (fun (_:unit) => H2)] *)

Notation "'TRIPLE' t 'PRE' H 'POSTUNIT' H2" :=
  (Triple t H (fun (_:unit) => H2))
  (at level 39, t at level 0, only parsing,
  format "'[v' 'TRIPLE'  t  '/' 'PRE'  H  '/' 'POSTUNIT'  H2 ']'") : triple_scope.

(** [TRIPLE t PRE H RET X POST H2] is short for [POST (fun x => H2)]. *)

Notation "'TRIPLE' t 'PRE' H1 'RET' v 'POST' H2" :=
  (Triple t H1 (fun r => \[r = v] \* H2))
  (at level 39, t at level 0, only parsing,
   format "'[v' 'TRIPLE'  t  '/' 'PRE'  H1  '/'  'RET'  v  '/'  'POST'  H2 ']'") : triple_scope.

(** [TRIPLE t INV H POST Q] is short for [TRIPLE T PRE H POST (Q \*+ H)] *)

Notation "'TRIPLE' T 'INV' H 'POST' Q" :=
  (Triple t H%hprop (Q \*+ H%hprop))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'INV'  H  ']'  '/' '[' 'POST'  Q  ']'  ']'")
   : triple_scope.

(** [TRIPLE t PRE H1 INV H2 POST Q] is short for [TRIPLE T PRE (H1 \* H2) POST (Q \*+ H2)] *)

Notation "'TRIPLE' T 'PRE' H1 'INV'' H2 'POST' Q" :=
  (Triple t (H1 \* H2) (Q \*+ H2%hprop))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'PRE''  H1  ']'  '/' '[' 'INV''  H2  ']'  '/' '[' 'POST'  Q  ']'  ']'")
   : triple_scope.

(** Additional combination of [INV] with [POSTUNIT] and [RET] *)

Notation "'TRIPLE' T 'INV' H1 'POSTUNIT' H2" :=
  (Triple t H1%hprop (fun (_:unit) => H1 \* H2%hprop))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'INV'  H1 ']'  '/' '[' 'POSTUNIT'  H2  ']'  ']'")
   : triple_scope.

Notation "'TRIPLE' T 'PRE' H1 'INV'' H2 'POSTUNIT' H3" :=
  (Triple t (H1 \* H2) (fun (_:unit) => H3 \* H2%hprop))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'PRE''  H1  ']'  '/' '[' 'INV''  H2  ']'  '/' '[' 'POSTUNIT'  H3  ']'  ']'")
   : triple_scope.

Notation "'TRIPLE' T 'INV' H1 'RET' v 'POST' H2" :=
  (Triple t H1%hprop (fun r => \[r = v] \* H2))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'INV'  H1 ']'  '/' '[' 'RET'  v  'POST'  H2  ']'  ']'")
   : triple_scope.

Notation "'TRIPLE' T 'PRE' H1 'INV'' H2 'RET' v 'POST' H3" :=
  (Triple t (H1 \* H2) (fun r => \[r = v] \* H3 \* H2%hprop))
  (at level 69, only parsing,
   format "'[v' 'TRIPLE'  t '/' '[' 'PRE''  H1  ']'  '/' '[' 'INV''  H2  ']'  '/' '[' 'RET'  v  'POST'  H3  ']'  ']'")
   : triple_scope.


(* ********************************************************************** *)
(* ********************************************************************** *)
(* ********************************************************************** *)
(** * Tactics for unfolding and folding representation predicates *)

(* TODO *)

(* ********************************************************************** *)
(** ** Database *)

(** The focus and unfocus databases are used to register specifications
    for accessors to record fields, combined with focus/unfocus operations.
    See example/Stack/StackSized_proof.v for a demo of this feature. *)

Definition database_xopen := True.
Definition database_xclose := True.

Notation "'RegisterOpen' T" := (Register database_xopen T)
  (at level 69) : charac.

Notation "'RegisterClose' T" := (Register database_xclose T)
  (at level 69) : charac.


(* ********************************************************************** *)
(** ** [xopen] *)

(** [xopen] is a tactic for applying [xchange] without having
    to explicitly specify the name of a focusing lemma.

    [xopen p] applies to a goal of the form
    [F H Q] or [H ==> H'] or [Q ===> Q'].
    It first searches for the pattern [p ~> T] in the pre-condition,
    then looks up in a database for the focus lemma [E] associated with
    the form [T], and then calls [xchange E].

    [xopen_show p] shows the lemma found, it is useful for debugging.

    Example for registering a focusing lemma:
      Hint Extern 1 (RegisterOpen (Tree _)) => Provide tree_open.
    See [Demo_proof.v] for examples.

    Then, use: [xopen p].

    Variants:
    - [xopenx t]  is short for [xopen t; xpull]

    - [xopenxs t]  is short for [xopen t; xpulls]  // EXPERIMENTAL

    - [xopen2 p] to perform [xopen p] twice. Only applies when there
      is no existentials to be extracted after the first [xopen].

*)

Ltac get_refocus_args tt :=
  match goal with
  | |- ?Q1 ===> ?Q2 => constr:((Q1,Q2))
  | |- ?H1 ==> ?H2 => constr:((H1,H2))
  | |- ?R ?H1 ?Q2 => constr:((H1,Q2))
  (* TODO: gérer le cas de fonctions appliquées à R *)
  end.

Ltac get_refocus_constr_in H t :=
  match H with context [ t ~> ?T ] => constr:(T) end.

Ltac xopen_constr t :=
  match get_refocus_args tt with (?H1,?H2) =>
  get_refocus_constr_in H1 t end.

Ltac xopen_core t :=
  let C1 := xopen_constr t in
  ltac_database_get database_xopen C1;
  let K := fresh "TEMP" in
  intros K; xchange (K t); clear K.

Ltac xopen_show_core t :=
  let C1 := xopen_constr t in
  pose C1;
  try ltac_database_get database_xopen C1;
  intros.

Tactic Notation "xopen_show" constr(t) :=
  xopen_show_core t.

Tactic Notation "xopen" constr(t) :=
  xopen_core t.
Tactic Notation "xopen" "~" constr(t) :=
  xopen t; xauto~.
Tactic Notation "xopen" "*" constr(t) :=
  xopen t; xauto*.

Tactic Notation "xopen2" constr(x) :=
  xopen x; xopen x.
Tactic Notation "xopen2" "~" constr(x) :=
  xopen2 x; xauto_tilde.
Tactic Notation "xopen2" "*" constr(x) :=
  xopen2 x; xauto_star.

Tactic Notation "xopenx" constr(t) :=
  xopen t; xpull.

Tactic Notation "xopenxs" constr(t) :=
  xopen t; xpulls.


(* ********************************************************************** *)
(** ** [xclose] *)

(** [xclose] is the symmetrical of [xopen]. It works in the
    same way, except that it looks for an unfocusing lemma.

    [xclose p] applies to a goal of the form
    [F H Q] or [H ==> H'] or [Q ===> Q'].
    It first searches for the pattern [p ~> T] in the pre-condition,
    then looks up in a database for the unfocus lemma [E] associated with
    the form [T], and then calls [xchange E].

    [xclose_show p] shows the lemma found, it is useful for debugging.

    Example for registering a focusing lemma:

     Hint Extern 1 (RegisterClose (Ref Id (MNode _ _ _))) =>
        Provide tree_node_close.

    Then, use: [xclose p].

    Variants:

    - [xclose p1 .. pn] is short for [xclose p1; ..; xclose pn]

    - [xclose2 p] to perform [xclose p] twice.

    - [xclose (>> p X Y)] where the extra arguments are used to
      provide explicit arguments to instantiate the "closing" lemma.

*)


Ltac xclose_get_ptr args :=
  match args with (boxer ?t)::_ => t end.

Ltac xclose_constr args :=
  let t := xclose_get_ptr args in
  match get_refocus_args tt with (?H1,?H2) =>
  get_refocus_constr_in H1 t end.

Ltac xclose_core args :=
  let args := list_boxer_of args in
  let C1 := xclose_constr args in
  ltac_database_get database_xclose C1;
  let K := fresh "TEMP" in
  intros K;
  let E := constr:((boxer K)::args) in
  xchange E;
  clear K.

Ltac xclose_show_core args :=
  let args := list_boxer_of args in
  let C1 := xclose_constr args in
  pose C1;
  try ltac_database_get database_xclose C1;
  intros.

Tactic Notation "xclose_show" constr(t) :=
  xclose_show_core t.

Tactic Notation "xclose" constr(t) :=
  xclose_core t.
Tactic Notation "xclose" "~" constr(t) :=
  xclose t; xauto~.
Tactic Notation "xclose" "*" constr(t) :=
  xclose t; xauto*.

Tactic Notation "xclose" constr(t1) constr(t2) :=
  xclose t1; xclose t2.
Tactic Notation "xclose" constr(t1) constr(t2) constr(t3) :=
  xclose t1; xclose t2 t3.
Tactic Notation "xclose" constr(t1) constr(t2) constr(t3) constr(t4) :=
  xclose t1; xclose t2 t3 t4.

Tactic Notation "xclose2" constr(x) :=
  xclose x; xclose x.
Tactic Notation "xclose2" "~" constr(x) :=
  xclose2 x; xauto_tilde.
Tactic Notation "xclose2" "*" constr(x) :=
  xclose2 x; xauto_star.



(* ********************************************************************** *)
(** ** Additional definitions *)

(** Type of representation predicates *)

Definition htype (A a:Type) : Type :=
  A -> a -> hprop.

(** Carried type for function closures *)

Definition func : Type := val.


(* ********************************************************************** *
(* TEMPORARY *)

Global Instance Enc_any : forall A, Enc A.
Admitted.
