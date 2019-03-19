(**

This file formalizes:
- heap entailement, written [H ==> H'],
- a functor that may be instantiated con construct, e.g.
  -- a standard Separation Logic,
  -- a Separation Logic extended with credits,
  -- a Separation Logic extended with temporary read-only permissions.

The functor in this file assumes:
- a type for heaps
- a definition of \[P] (lifting of pure predicates) and of \* (star)
- five properties of these operators
  (neutral element, commutativity and associativity of star,
   extrusion of existentials, and frame property for entailment).

The functor also provides:

- derived heap operators: \[], (\exists _,_), \Top
- a number of useful lemmas for reasoning about these operators
- notation for representation predicates: [x ~> R X].

- [rew_heap] normalizes heap predicate expressions
- [hpull] extracts existentials and pure facts from LHS of entailments
- [hsimpl] simplifies heap entailments (it calls [hpull] first)
- [hhsimpl] uses [hsimpl] to solves goal of the form [X: H h, ... |- H' h]
- [hchange] performs transitivity steps in entailments, modulo frame

- [xpull] extracts existentials and pure facts from preconditions.
- [xchange] performs transitivity steps in preconditions.
- [xapply] applies a lemma (triple or characteristic formula) modulo
  frame and weakening.
- [xunfold] unfolds representation predicates of the form [x ~> R X]

- [xpulls] is like [xpull] but performs one substitution automatically.
- [xchanges] is like [xchange] but calls [hsimpl] to simplify subgoals.
- [xapplys] is like [xapply] but calls [hsimpl] to simplify subgoals.

- [local F] is a predicate transformer used by characteristic formulae.
- [is_local F], where [F] is typically a triple or a characteristic formula,
  asserts that [F] can be subject to frame, weakening, and extraction
  of existentials and pure facts from preconditions. Tactics such as
  [xapply] apply the frame rule in a generic manner, and produce a
  [is_local] subgoal as side-condition.
- [xlocal] automatically discharges goals of the form [is_local F].

Author: Arthur Charguéraud, with contributions from Jacques-Henri Jourdan.
License: MIT.

*)

Set Implicit Arguments.
From TLC Require Export LibCore.
From Sep Require Export TLCbuffer.


(* ********************************************************************** *)
(** * Predicate extensionality, specialized to heap predicates *)

(** Predicate extensionality follows from functional extensional
    and propositional extensionality, which we take as axiom
    (in TLC's LibAxioms file). *)

Lemma hprop_extens : forall A (H1 H2:A->Prop),
  (forall h, H1 h <-> H2 h) ->
  (H1 = H2).
Proof using.
  introv M. applys fun_ext_1. intros h. applys* prop_ext.
Qed.


(* ********************************************************************** *)
(** * Entailment *)

(* ---------------------------------------------------------------------- *)
(* ** Definition of entailment *)


(** [H1 ==> H2] is defined as [forall h, H1 h -> H2 h]. *)

Definition himpl A (H1 H2:A->Prop) :=
  forall x, H1 x -> H2 x.

Notation "H1 ==> H2" := (himpl H1 H2)
  (at level 55, right associativity) : heap_scope.

(** [Q1 ===> Q2] is defined as [forall x h, Q1 x h -> Q2 x h].
    It is thus equivalent to [forall x, Q1 x ==> Q2 x].
    Thus, invoking [intro] on a [===>] goal leaves a [==>] goal. *)

Definition qimpl A B (Q1 Q2:A->B->Prop) :=
  forall r, himpl (Q1 r) (Q2 r).

Notation "Q1 ===> Q2" := (qimpl Q1 Q2)
  (at level 55, right associativity) : heap_scope.

Open Scope heap_scope.


(* ---------------------------------------------------------------------- *)
(* ** Properties of entailment *)

(*--LATER: update names to match new naming conventions *)

Section HimplProp.
Variable A : Type.
Implicit Types H : A -> Prop.

Hint Unfold himpl.

(** Entailment is reflexive, symmetric, transitive *)

Lemma himpl_refl : forall H,
  H ==> H.
Proof using. intros h. auto. Qed.

Lemma himpl_trans : forall H2 H1 H3,
  (H1 ==> H2) ->
  (H2 ==> H3) ->
  (H1 ==> H3).
Proof using. introv M1 M2. intros h H1h. eauto. Qed.

Lemma himpl_antisym : forall H1 H2,
  (H1 ==> H2) ->
  (H2 ==> H1) ->
  (H1 = H2).
Proof using. introv M1 M2. applys pred_ext_1. intros h. iff*. Qed.

(** Paragraphe of the definition, used by tactics *)

Lemma himpl_inv : forall H1 H2 (h:A),
  (H1 ==> H2) ->
  (H1 h) ->
  (H2 h).
Proof using. auto. Qed.

(** Reformulation of reflexivity, used by tactics *)

Lemma himpl_of_eq : forall H1 H2,
  H1 = H2 ->
  H1 ==> H2.
Proof. intros. subst. applys~ himpl_refl. Qed.

Lemma himpl_of_eq_sym : forall H1 H2,
  H1 = H2 ->
  H2 ==> H1.
Proof. intros. subst. applys~ himpl_refl. Qed.

End HimplProp.

Arguments himpl_of_eq [A] [H1] [H2].
Arguments himpl_of_eq_sym [A] [H1] [H2].
Arguments himpl_antisym [A] [H1] [H2].

Hint Resolve himpl_refl.

(** Reflexivity for postconditions *)

Lemma qimpl_refl : forall A B (Q:A->B->Prop),
  Q ===> Q.
Proof using. intros. hnfs*. Qed.

Hint Resolve qimpl_refl.



(* ********************************************************************** *)
(** * Assumptions of the functor *)

Module Type SepCore.


(* ---------------------------------------------------------------------- *)
(* ** Representation of [hprop] *)

(** Type of heaps *)

Parameter heap : Type.

(** Type of heap predicates *)

Definition hprop := heap -> Prop.

(** Characterization of affine heaps: 
    the [haffine H] asserts that [H] only holds for affine heaps. *)

Parameter heap_affine : heap -> Prop.

Definition haffine (H : hprop) : Prop :=
  forall h, H h -> heap_affine h.


(* ---------------------------------------------------------------------- *)
(* ** Core operators *)

(** Abstract predicates *)

Parameter hempty : hprop.

Parameter hstar : hprop -> hprop -> hprop.

(** Concrete predicates *)

Definition hexists A (J:A->hprop) : hprop :=
  fun h => exists x, J x h.

Definition hforall (A : Type) (J : A -> hprop) : hprop :=
  fun h => forall x, J x h.

(** Notation to state the properties *)

Notation "\[]" := (hempty)
  (at level 0) : heap_scope.

Notation "H1 '\*' H2" := (hstar H1 H2)
  (at level 41, right associativity) : heap_scope.

Notation "Q \*+ H" := (fun x => hstar (Q x) H)
  (at level 40) : heap_scope.


(* ---------------------------------------------------------------------- *)
(* ** Core properties *)

(** Empty is left neutral for star *)

Parameter hstar_hempty_l : forall H,
  \[] \* H = H.

(** Star is commutative *)

Parameter hstar_comm : forall H1 H2,
   H1 \* H2 = H2 \* H1.

(** Star is associative *)

Parameter hstar_assoc : forall H1 H2 H3,
  (H1 \* H2) \* H3 = H1 \* (H2 \* H3).

(** Extrusion of existentials out of star *)

Parameter hstar_hexists : forall A (J:A->hprop) H,
  (hexists J) \* H = hexists (fun x => (J x) \* H).

(** Extrusion of foralls out of star *)

Parameter hstar_hforall : forall H A (J:A->hprop),
  (hforall J) \* H ==> hforall (J \*+ H).

(** The frame property (star on H2) holds for entailment *)

Parameter himpl_frame_l : forall H2 H1 H1',
  H1 ==> H1' ->
  (H1 \* H2) ==> (H1' \* H2).

(** Properties of haffine *)

Parameter haffine_hempty :
  haffine \[].

Parameter haffine_hstar : forall H1 H2,
  haffine H1 ->
  haffine H2 ->
  haffine (H1 \* H2).

End SepCore.



(* ********************************************************************** *)
(** * Definition of heap predicates *)

Module SepSetup (SH : SepCore).
Import SH.

Open Scope heap_scope.

Implicit Types h : heap.
Implicit Types H : hprop.
Implicit Types P : Prop.

(* ---------------------------------------------------------------------- *)
(* ** Additional notation for core predicates *)

(** Notation for [hexists] *)

Notation "'\exists' x1 , H" := (hexists (fun x1 => H))
  (at level 39, x1 ident, H at level 50) : heap_scope.
Notation "'\exists' x1 x2 , H" := (\exists x1, \exists x2, H)
  (at level 39, x1 ident, x2 ident, H at level 50) : heap_scope.
Notation "'\exists' x1 x2 x3 , H" := (\exists x1, \exists x2, \exists x3, H)
  (at level 39, x1 ident, x2 ident, x3 ident, H at level 50) : heap_scope.
Notation "'\exists' x1 x2 x3 x4 , H" :=
  (\exists x1, \exists x2, \exists x3, \exists x4, H)
  (at level 39, x1 ident, x2 ident, x3 ident, x4 ident, H at level 50) : heap_scope.
Notation "'\exists' x1 x2 x3 x4 x5 , H" :=
  (\exists x1, \exists x2, \exists x3, \exists x4, \exists x5, H)
  (at level 39, x1 ident, x2 ident, x3 ident, x4 ident, x5 ident, H at level 50) : heap_scope.

(* TODO: get this definition to work:
Notation "'\exists' x1 .. xn , H" :=
  (hexists (fun x1 => .. (hexists (fun xn => H)) ..))
  (at level 39, x1, xn ident, H at level 50) : heap_scope.
*)

Notation "'\exists' ( x1 : T1 ) , H" := (hexists (fun x1:T1 => H))
  (at level 39, x1 ident, H at level 50, only parsing) : heap_scope.
Notation "'\exists' ( x1 : T1 ) ( x2 : T2 ) , H" := (\exists (x1:T1), \exists (x2:T2), H)
  (at level 39, x1 ident, x2 ident, H at level 50, only parsing) : heap_scope.
Notation "'\exists' ( x1 : T1 ) ( x2 : T2 ) ( x3 : T3 ) , H" := (\exists (x1:T1), \exists (x2:T2), \exists (x3:T3), H)
  (at level 39, x1 ident, x2 ident, x3 ident, H at level 50, only parsing) : heap_scope.

(** Notation for [hforall] *)

Notation "'\forall' x1 , H" := (hforall (fun x1 => H))
  (at level 39, x1 ident, H at level 50) : heap_scope.
Notation "'\forall' x1 x2 , H" := (\forall x1, \forall x2, H)
  (at level 39, x1 ident, x2 ident, H at level 50) : heap_scope.
Notation "'\forall' x1 x2 x3 , H" := (\forall x1, \forall x2, \forall x3, H)
  (at level 39, x1 ident, x2 ident, x3 ident, H at level 50) : heap_scope.
Notation "'\forall' x1 x2 x3 x4 , H" :=
  (\forall x1, \forall x2, \forall x3, \forall x4, H)
  (at level 39, x1 ident, x2 ident, x3 ident, x4 ident, H at level 50) : heap_scope.
Notation "'\forall' x1 x2 x3 x4 x5 , H" :=
  (\forall x1, \forall x2, \forall x3, \forall x4, \forall x5, H)
  (at level 39, x1 ident, x2 ident, x3 ident, x4 ident, x5 ident, H at level 50) : heap_scope.

Notation "'\forall' ( x1 : T1 ) , H" := (hforall (fun x1:T1 => H))
  (at level 39, x1 ident, H at level 50, only parsing) : heap_scope.
Notation "'\forall' ( x1 : T1 ) ( x2 : T2 ) , H" := (\forall (x1:T1), \forall (x2:T2), H)
  (at level 39, x1 ident, x2 ident, H at level 50, only parsing) : heap_scope.
Notation "'\forall' ( x1 : T1 ) ( x2 : T2 ) ( x3 : T3 ) , H" := (\forall (x1:T1), \forall (x2:T2), \forall (x3:T3), H)
  (at level 39, x1 ident, x2 ident, x3 ident, H at level 50, only parsing) : heap_scope.


(* ---------------------------------------------------------------------- *)
(* ** Derived heap predicates *)

(** Pure propositions lifted to heap predicates,
  written [ \[P] ].

  Remark: the definition below is equivalent to
  [fun h => (hempty h /\ P)]. *)

Definition hpure (P:Prop) : hprop :=
  hexists (fun (p:P) => hempty).

Notation "\[ P ]" := (hpure P)
  (at level 0, P at level 99, format "\[ P ]") : heap_scope.

(** The "Top" predicate, written [\Top], which holds of any heap,
  implemented as [\exists H, H]. *)

Definition htop : hprop :=
  hexists (fun (H:hprop) => H).

Notation "\Top" := (htop) : heap_scope.

(** The "GC" predicate, written [\GC], which holds of any heap,
  implemented as [\exists H, \[affine H] \* H]. *)

Definition hgc : hprop :=
  \exists H, \[haffine H] \* H.

Notation "\GC" := (hgc) : heap_scope.

(** Magic wand, written [H1 \-* H2] *)

Definition hwand (H1 H2 : hprop) : hprop :=
  hexists (fun (H:hprop) => H \* (hpure (H \* H1 ==> H2))).

Notation "H1 \-* H2" := (hwand H1 H2)
  (at level 43, right associativity) : heap_scope.

(** Magic wand for postconditions, written [Q1 \--* Q2] *)

Definition qwand A (Q1 Q2:A->hprop) :=
  hforall (fun x => hwand (Q1 x) (Q2 x)).

Notation "Q1 \--* Q2" := (qwand Q1 Q2)
  (at level 43) : heap_scope.

Open Scope heap_scope.
Delimit Scope heap_scope with hprop.

(** Disjunction, equivalent to [fun h => H1 h \/ H2 h] *)

Definition hor (H1 H2 : hprop) : hprop :=
  \exists (b:bool), if b then H1 else H2.

(** Non-separating conjunction, equivalent to [fun h => H1 h /\ H2 h] *)

Definition hand (H1 H2 : hprop) : hprop :=
  \forall (b:bool), if b then H1 else H2.

(** Affinity for postconditions *)

Definition haffine_post (A:Type) (J:A->hprop) : Prop :=
  forall x, haffine (J x).


(* ---------------------------------------------------------------------- *)
(** Additional notation for entailment
    [H1 ==+> H2] is short for [H1 ==> H1 \* H2] *)

Notation "H1 ==+> H2" := (H1%hprop ==> H1%hprop \* H2%hprop)
  (at level 55, only parsing) : heap_scope.


(* ---------------------------------------------------------------------- *)
(* ** Notation for triples *)

(** Notation [F PRE H POST Q] for stating specifications, e.g.
    [triple t PRE H POST Q] is the same as [triple t H Q] *)

Notation "F 'PRE' H 'POST' Q" :=
  (F H Q)
  (at level 69, only parsing) : heap_scope.


(* ---------------------------------------------------------------------- *)
(* ** Properties of [hprop] *)

Global Instance hinhab : Inhab hprop.
Proof using. intros. apply (Inhab_of_val hempty). Qed.


(* ---------------------------------------------------------------------- *)
(* ** Derived properties of operators *)

(** Properties of [himpl] *)

Lemma himpl_frame_r : forall H1 H2 H2',
  H2 ==> H2' ->
  (H1 \* H2) ==> (H1 \* H2').
Proof using.
  introv M. do 2 rewrite (@hstar_comm H1). applys~ himpl_frame_l.
Qed.

(** Properties of [hempty] *)

Lemma hstar_hempty_r : forall H,
  H \* \[] = H.
Proof using.
  applys neutral_r_of_comm_neutral_l.
  applys~ hstar_comm.
  applys~ hstar_hempty_l.
Qed.

(** Properties of [hpure] *)

Lemma hstar_pure : forall P H h, (* TODO: rename to hstar_hpure *)
  (\[P] \* H) h = (P /\ H h).
Proof using.
  intros. extens. unfold hpure.
  rewrite hstar_hexists.
  rewrite* hstar_hempty_l.
  iff (p&M) (p&M). { split~. } { exists~ p. }
Qed.

Lemma hpure_intro : forall P h,
  \[] h ->
  P ->
  \[P] h.
Proof using.
  introv M N. rewrite <- (hstar_hempty_l \[P]).
  rewrite hstar_comm. rewrite~ hstar_pure.
Qed.

Lemma hpure_inv : forall P h,
  \[P] h ->
  P /\ \[] h.
Proof using.
  introv M. rewrite <- hstar_pure.
  rewrite~ hstar_hempty_r.
Qed.

Lemma himpl_hpure_l : forall P H H',
  (P -> H ==> H') ->
  (\[P] \* H) ==> H'.
Proof using.
  introv W Hh. rewrite hstar_pure in Hh. applys* W.
Qed.

Lemma himpl_hpure_r : forall P H H',
  P ->
  (H ==> H') ->
  H ==> (\[P] \* H').
Proof using.
  introv HP W. intros h Hh. rewrite~ hstar_pure.
Qed.

Lemma hempty_eq_hpure_true :
  \[] = \[True].
Proof using.
  applys pred_ext_1. intros h. iff M.
  { applys* hpure_intro. }
  { forwards*: hpure_inv M. }
Qed.

Lemma hfalse_hstar_any : forall H,
  \[False] \* H = \[False].
Proof using.
  intros. applys pred_ext_1. intros h. rewrite hstar_pure. iff M.
  { false*. } { lets: hpure_inv M. false*. }
Qed.

Lemma hpure_eq_hexists_empty : forall P,
  \[P] = (\exists (p:P), \[]).
Proof using. auto. Qed.

(** Properties of [hexists] *)

Lemma hexists_intro : forall A (x:A) (J:A->hprop) h,
  J x h ->
  (hexists J) h.
Proof using. intros. exists~ x. Qed.

Lemma hexists_inv : forall A (J:A->hprop) h,
  (hexists J) h ->
  exists x, J x h.
Proof using. intros. destruct H as [x H]. exists~ x. Qed.

Lemma himpl_hexists_l : forall A H (J:A->hprop),
  (forall x, J x ==> H) ->
  (hexists J) ==> H.
Proof using. introv W. intros h (x&Hh). applys* W. Qed.

Lemma himpl_hexists_r : forall A (x:A) H J,
  (H ==> J x) ->
  H ==> (hexists J).
Proof using. introv W h. exists x. apply~ W. Qed.

Lemma himpl_hexists : forall A (J1 J2:A->hprop),
  J1 ===> J2 ->
  hexists J1 ==> hexists J2.
Proof using. introv W. intros h (x&M). exists x. applys~ W. Qed.

(** Properties of [hforall] *)

Lemma himpl_hforall_r : forall A (J:A->hprop) H,
  (forall x, H ==> J x) ->
  H ==> (hforall J).
Proof using. introv M. intros h Hh x. apply~ M. Qed.

Lemma himpl_hforall_l : forall A (J:A->hprop) H,
  (exists x, J x ==> H) ->
  (hforall J) ==> H.
Proof using. introv (x&M). intros h Hh. apply~ M. Qed.

Lemma himpl_hforall_l_for : forall A x (J:A->hprop) H,
  (J x ==> H) ->
  (hforall J) ==> H.
Proof using. introv M. applys* himpl_hforall_l. Qed.

Lemma himpl_hforall : forall A (J1 J2:A->hprop),
  J1 ===> J2 ->
  hforall J1 ==> hforall J2.
Proof using. introv W. intros h M x. applys W. applys M. Qed.

(** Properties of [hor] *)

Lemma hor_sym : forall H1 H2,
  hor H1 H2 = hor H2 H1.
Proof using.
  intros. unfold hor. applys himpl_antisym.
  { applys himpl_hexists_l. intros b.
    applys himpl_hexists_r (neg b). destruct* b. }
  { applys himpl_hexists_l. intros b.
    applys himpl_hexists_r (neg b). destruct* b. }
Qed.

Lemma himpl_hor_r_r : forall H1 H2,
  H1 ==> hor H1 H2.
Proof using. intros. unfolds hor. exists* true. Qed.

Lemma himpl_hor_r_l : forall H1 H2,
  H2 ==> hor H1 H2.
Proof using. intros. unfolds hor. exists* false. Qed.

(** Properties of [hand] *)

Lemma hand_sym : forall H1 H2,
  hand H1 H2 = hand H2 H1.
Proof using.
  intros. unfold hand. applys himpl_antisym.
  { applys himpl_hforall_r. intros b.
    applys himpl_hforall_l_for (neg b). destruct* b. }
  { applys himpl_hforall_r. intros b.
    applys himpl_hforall_l_for (neg b). destruct* b. }
Qed.

Lemma himpl_hand_l_r : forall H1 H2,
  hand H1 H2 ==> H1.
Proof using. intros. unfolds hand. applys* himpl_hforall_l_for true. Qed.

Lemma himpl_hand_l_l : forall H1 H2,
  hand H1 H2 ==> H2.
Proof using. intros. unfolds hand. applys* himpl_hforall_l_for false. Qed.

Lemma himpl_hand_r : forall H1 H2 H3,
  H1 ==> H2 ->
  H1 ==> H3 ->
  H1 ==> hand H2 H3.
Proof using. introv M1 M2 Hh. intros b. case_if*. Qed.

(** Properties of [hwand] and [qwand] necessary for [hsimpl];
    the remaining properties are proved later using [hsimpl]. *)

Lemma hwand_move_l : forall H1 H2 H3,
  H1 \* H2 ==> H3 ->
  H1 ==> (H2 \-* H3).
Proof using. 
  introv M. unfold hwand. applys himpl_hexists_r H1.
  rewrite hstar_comm. applys~ himpl_hpure_r.
Qed.

Lemma qwand_move_l : forall A (Q1 Q2:A->hprop) H,
  Q1 \*+ H ===> Q2 ->
  H ==> (Q1 \--* Q2).
Proof using.
  introv M. unfold qwand. applys himpl_hforall_r. intros x.
  applys* hwand_move_l. rewrite* hstar_comm.
Qed.

Arguments qwand_move_l [A].


(* ---------------------------------------------------------------------- *)
(* ** Properties of [htop] *)

Lemma htop_intro : forall h,
  \Top h.
Proof using. intros. exists~ (=h). Qed.

Lemma htop_eq :
  \Top = (\exists H, H).
Proof using. auto. Qed.

Lemma himpl_same_hstar_htop_r : forall H,
  H ==> H \* \Top.
Proof using.
  intros. rewrite htop_eq. rewrite hstar_comm. rewrite hstar_hexists.
  applys himpl_hexists_r \[]. rewrite~ hstar_hempty_l.
Qed.

Lemma himpl_hstar_htop_r : forall H H',
  H ==> H' ->
  H ==> H' \* \Top.
Proof using.
  introv M. applys himpl_trans (rm M). applys himpl_same_hstar_htop_r.
Qed.

Lemma htop_hstar_htop :
  \Top \* \Top = \Top.
Proof using.
  applys himpl_antisym.
  { unfold htop. rewrite hstar_hexists.
    applys himpl_hexists_l. intros H.
    rewrite hstar_comm.
    rewrite hstar_hexists.
    applys himpl_hexists_l. intros H'.
    applys~ himpl_hexists_r (H' \* H). }
  { applys~ himpl_hstar_htop_r. }
Qed.


(* ---------------------------------------------------------------------- *)
(* ** Affine heap predicates *)

Lemma haffine_eq : forall H,
  haffine H = (forall h, H h -> heap_affine h).
Proof using. auto. Qed.

Lemma haffine_hexists : forall A (J:A->hprop),
  haffine_post J ->
  haffine (hexists J).
Proof using. introv F1 (x&Hx). applys* F1. Qed.

Lemma haffine_hforall : forall A `{Inhab A} (J:A->hprop),
  haffine_post J ->
  haffine (hforall J).
Proof using. introv IA F1 Hx. applys* F1 arbitrary. Qed.

Lemma haffine_hpure : forall P,
  haffine \[P].
Proof using.
  intros. applys* haffine_hexists. intros HP. applys* haffine_hempty.
Qed.

Lemma haffine_hgc :
  haffine \GC.
Proof using.
  applys haffine_hexists. intros H h Hh. rewrite hstar_pure in Hh.
  destruct Hh as [M N]. applys* M.
Qed.


(* ---------------------------------------------------------------------- *)
(* ** Properties of [hgc] *)

Lemma hgc_eq :
  \GC = (\exists H, \[haffine H] \* H).
Proof using. auto. Qed.

Lemma hgc_of_heap_affine : forall h,
  heap_affine h ->
  \GC h.
Proof using.
  intros. rewrite hgc_eq. exists (=h).
  rewrite hstar_pure. split~. { introv ->. auto. }
Qed.

Lemma himpl_hgc_r : forall H,
  haffine H ->
  H ==> \GC.
Proof using.
  introv M. intros h Hh. applys* hgc_of_heap_affine.
Qed.
  (* Note that lemma above can also be read as:
    haffine H ->
    H h ->
    \GC h.
  *)

Lemma himpl_same_hstar_hgc_r : forall H,
  H ==> H \* \GC.
Proof using.
  intros. rewrite hgc_eq. rewrite hstar_comm. rewrite hstar_hexists.
  applys himpl_hexists_r \[]. rewrite hstar_hempty_r.
  applys~ himpl_hpure_r. applys haffine_hempty.
Qed.

Lemma himpl_hstar_hgc_r : forall H H',
  H ==> H' ->
  H ==> H' \* \GC.
Proof using.
  introv M. applys himpl_trans (rm M). applys himpl_same_hstar_hgc_r.
Qed.

Lemma hgc_hstar_hgc :
  \GC \* \GC = \GC.
Proof using.
  repeat rewrite hgc_eq. applys himpl_antisym.
  { rewrite hstar_hexists. applys himpl_hexists_l ;=> H.
    rewrite hstar_comm. rewrite hstar_hexists. applys himpl_hexists_l ;=> H'.
    applys~ himpl_hexists_r (H' \* H). rewrite hstar_assoc.
    applys himpl_hpure_l ;=> MH'. rewrite <- (hstar_comm H).
    rewrite <- hstar_assoc. rewrite hstar_comm.
    applys himpl_hpure_l ;=> MH. applys~ himpl_hpure_r.
    applys~ haffine_hstar. }
  { applys~ himpl_hstar_hgc_r. }
Qed.
  (* Same proof using tactics:
       unfold hgc. applys himpl_antisym.
      { hpull ;=> H1 M1 H2 M2. hsimpl (H1 \* H2). applys* haffine_hstar. }
      { hpull ;=> H M. hsimpl H \[]. applys haffine_hempty. auto. } *)

Lemma hempty_himpl_hgc : \[] ==> \GC.
Proof using.
  rewrite hgc_eq. applys himpl_hexists_r \[]. 
  applys~ himpl_hpure_r. applys haffine_hempty.
Qed.


(* ---------------------------------------------------------------------- *)
(* ** Definition of [is_local] *)

(** Type of characteristic formulae on values of type B *)

Notation "'~~' B" := (hprop->(B->hprop)->Prop)
  (at level 8, only parsing) : type_scope.

(** A formula [F] is local (e.g. [F] could be the predicate SL [triple])
    if it is sufficient for establishing [F H Q] to establish that the
    the formula holds on a subheap, in the sense that [F H1 Q1] with
    [H = H1 \* H2] and [Q = Q1 \*+ H2]. 
    (Technically, we add an extra [\GC] in to capture the affinity of the logic.) *)

Definition is_local B (F:~~B) : Prop :=
  forall H Q, 
    (H ==> \exists H1 H2 Q1, H1 \* H2 \*
             \[F H1 Q1 /\ Q1 \*+ H2 ===> Q \*+ \GC]) ->
    F H Q.

(** [is_local_pred S] asserts that [is_local (S x)] holds for any [x].
    It is useful for describing loop invariants. *)

Definition is_local_pred A B (S:A->~~B) :=
  forall x, is_local (S x).


(* ---------------------------------------------------------------------- *)
(* ** Notation for representation predicates *)

(** The arrow notation typically takes the form [x ~> R x],
   to indicate that [X] is the logical value that describes the
   heap structure [x], according to the representation predicate [R].
   It is just a notation for the heap predicate [R X x]. *)

Definition repr (A:Type) (S:A->hprop) (x:A) : hprop :=
  S x.

Notation "x '~>' S" := (repr S x)
  (at level 33, no associativity) : heap_scope.

Lemma repr_eq : forall (A:Type) (S:A->hprop) (x:A),
  (x ~> S) = (S x).
Proof using. auto. Qed.

(** [x ~> Id X] holds when [x] is equal to [X] in the empty heap.
   [Id] is called the identity representation predicate. *)

Definition Id {A:Type} (X:A) (x:A) :=
  \[ X = x ].


(* ---------------------------------------------------------------------- *)
(* ** Set operators to be opaque *)

Global Opaque hempty hpure hstar hexists htop hgc haffine.



(* ********************************************************************** *)
(* * Tactics for heap entailments *)

(* ---------------------------------------------------------------------- *)
(* ** [rew_heap] tactic to normalize expressions with [hstar] *)

(** [rew_heap] removes empty heap predicates, and normalizes w.r.t.
  associativity of star. *)

Lemma star_post_empty : forall B (Q:B->hprop),
  Q \*+ \[] = Q.
Proof using. extens. intros. rewrite* hstar_hempty_r. Qed.

Hint Rewrite hstar_hempty_l hstar_hempty_r
             hstar_assoc star_post_empty : rew_heap.

Tactic Notation "rew_heap" :=
  autorewrite with rew_heap.
Tactic Notation "rew_heap" "in" "*" :=
  autorewrite with rew_heap in *.
Tactic Notation "rew_heap" "in" hyp(H) :=
  autorewrite with rew_heap in H.

Tactic Notation "rew_heap" "~" :=
  rew_heap; auto_tilde.
Tactic Notation "rew_heap" "~" "in" "*" :=
  rew_heap in *; auto_tilde.
Tactic Notation "rew_heap" "~" "in" hyp(H) :=
  rew_heap in H; auto_tilde.

Tactic Notation "rew_heap" "*" :=
  rew_heap; auto_star.
Tactic Notation "rew_heap" "*" "in" "*" :=
  rew_heap in *; auto_star.
Tactic Notation "rew_heap" "*" "in" hyp(H) :=
  rew_heap in H; auto_star.


(* ---------------------------------------------------------------------- *)
(** Auxiliary lemmas useful for manual proofs *)

Lemma hstar_comm_assoc : forall H1 H2 H3,
  H1 \* H2 \* H3 = H2 \* H1 \* H3.
Proof using.
  intros. rewrite <- hstar_assoc.
  rewrite (@hstar_comm H1 H2). rew_heap~.
Qed.


(* ---------------------------------------------------------------------- *)
(** Auxiliary tactics used by many tactics *)

(* [xprecondition tt] returns the current precondition. *)

Ltac xprecondition tt :=
  match goal with |- ?R ?H ?Q => constr:(H) end.

(* [xpostcondition tt] returns the current postcondition. *)

Ltac xpostcondition tt :=
  match goal with |- ?E =>
  match get_fun_arg E with (_,?Q) => constr:(Q)
  end end.
  (* LATER: is this now equivalent to:
     match goal with |- ?J ?Q => constr:(Q) end. *)

(** [xpostcondition_is_evar tt] returns a boolean indicating
    whether the postcondition of the current goal is an evar. *)

Ltac xpostcondition_is_evar tt :=
  let Q := xpostcondition tt in
  is_evar_as_bool Q.


(* ---------------------------------------------------------------------- *)
(** Auxiliary tactics used by [hpull] and [hsimpl] *)

Ltac remove_empty_heaps_from H :=
  match H with context[ ?H1 \* \[] ] =>
    match is_evar_as_bool H1 with
    | false => rewrite (@hstar_hempty_r H1)
    | true => let X := fresh in
              set (X := H1);
              rewrite (@hstar_hempty_r X);
              subst X
    end end.

Ltac remove_empty_heaps_left tt :=
  repeat match goal with |- ?H1 ==> _ => remove_empty_heaps_from H1 end.

Ltac remove_empty_heaps_right tt :=
  repeat match goal with |- _ ==> ?H2 => remove_empty_heaps_from H2 end.

Ltac on_formula_pre cont :=
  match goal with
  | |- _ ?H ?Q => cont H
  | |- _ _ ?H ?Q => cont H
  | |- _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ _ _ _ _ ?H ?Q => cont H
  | |- _ _ _ _ _ _ _ _ _ _ ?H ?Q => cont H
  end.

Ltac on_formula_post cont :=
  match goal with
  | |- _ ?H ?Q => cont Q
  | |- _ _ ?H ?Q => cont Q
  | |- _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ _ _ _ _ ?H ?Q => cont Q
  | |- _ _ _ _ _ _ _ _ _ _ ?H ?Q => cont Q
  end.

Ltac remove_empty_heaps_formula tt :=
  repeat (on_formula_pre ltac:(remove_empty_heaps_from)).


(* ---------------------------------------------------------------------- *)
(* ** Tactic [haffine] simplifies a goal [haffine H] using structural
      rules. It may be extended to support custom extensions. *)

Ltac haffine_custom tt :=
  fail.

(* example extension:

  Ltac haffine_custom tt ::=
    repeat match goal with
    | |- haffine (hcredits _) => apply affine_credits; auto with zarith
    end.

*)

Ltac haffine_step tt :=
  match goal with 
  | |- haffine_post (_) => intros ? (* todo: interesting to have? *)
  | |- haffine ?H =>
    match H with
    | (hempty) => apply haffine_hempty
    | (hpure _) => apply haffine_hpure
    | (hstar _ _) => apply haffine_hstar
    | (hgc) => apply haffine_hgc
    | (hexists _) => apply haffine_hexists
    | (hforall _) => apply haffine_hforall
    | _ => haffine_custom tt
    end
  end.

Ltac haffine_core tt :=
  repeat (haffine_step tt).

Tactic Notation "haffine" :=
  haffine_core tt.


(* ---------------------------------------------------------------------- *)
(* Hints for tactics such as [hsimpl] *)

Inductive Hsimpl_hint : list Boxer -> Type :=
  | Hsimpl_hint : forall (L:list Boxer), Hsimpl_hint L.

Ltac Hsimpl_hint_put L :=
  let H := fresh "Hint" in
  generalize (Hsimpl_hint L); intros H.

Ltac Hsimpl_hint_next cont :=
  match goal with H: Hsimpl_hint ((boxer ?x)::?L) |- _ =>
    clear H; Hsimpl_hint_put L; cont x end.

Ltac Hsimpl_hint_remove tt :=
  match goal with H: Hsimpl_hint _ |- _ => clear H end.



(* ---------------------------------------------------------------------- *)
(* Tactic [hsimpl] *)

(** ... doc for [hsimpl] to update

   At the end, there remains a heap entailment with a simplified
   LHS and a simplified RHS, with items not cancelled out.
   At this point, if the goal is of the form [H ==> \GC] or [H ==> \Top] or
   [H ==> ?H'] for some evar [H'], then [hsimpl] solves the goal.
   Else, it leaves whatever remains.

   For the cancellation part, [hsimpl] cancels out [H] from the LHS
   with [H'] from the RHS if either [H'] is syntactically equal to [H],
   or if [H] and [H'] both have the form [x ~> ...] for the same [x].
   Note that, in case of a mismatch with [x ~> R X] on the LHS and
   [x ~> R' X'] on the RHS, [hsimpl] will produce a goal of the form
   [(x ~> R X) = (x ~> R' X')] which will likely be unsolvable.
   It is the user's responsability to perform the appropriate conversion
   steps prior to calling [hsimpl].

   Remark: the reason for the special treatment of [x ~> ...] is that
   it is very useful to be able to automatically cancel out
   [x ~> R X] from the LHS with [x ~> R ?Y], for some evar [?Y] which
   typically is introduced from an existential, e.g. [\exists Y, x ~> R Y].

   Remark: importantly, [hsimpl] does not attempt any simplification on
   a representation predicate of the form [?x ~> ...], when the [?x]
   is an uninstantiated evar. Such situation may arise for example
   with the following RHS: [\exists p, (r ~> Ref p) \* (p ~> Ref 3)].

   As a special feature, [hsimpl] may be provided optional arguments
   for instantiating the existentials (instead of introducing evars).
   These optional arguments need to be given in left-right order,
   and are used on a first-match basis: the head value is used if its
   type matches the type expected by the existential, else an evar
   is introduced for that existential. *)


(** [Hsimpl (Hla, Hlw, Hlt) (Hra, Hrg, Hrt)] is interepreted as
    the entailement [Hla \* Hlw \* Hlt ==> Hra \* Hrg \* Hrt] where
    - [Hla] denotes "cleaned up" items from the left hand side
    - [Hlw] denotes the [H1 \-* H2] and [Q1 \--* Q2] items from the left hand side
    - [Hlt] denotes the remaining items to process  items from the left hand side
    - [Hra] denotes "cleaned up" items from the right hand side
    - [Hrg] denotes the [\GC] and [\Top] items from the right hand side
    - [Hrt] denotes the remaining items to process from the right hand side 

    Note: we assume that all items consist of iterated hstars, and are 
    always terminated by an empty heap.
*)

Definition Hsimpl (HL HR:hprop*hprop*hprop) :=
  let '(Hla,Hlw,Hlt) := HL in
  let '(Hra,Hrg,Hrt) := HR in
  Hla \* Hlw \* Hlt ==> Hra \* Hrg \* Hrt.

(** [hsimpl_protect H] is use to prevent [hsimpl] from investigating inside [H] *)

Definition hsimpl_protect (A:Type) (X:A) : A := X.

(** Transition lemmas to start the process *)

Lemma hpull_protect : forall H1 H2,
  H1 ==> hsimpl_protect H2 ->
  H1 ==> H2.
Proof using. auto. Qed.

Lemma hsimpl_start : forall H1 H2,
  Hsimpl (\[], \[], (H1 \* \[])) (\[], \[], (H2 \* \[])) ->
  H1 ==> H2.
Proof using. introv M. unfolds Hsimpl. rew_heap~. Qed.
(* Note: [repeat rewrite hstar_assoc] after applying this lemma *)

(** Transition lemmas to stop the process *)

Lemma hsimpl_stop_general : forall Hla Hlw Hlt Hra Hrg Hrt,
  Hla \* Hlw \* Hlt ==> Hra \* Hrg \* Hrt ->
  Hsimpl (Hla, Hlw, Hlt) (Hra, Hrg, Hrt).
Proof using. auto. Qed.

Lemma hsimpl_stop_usual_without_hgc : forall Hla Hra,
  Hla ==> Hra ->
  Hsimpl (Hla, \[], \[]) (Hra, \[], \[]).
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_stop_refl : forall Hla,
  Hsimpl (Hla, \[], \[]) (Hla, \[], \[]).
Proof using. intros. unfolds Hsimpl. rew_heap~. Qed.

Lemma hsimpl_stop_qwand : forall A (Q:A->hprop) Hla,
  Hsimpl (Hla, \[], \[]) (Q \--* (Q \*+ Hla), \[], \[]).
Proof using. intros. unfolds Hsimpl. rew_heap~. Qed.

Lemma hsimpl_stop_htop : forall Hla Hrg',
  Hsimpl (Hla, \[], \[]) (\[], (\Top \* Hrg'), \[]).
Proof using. . Qed.

Lemma hsimpl_stop_hgc : forall Hla Hrg',
  haffine Hla ->
  Hsimpl (Hla, \[], \[]) (\[], (\GC \* Hrg'), \[]).
Proof using. . Qed.

(** Transition lemmas for LHS extraction operations *)

Lemma hsimpl_l_hempty : forall Hla Hlw Hlt HR,
  Hsimpl (Hla, Hlw, Hlt) HR ->
  Hsimpl (Hla, Hlw, (\[] \* Hlt)) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_hpure : forall P Hla Hlw Hlt HR,
  (P -> Hsimpl (Hla, Hlw, Hlt) HR) ->
  Hsimpl (Hla, Hlw, (\[P] \* Hlt)) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_hpure : forall A (J:A->hprop) Hla Hlw Hlt HR,
  (forall x, Hsimpl (Hla, Hlw, (J x \* Hlt)) HR) ->
  Hsimpl (Hla, Hlw, (hexists J \* Hlt)) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_acc_wand : forall H Hla Hlw Hlt HR,
  Hsimpl (Hla, (H \* Hlw), Hlt) HR ->
  Hsimpl (Hla, Hlw, (H \* Hlt)) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_acc_other : forall H Hla Hlw Hlt HR,
  Hsimpl ((H \* Hla), Hlw, Hlt) HR ->
  Hsimpl (Hla, Hlw, (H \* Hlt)) HR.
Proof using. introv M. rew_heap~. Qed.

(** Transition lemmas for LHS cancellation operations *)

Lemma hsimpl_l_cancel_hwand : forall H1 H2 Hla Hlw Hlt HR,
  Hsimpl (Hla, Hlw, (H2 \* Hlt)) HR ->
  Hsimpl ((H1 \* Hla), ((H1 \-* H2) \* Hlw), Hlt) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_cancel_qwand : forall A (Q1 Q2:A->hprop) (x:A) Hla Hlw Hlt HR,
  Hsimpl (Hla, Hlw, (Q2 x \* Hlt)) HR ->
  Hsimpl ((Q1 x \* Hla), ((Q1 \-* Q2) \* Hlw), Hlt) HR.
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_skip_wand : forall H Hla Hlw Hlt HR,
  Hsimpl ((Hla \* H), Hlw, Hlt) HR ->
  Hsimpl (Hla, (H \* Hlw), Hlt) HR.
Proof using. introv M. rew_heap~. Qed.

(** Transition lemmas for RHS extraction operations *)

Lemma hsimpl_r_hempty : forall Hra Hrg Hrt HL,
  Hsimpl HL (Hra, Hrg, Hrt) ->
  Hsimpl HL (Hra, Hrg, (\[] \* Hrt)).
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_l_hpure : forall P Hra Hrg Hrt HL,
  hsimpl_protect P ->
  Hsimpl HL (Hra, Hrg, Hrt) ->
  Hsimpl HL (Hra, Hrg, (\[P] \* Hrt)).
Proof using. introv M. ... Qed.

Lemma hsimpl_l_hexists : forall A (x:A) (J:A->hprop) Hra Hrg Hrt HL,
  Hsimpl HL (Hra, Hrg, (J x \* Hrt)) ->
  Hsimpl HL (Hra, Hrg, (hexists J \* Hrt)).
Proof using. ... Qed.

Lemma hsimpl_l_hgc : forall Hra Hrg Hrt HL,
  Hsimpl HL (Hra, (\GC \* Hrg), Hrt) ->
  Hsimpl HL (Hra, Hrg, (\GC \* Hrt)).
Proof using. introv M. unfolds Hsimpl. rew_heap~. Qed.

Lemma hsimpl_l_htop : forall Hra Hrg Hrt HL,
  Hsimpl HL (Hra, (\Top \* Hrg), Hrt) ->
  Hsimpl HL (Hra, Hrg, (\Top \* Hrt)).
Proof using. introv M. unfolds Hsimpl. rew_heap~. Qed.

(** Transition lemmas for LHS/RHS cancellation 
    --- meant to be applied when Hlw and Hlt are empty *)

Lemma hsimpl_lr_cancel : forall H Hla Hlw Hlt Hra Hrg Hrt,
  Hsimpl (Hla, Hlw, Hlt) (Hra, Hrg, Hrt) ->
  Hsimpl ((H \* Hla), Hlw, Hlt) (Hra, Hrg, (H \* Hrt)).
Proof using. introv M. rew_heap~. Qed.

Lemma hsimpl_lr_hwand : forall H1 H2 Hla Hlw Hlt,
  Hsimpl (Hla, Hlw, (H1 \* Hlt)) (H2, \[], \[]) ->
  Hsimpl (Hla, Hlw, Hlt) ((H1 \-* H2), \[], \[]).
Proof using. 
  introv M. unfolds Hsimpl. rew_heap~. 
  applys hwand_move_l \[]. { rewrite* hstar_hempty_l. }
Qed.

Lemma hsimpl_lr_qwand : forall A (Q1 Q2:A->hprop) Hla Hlw Hlt,
  (forall x, Hsimpl (Hla, Hlw, (Q1 x \* Hlt)) (Q2 x, \[], \[]) ->
  Hsimpl (Hla, Hlw, Hlt) ((Q1 \-* Q2), \[], \[]).
Proof using. 
  introv M. unfolds Hsimpl. rew_heap~. 
  applys qwand_move_l \[]. { rewrite* hstar_hempty_l. }
Qed.



------



Lemma hcancel_hexists : forall A (x:A) H' H1 H2 (J:A->hprop),
  H' ==> H1 \* J x \* H2 ->
  H' ==> H1 \* (hexists J \* H2).
Proof using.
  intros. rewrite hstar_comm_assoc.
  rewrite hstar_hexists.
  applys himpl_hexists_r x.
  rewrite~ hstar_comm_assoc.
Qed.

Lemma hcancel_id : forall A (x X : A) H' H1 H2,
  H' ==> H1 \* H2 ->
  x = X ->
  H' ==> H1 \* (x ~> Id X \* H2).
Proof using. intros. unfold Id. apply~ hcancel_hprop. Qed.

Lemma hcancel_id_unify : forall A (x : A) H' H1 H2,
  H' ==> H1 \* H2 ->
  H' ==> H1 \* (x ~> Id x \* H2).
Proof using. intros. apply~ hcancel_id. Qed.

Lemma hcancel_cancel_1 : forall H HA HR HT,
  HT ==> HA \* HR ->
  H \* HT ==> HA \* (H \* HR).
Proof using. intros. rewrite hstar_comm_assoc. applys~ himpl_frame_r. Qed.

Lemma hcancel_cancel_eq_1 : forall H H' HA HR HT,
  H = H' -> HT ==> HA \* HR -> H \* HT ==> HA \* (H' \* HR).
Proof using. intros. subst. apply~ hcancel_cancel_1. Qed.


------

Ltac hcancel_setup tt :=
  hcancel_prepare tt;
  rew_heap;
  hcancel_left_empty tt;
  apply hcancel_start.

Ltac hsimpl_cleanup tt :=
  try Hsimpl_hint_remove tt;
  try remove_empty_heaps_right tt;
  try remove_empty_heaps_left tt;


  try apply himpl_refl;
  try (apply hcancel_hgc; );


---

Ltac hcancel_prepare tt :=
  match goal with
  | |- @qimpl _ _ _ ?Q' => is_evar Q'; apply qimpl_refl
  | |- @qimpl unit _ ?Q ?Q' => let t := fresh "_tt" in intros t; destruct t
  | |- eq _ _ => applys himpl_antisym
  | |- @qimpl _ _ _ _ => let r := fresh "r" in intros r
  | |- himpl _ ?H' => is_evar H'; apply himpl_refl
  | |- himpl _ _ => idtac
  end.
------------

(** Tactics *)

Opaque Hsimpl.

Ltac hsimpl_handle_qimpl tt :=
  match goal with
  | |- @qimpl unit _ _ _ => let t := fresh "_tt" in intros t; destruct t
  | |- @qimpl _ _ _ _ => let r := fresh "r" in intros r
  | |- himpl _ _ => idtac
  | _ => fail 1 "not a goal for hsimpl/hpull"
  end.

Ltac Hsimpl_intro tt :=
  applys hsimpl_start;
  repeat (rewrite hstar_assoc).

Ltac hpull_start tt :=
  pose ltac_mark;
  intros;
  hsimpl_handle_qimpl tt;
  applys hpull_protect;
  Hsimpl_intro tt.

Ltac hsimpl_start tt :=
  pose ltac_mark;
  intros;
  hsimpl_handle_qimpl tt;
  Hsimpl_intro tt.

Ltac hsimpl_post_before_generalize tt :=
  idtac.

Ltac hsimpl_post_after_generalize tt :=
  idtac.

Ltac himpl_post_processing_for_hyp H :=
  idtac.

Ltac hsimpl_handle_false_subgoals tt :=
  tryfalse.

Ltac hsimpl_handle_haffine_subgoals tt :=
  match goal with |- haffine _ =>   
    try solve [ haffine ] end.

Ltac hsimpl_post tt :=
  hsimpl_post_before_generalize tt;
  hsimpl_handle_false_subgoals tt;
  gen_until_mark_with_processing ltac:(himpl_post_processing_for_hyp);
  hsimpl_post_after_generalize tt;
  unfold hsimpl_protect;
  hsimpl_handle_haffine_subgoals tt.

Ltac hsimpl_apply_stop_lemma tt :=
  match goal with 
  | |- Hsimpl (?Hla, \[], \[]) (?Q1 \--* ?Q2, \[], \[]) => 
      is_evar Q1; eapply hsimpl_stop_qwand
  | |- Hsimpl (?Hla, \[], \[]) (?Hra, \[], \[]) => 
      first [ is_evar Hra; apply hsimpl_stop_refl
            | apply hsimpl_stop_usual_without_hgc ]
  | |- Hsimpl (?Hla, \[], \[]) (?Hra, (?Hrg1 \* _), \[]) =>
      (* could be smarter to take in priority \Top instead of \GC *)
      match Hrg1 with
      | \Top => apply hsimpl_stop_htop
      | \GC => apply hsimpl_stop_hgc
      end
  | |- _ => apply hsimpl_stop_general
  end.

Ltac hsimpl_stop tt :=
  hsimpl_apply_stop_lemma tt;
  hsimpl_post tt.

(** Tactic notation *)

Tactic Notation "hpull" := hpull_core tt.
Tactic Notation "hpull" "~" := hpull; auto_tilde.
Tactic Notation "hpull" "*" := hpull; auto_star.

Tactic Notation "hsimpl" := hsimpl_core tt.
Tactic Notation "hsimpl" "~" := hsimpl; auto_tilde.
Tactic Notation "hsimpl" "*" := hsimpl; auto_star.

Tactic Notation "hsimpl" constr(L) :=
  match type of L with
  | list Boxer => Hsimpl_hint_put L
  | _ => Hsimpl_hint_put (boxer L :: nil)
  end; hsimpl.
Tactic Notation "hsimpl" constr(X1) constr(X2) :=
  hsimpl (>> X1 X2).
Tactic Notation "hsimpl" constr(X1) constr(X2) constr(X3) :=
  hsimpl (>> X1 X2 X3).

Tactic Notation "hsimpl" "~" constr(L) :=
  hsimpl L; auto_tilde.
Tactic Notation "hsimpl" "~" constr(X1) constr(X2) :=
  hsimpl X1 X2; auto_tilde.
Tactic Notation "hsimpl" "~" constr(X1) constr(X2) constr(X3) :=
  hsimpl X1 X2 X3; auto_tilde.

Tactic Notation "hsimpl" "*" constr(L) :=
  hsimpl L; auto_star.
Tactic Notation "hsimpl" "*" constr(X1) constr(X2) :=
  hsimpl X1 X2; auto_star.
Tactic Notation "hsimpl" "*" constr(X1) constr(X2) constr(X3) :=
  hsimpl X1 X2 X3; auto_star.







----


Lemma hcancel_cancel_2 : forall H HA HR H1 HT,
  H1 \* HT ==> HA \* HR ->
  H1 \* H \* HT ==> HA \* (H \* HR).
Proof using. intros. rewrite (hstar_comm_assoc H1). apply~ hcancel_cancel_1. Qed.

Lemma hcancel_cancel_3 : forall H HA HR H1 H2 HT,
  H1 \* H2 \* HT ==> HA \* HR -> H1 \* H2 \* H \* HT ==> HA \* (H \* HR).
Proof using. intros. rewrite (hstar_comm_assoc H2). apply~ hcancel_cancel_2. Qed.

Lemma hcancel_cancel_4 : forall H HA HR H1 H2 H3 HT,
  H1 \* H2 \* H3 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H3). apply~ hcancel_cancel_3. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_5 : forall H HA HR H1 H2 H3 H4 HT,
  H1 \* H2 \* H3 \* H4 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H4). apply~ hcancel_cancel_4. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_6 : forall H HA HR H1 H2 H3 H4 H5 HT,
  H1 \* H2 \* H3 \* H4 \* H5 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H5 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H5). apply~ hcancel_cancel_5. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_7 : forall H HA HR H1 H2 H3 H4 H5 H6 HT,
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H6). apply~ hcancel_cancel_6. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_8 : forall H HA HR H1 H2 H3 H4 H5 H6 H7 HT,
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (star_comm_assoc H7). apply~ hcancel_cancel_7. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_9 : forall H HA HR H1 H2 H3 H4 H5 H6 H7 H8 HT,
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H8). apply~ hcancel_cancel_8. Qed.*)
Admitted. (* commented out for faster compilation *)

Lemma hcancel_cancel_10 : forall H HA HR H1 H2 H3 H4 H5 H6 H7 H8 H9 HT,
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 \* HT ==> HA \* HR ->
  H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 \* H \* HT ==> HA \* (H \* HR).
(*Proof using. intros. rewrite (hstar_comm_assoc H9). apply~ hcancel_cancel_9. Qed.*)
Admitted. (* commented out for faster compilation *)

Ltac hcancel_try_same tt :=
  first
  [ apply hcancel_cancel_1
  | apply hcancel_cancel_2
  | apply hcancel_cancel_3
  | apply hcancel_cancel_4
  | apply hcancel_cancel_5
  | apply hcancel_cancel_6
  | apply hcancel_cancel_7
  | apply hcancel_cancel_8
  | apply hcancel_cancel_9
  | apply hcancel_cancel_10
  ].

Ltac hcancel_find_same H HL :=
  match HL with
  | H \* _ => apply hcancel_cancel_1
  | _ \* H \* _ => apply hcancel_cancel_2
  | _ \* _ \* H \* _ => apply hcancel_cancel_3
  | _ \* _ \* _ \* H \* _ => apply hcancel_cancel_4
  | _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_5
  | _ \* _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_6
  | _ \* _ \* _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_7
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_8
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_9
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* H \* _ => apply hcancel_cancel_10
  end.

Ltac hcancel_find_repr l HL cont :=
  match HL with
  | repr _ l \* _ => apply hcancel_cancel_eq_1
  | _ \* repr _ l \* _ => apply hcancel_cancel_eq_2
  | _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_3
  | _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_4
  | _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_5
  | _ \* _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_6
  | _ \* _ \* _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_7
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_8
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_9
  | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* repr _ l \* _ => apply hcancel_cancel_eq_10
  end; [ cont tt | ].

Ltac hcancel_hexists tt :=
  first [
    Hsimpl_hint_next ltac:(fun x =>
      match x with
      | __ => eapply hcancel_hexists
      | _ => apply (@hcancel_hexists _ x)
      end)
  | eapply hcancel_hexists ].

(* LATER: improve this implementation, and give a good spec *)
Ltac hcancel_find_repr_post tt :=
  try solve
   [ reflexivity
   | fequal; fequal; first [ eassumption | symmetry; eassumption ] ];
  try match goal with |- repr ?X ?l = repr ?Y ?l => match constr:((X,Y)) with
  | (?F1 _, ?F1 _) => fequal; fequal
  | (?F1 ?F2 _, ?F1 ?F2 _) => fequal; fequal
  | (?F1 ?F2 ?F3 _, ?F1 ?F2 ?F3 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 _, ?F1 ?F2 ?F3 ?F4 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 ?F5 _, ?F1 ?F2 ?F3 ?F4 ?F5 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 ?F5 ?F6 _, ?F1 ?F2 ?F3 ?F4 ?F5 ?F6 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 _, ?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 ?F8 _, ?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 ?F8 _) => fequal; fequal
  | (?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 ?F8 ?F9 _, ?F1 ?F2 ?F3 ?F4 ?F5 ?F6 ?F7 ?F8 ?F9 _) => fequal; fequal
  end end.

(** Maintain the goal in the form
     H1 \* ... \* HN \* [] ==> HA \* HR
   where HA is initially empty and accumulates elements not simplifiable
   and HR contains the values that are to be cancelled out;
   the last item of HR is always a [].
   As long as HR is of the form H \* H', we try to match H with one of the Hi.
  *)

Ltac hcancel_hook H := fail.

Ltac check_noevar2 M := (* LATER: merge *)
  first [ has_evar M; fail 1 | idtac ].

Ltac hcancel_step tt :=
  match goal with |- ?HL ==> ?HA \* ?HN =>
  match HN with
  | ?H \* _ =>
    match H with
    | \Top => apply hcancel_keep
    | \GC => apply hcancel_keep
    | ?H => hcancel_hook H
    | \[] => apply hcancel_empty
    | \[_] => apply hcancel_hprop
    | hexists _ => hcancel_hexists tt
    | _ \* _ => apply hcancel_assoc
    | ?H =>
       first [ is_evar H; fail 1 | idtac ];
       hcancel_find_same H HL (* may fail *)
    | ?x ~> _ => hcancel_find_repr x HL ltac:(hcancel_find_repr_post) (* may fail *)
    | ?x ~> Id _ => check_noevar2 x; apply hcancel_id (* may fail *)
    | ?x ~> ?T _ => check_noevar2 x;
                    let M := fresh in assert (M: T = Id); [ reflexivity | clear M ];
                    apply hcancel_id; [ | reflexivity ]
                    (* may fail *)
    | ?x ~> ?T ?X => check_noevar2 x; is_evar T; is_evar X; apply hcancel_id_unify
    | _ => apply hcancel_keep
    end
  | \[] => fail 1
  | _ => apply hcancel_starify
  end end.







(* ---------------------------------------------------------------------- *)
(* Demo for tactic [hsimpl] *)


Lemma hpull_demo : forall H1 H2 H3 H,
   (H1 \* \[] \* (H2 \* \exists (y:int), \[y = y]) \* H3) ==> H.

Lemma hsimpl_demo_1 : forall H1 H2 H3 H4 H5,
  H1 \* H2 \* H3 \* H4 ==> H4 \* H3 \* H5 \* H2.
Proof using.
  intros. dup.
  { hsimpl. admit. (* demo *) }
  { hcancel_setup tt.
    hcancel_step tt.
    hcancel_step tt.
    hcancel_step tt.
    hcancel_step tt.
    hcancel_step tt.
    try hcancel_step tt.
    hcancel_cleanup tt.
    admit. (* demo *) }
Abort.

Lemma hsimpl_demo_2 : forall H1 H2 H3 H4 H5,
  H1 \* H2 \* H3 \* H4 \* H5 ==> H3 \* H1 \* H2 \* \Top.
Proof using. intros. hsimpl. Abort.

Lemma hsimpl_demo_3 : forall H1 H2,
  (forall H, H1 \* H2 ==> H -> True) -> True.
Proof using. intros. eapply H. hsimpl. Abort.

Lemma hsimpl_demo_4 : forall H1 H2,
  H1 \* H2 \* \Top ==> H1 \* \Top.
Proof using. intros. hsimpl. Abort.

Lemma hsimpl_demo_5 : forall H1 H2,
  H1 \* H2 \* \Top ==> H1 \* \Top \* \Top.
Proof using.
  intros. set (H:=\Top) at 2. rewrite htop_eq.
  unfold H. hsimpl.
Abort.

Lemma hsimpl_demo_6 : forall H1 H2,
  haffine H2 ->
  H1 \* H2 ==> H1 \* \GC.
Proof using. intros. hsimpl. auto. Qed.

Lemma hsimpl_demo_7 : forall H1 H2,
  haffine H2 ->
  H1 \* H2 \* \GC ==> H1 \* H2 \* \GC \* \GC.
Proof using. intros. hsimpl. Qed.

Lemma demo_hsimpl_hints : exists n, n = 3.
Proof using.
  Hsimpl_hint_put (>> 3 true).
  Hsimpl_hint_next ltac:(fun x => exists x).
  Hsimpl_hint_remove tt.
Abort.




(* ---------------------------------------------------------------------- *)
(* Premature optimization for [hsimpl_start] tactic *)

(*
  Ltac hcancel_left_empty tt :=
    match goal with |- ?HL ==> _ =>
    match HL with
    | \[] => idtac
    | _ \* \[] => idtac
    | _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* \[] => idtac
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* ?H => apply hcancel_start_10
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* _ \* ?H => apply hcancel_start_9
    | _ \* _ \* _ \* _ \* _ \* _ \* _ \* ?H => apply hcancel_start_8
    | _ \* _ \* _ \* _ \* _ \* _ \* ?H => apply hcancel_start_7
    | _ \* _ \* _ \* _ \* _ \* ?H => apply hcancel_start_6
    | _ \* _ \* _ \* _ \* ?H => apply hcancel_start_5
    | _ \* _ \* _ \* ?H => apply hcancel_start_4
    | _ \* _ \* ?H => apply hcancel_start_3
    | _ \* ?H => apply hcancel_start_2
    | ?H => apply hcancel_start_1
    end end.


  Lemma hcancel_start_1 : forall H1 H',
    H1 \* \[] ==> H' -> H1 ==> H'.
  Proof using. intros. rew_heap in H. auto. Qed.

  Lemma hcancel_start_2 : forall H1 H2 H',
    H1 \* H2 \* \[] ==> H' ->
    H1 \* H2 ==> H'.
  Proof using. intros. rew_heap in H. auto. Qed.

  Lemma hcancel_start_3 : forall H1 H2 H3 H',
    H1 \* H2 \* H3 \* \[] ==> H' ->
    H1 \* H2 \* H3 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed.*)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_4 : forall H1 H2 H3 H4 H',
    H1 \* H2 \* H3 \* H4 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_5 : forall H1 H2 H3 H4 H5 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_6 : forall H1 H2 H3 H4 H5 H6 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_7 : forall H1 H2 H3 H4 H5 H6 H7 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_8 : forall H1 H2 H3 H4 H5 H6 H7 H8 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_9 : forall H1 H2 H3 H4 H5 H6 H7 H8 H9 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

  Lemma hcancel_start_10 : forall H1 H2 H3 H4 H5 H6 H7 H8 H9 H10 H',
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 \* H10 \* \[] ==> H' ->
    H1 \* H2 \* H3 \* H4 \* H5 \* H6 \* H7 \* H8 \* H9 \* H10 ==> H'.
  (* Proof using. intros. rew_heap in H. auto. Qed. *)
  Admitted. (* commented out for faster compilation *)

*)



(* ---------------------------------------------------------------------- *)
(* ** Tactic [hhsimpl] to prove [H h] from [H' h] *)

(** [hhsimpl] applies to a goal of the form [H h].
   It looks up for an hypothesis of the form [H' h],
   where [H'] is a heap predicate (whose type is syntactically [hprop]).
   It then turns the goal into [H ==> H'], and calls [hsimpl].

   This tactic is very useful for establishing the soundness of
   Separation Logic derivation rules. It should never be used in
   the verification of concrete programs, since a heap [h] should
   never appear explicitly in such a proof, all the reasoning being
   conducted at the level of heap predicates. *)

Ltac hhsimpl_core :=
  match goal with N: ?H ?h |- _ ?h =>
    match type of H with hprop =>
    applys himpl_inv N; clear N; hsimpl
  end end.

Tactic Notation "hhsimpl" := hhsimpl_core.
Tactic Notation "hhsimpl" "~" := hhsimpl; auto_tilde.
Tactic Notation "hhsimpl" "*" := hhsimpl; auto_star.


(* ---------------------------------------------------------------------- *)
(* ** Tactic [hchange] *)

(** [hchange] performs rewriting on the LHS of an entailment.
  Essentially, it applies to a goal of the form [H1 \* H2 ==> H3],
  and exploits an entailment [H1 ==> H1'] to replace the goal with
  [H1' \* H2 ==> H3].

  The tactic is actually a bit more flexible in two respects:
  - it does not force the LHS to be exactly of the form [H1 \* H2]
  - it takes as argument any lemma, whose instantiation result in
    a heap entailment of the form [H1 ==> H1'].

  Concretely, the tactic is just a wrapper around an application
  of the lemma called [hchange_lemma], which appears below.

  [hchanges] combines a call to [hchange] with calls to [hsimpl]
  on the subgoals. *)

Lemma hchange_lemma : forall H1 H1' H H' H2,
  (H1 ==> H1') ->
  (H ==> H1 \* H2) ->
  (H1' \* H2 ==> H') ->
  (H ==> H').
Proof using.
  intros. applys* (@himpl_trans heap) (H1 \* H2).
  applys* (@himpl_trans heap) (H1' \* H2). hsimpl~.
Qed.

Ltac hchange_apply L cont1 cont2 :=
  eapply hchange_lemma;
    [ applys L | cont1 tt | cont2 tt ].

Ltac hchange_forwards L modif cont1 cont2 :=
  forwards_nounfold_then L ltac:(fun K =>
  match modif with
  | __ =>
     match type of K with
     | _ = _ => hchange_apply (@himpl_of_eq _ _ _ K) cont1 cont2
     | _ => hchange_apply K cont1 cont2
     end
  | _ => hchange_apply (@modif _ _ _ K) cont1 cont2
  end).

Ltac hcancel_cont tt :=
  instantiate; hcancel.

Ltac hsimpl_cont tt :=
  instantiate; hsimpl.

Ltac hchange_core E modif cont1 cont2 :=
  hpull; intros;
  match E with
  (*  | ?H ==> ?H' => hchange_with_core H H' -- LATER *)
  | _ => hchange_forwards E modif ltac:(cont1) ltac:(cont2)
  end.

Ltac hchange_debug_base E modif :=
  hchange_forwards E modif ltac:(idcont) ltac:(idcont).

Tactic Notation "hchange_debug" constr(E) :=
  hchange_debug_base E __.
Tactic Notation "hchange_debug" "->" constr(E) :=
  hchange_debug_base E himpl_of_eq.
Tactic Notation "hchange_debug" "<-" constr(E) :=
  hchange_debug_base himpl_of_eq_sym.

Ltac hchange_base E modif :=
  hchange_core E modif ltac:(hcancel_cont) ltac:(idcont).

Tactic Notation "hchange" constr(E) :=
  hchange_base E __.
Tactic Notation "hchange" "->" constr(E) :=
  hchange_base E himpl_of_eq.
Tactic Notation "hchange" "<-" constr(E) :=
  hchange_base E himpl_of_eq_sym.

Tactic Notation "hchange" "~" constr(E) :=
  hchange E; auto_tilde.
Tactic Notation "hchange" "*" constr(E) :=
  hchange E; auto_star.

Ltac hchanges_base E modif :=
  hchange_core E modif ltac:(hcancel_cont) ltac:(hsimpl_cont).

Tactic Notation "hchanges" constr(E) :=
  hchanges_base E __.
Tactic Notation "hchanges" "->" constr(E) :=
  hchanges_base E himpl_of_eq.
Tactic Notation "hchange" "<-" constr(E) :=
  hchanges_base E himpl_of_eq_sym.

Tactic Notation "hchanges" "~" constr(E) :=
  hchanges E; auto_tilde.
Tactic Notation "hchanges" "*" constr(E) :=
  hchanges E; auto_star.

Tactic Notation "hchange" constr(E1) constr(E2) :=
  hchange E1; hchange E2.
Tactic Notation "hchange" constr(E1) constr(E2) constr(E3) :=
  hchange E1; hchange E2 E3.



(* ********************************************************************** *)
(* * Properties of the magic wand *)

(* ---------------------------------------------------------------------- *)
(* ** Properties of [hwand] *)

Lemma hwand_eq_hexists_hstar_hpure : forall H1 H2,
  (H1 \-* H2) = (\exists H, H \* \[H \* H1 ==> H2]).
Proof using. auto. Qed.

Lemma hwand_hempty_l : forall H,
  (\[] \-* H) = H.
Proof using.
  intros. unfold hwand. applys himpl_antisym.
  { hpull ;=> H' M. hchanges M. }
  { hsimpl. }
Qed.

Hint Rewrite hwand_hempty_l : rew_heap.

Lemma hwand_himpl_r : forall H1 H2 H2',
  H2 ==> H2' ->
  (H1 \-* H2) ==> (H1 \-* H2').
Proof using.
  intros. unfold hwand. hsimpl ;=> H3 M. hchanges~ M.
Qed.

Lemma hwand_himpl_l : forall H1' H1 H2,
  H1' ==> H1 ->
  (H1 \-* H2) ==> (H1' \-* H2).
Proof using.
  intros. unfold hwand. hsimpl ;=> H3 M. hchanges M. hchanges H.
Qed.

Lemma hwand_cancel : forall H1 H2,
  H1 \* (H1 \-* H2) ==> H2.
Proof using.
  intros. unfold hwand. hsimpl ;=> H3 M. hchanges M.
Qed.

Arguments hwand_cancel : clear implicits.

Lemma hwand_move_r : forall H1 H2 H3,
  H1 ==> (H2 \-* H3) ->
  H1 \* H2 ==> H3.
Proof using.
  introv M. hchange (>> himpl_frame_r H2 M).
  rew_heap. apply hwand_cancel.
Qed.

Lemma hwand_move_l_pure : forall H1 H2 (P:Prop),
  (P -> H1 ==> H2) ->
  H1 ==> (\[P] \-* H2).
Proof using. introv M. applys hwand_move_l. hsimpl*. Qed.

Lemma hwand_cancel_part : forall H1 H2 H3,
  H1 \* ((H1 \* H2) \-* H3) ==> (H2 \-* H3).
Proof using.
  intros. unfold hwand. hsimpl ;=> H4 M. hchanges M.
Qed.

Arguments hwand_cancel_part : clear implicits.

Lemma hwand_move_part_r : forall H1 H2 H3 H4,
  H2 ==> ((H1 \* H3) \-* H4) ->
  H1 \* H2 ==> (H3 \-* H4).
Proof using.
  introv M. hchange (>> himpl_frame_r H1 M).
  rew_heap. apply hwand_cancel_part.
Qed.

Lemma hwand_move_part_l : forall H1 H2 H3 H4,
  H1 \* H2 ==> (H3 \-* H4) ->
  H2 ==> ((H1 \* H3) \-* H4).
Proof using.
  introv M. unfold hwand. hsimpl. hchanges (hwand_move_r M).
Qed.

Lemma hstar_hwand : forall H1 H2 H3,
  (H1 \-* H2) \* H3 ==> H1 \-* (H2 \* H3).
Proof using.
  intros. unfold hwand. hsimpl ;=> H4 M. hchanges M.
Qed.

Arguments hstar_hwand : clear implicits.

Lemma hstar_qwand : forall H A (Q1 Q2:A->hprop),
  (Q1 \--* Q2) \* H ==> Q1 \--* (Q2 \*+ H).
Proof using.
  intros. unfold qwand. hchanges hstar_hforall.
  applys himpl_hforall. intros x.
  hchanges hstar_hwand.
Qed.

Lemma hwand_hpure_himpl : forall (P:Prop) H1 H2,
  P ->
  H1 ==> H2 ->
  \[P] \-* H1 ==> H2.
Proof using.
  introv N M. intros h Hh. lets U: (conj N Hh).
  rewrite <- hstar_pure in U. lets U': hwand_cancel U. applys* M.
Qed.


(* ---------------------------------------------------------------------- *)
(* ** Properties of [qwand] *)

Lemma qwand_himpl_hwand: forall A (x:A) (Q1 Q2:A->hprop),
  (Q1 \--* Q2) ==> (Q1 x \-* Q2 x).
Proof using.
  intros. unfold qwand, hforall. intros h. auto.
Qed.

Arguments qwand_himpl_hwand [ A ].

Lemma qwand_cancel : forall A (Q1 Q2:A->hprop),
  Q1 \*+ (Q1 \--* Q2) ===> Q2.
Proof using.
  intros. intros x.
  hchange (qwand_himpl_hwand x Q1 Q2).
  hchanges (hwand_cancel (Q1 x)).
Qed.

Lemma qwand_cancel_part : forall H A (Q1 Q2:A->hprop),
  H \* ((Q1 \*+ H) \--* Q2) ==> (Q1 \--* Q2).
Proof using.
  intros. unfold qwand. rewrite hstar_comm. hchange hstar_hforall. rew_heap.
  applys himpl_hforall. intros x.
  rewrite hstar_comm. rewrites (>> hstar_comm (Q1 x) H).
  hchanges (hwand_cancel_part H).
Qed.

Lemma qwand_himpl_r : forall A (Q1 Q2 Q2':A->hprop),
  Q2 ===> Q2' ->
  (Q1 \--* Q2) ==> (Q1 \--* Q2').
Proof using.
  introv M. unfold qwand. applys himpl_hforall.
  intros x. applys* hwand_himpl_r.
Qed.


(* ********************************************************************** *)
(** * Properties of [is_local] *)

(** Remark: for conciseness, we abbreviate names of lemmas,
    e.g. [is_local_inv_frame] is named [local_conseq_frame]. *)

Section IsLocal.
Variables (B : Type).
Implicit Types (F : ~~B).
Hint Resolve haffine_hempty.

(** A introduction rule to establish [is_local], exposing the definition *)

Lemma is_local_intro : forall F,
  (forall H Q, 
    (H ==> \exists H1 H2 Q1, H1 \* H2 \*
             \[F H1 Q1 /\ Q1 \*+ H2 ===> Q \*+ \GC]) ->
    F H Q) ->
  is_local F.
Proof using. auto. Qed.

(** An elimination rule for [is_local] *)

Lemma is_local_elim : forall F H Q,
  is_local F ->
  (H ==> \exists H1 H2 Q1, H1 \* H2 \* \[F H1 Q1 /\ Q1 \*+ H2 ===> Q \*+ \GC]) ->
  F H Q.
Proof using. auto. Qed.

(** An elimination rule for [is_local] without [htop] *)

Lemma is_local_elim_frame : forall F H Q,
  is_local F ->
  (H ==> \exists H1 H2 Q1, H1 \* H2 \* \[F H1 Q1 /\ Q1 \*+ H2 ===> Q]) ->
  F H Q.
Proof using. 
  introv L M. applys~ is_local_elim. hchange M.
  hpull ;=> H1 H2 Q1 (N1&N2). hsimpl H1 H2 Q1. split~. hchanges~ N2.
Qed.

(** An elimination rule for [is_local] specialized for no frame, and no [htop] *)

Lemma is_local_elim_conseq_pre : forall F H Q,
  is_local F ->
  (H ==> \exists H1, H1 \* \[F H1 Q]) ->
  F H Q.
Proof using.
  introv L M. applys~ is_local_elim_frame. hchange M.
  hpull ;=> H1 N. hsimpl H1 \[] Q. splits*. hsimpl.
Qed.

(** Weaken and frame and gc property [local] *)

Lemma is_local_conseq_frame_hgc : forall F H H1 H2 Q1 Q,
  is_local F ->
  F H1 Q1 ->
  H ==> H1 \* H2 ->
  Q1 \*+ H2 ===> Q \*+ \GC ->
  F H Q.
Proof using.
  introv L M WH WQ. applys~ is_local_elim. hchanges* WH.
Qed.

(** Weaken and frame properties from [local] *)

Lemma is_local_conseq_frame : forall H1 H2 Q1 F H Q,
  is_local F ->
  F H1 Q1 ->
  H ==> H1 \* H2 ->
  Q1 \*+ H2 ===> Q ->
  F H Q.
Proof using.
  introv L M WH WQ. applys* is_local_conseq_frame_hgc M. hchanges~ WQ.
Qed.

(** Frame rule *)

Lemma is_local_frame : forall H2 Q1 H1 F,
  is_local F ->
  F H1 Q1 ->
  F (H1 \* H2) (Q1 \*+ H2).
Proof using. introv L M. applys~ is_local_conseq_frame M. Qed.

(** Ramified frame rule *)

Lemma is_local_ramified_frame : forall Q1 H1 F H Q,
  is_local F ->
  F H1 Q1 ->
  H ==> H1 \* (Q1 \--* Q) ->
  F H Q.
Proof using.
  introv L M WH. applys~ is_local_conseq_frame (Q1 \--* Q) M.
  hchanges qwand_cancel.
Qed.

(** Ramified frame rule with \GC *)

Lemma is_local_ramified_frame_hgc : forall Q1 H1 F H Q,
  is_local F ->
  F H1 Q1 ->
  H ==> H1 \* (Q1 \--* Q \*+ \GC) ->
  F H Q.
Proof using.
  introv L M WH. applys~ is_local_conseq_frame_hgc (Q1 \--* Q \*+ \GC) M.
  hchanges qwand_cancel.
Qed.

(** Consequence rule *)

Lemma is_local_conseq : forall H' Q' F H Q,
  is_local F ->
  F H' Q' ->
  H ==> H' ->
  Q' ===> Q ->
  F H Q.
Proof using.
  introv L M WH WQ. applys* is_local_conseq_frame_hgc \[] M. 
  { hsimpl*. } { hchanges WQ. }
Qed.

(** Garbage collection on precondition from [local] *)

Lemma is_local_hgc_pre : forall F H Q,
  is_local F ->
  F H Q ->
  F (H \* \GC) Q.
Proof using. introv L M. applys~ is_local_conseq_frame_hgc M. Qed.

Lemma is_local_conseq_pre_hgc : forall H' F H Q,
  is_local F ->
  H ==> H' \* \GC ->
  F H' Q ->
  F H Q.
Proof using. introv L WH M. applys* is_local_conseq_frame_hgc M. Qed.

(** Garbage collection on postcondition from [local] *)

Lemma is_local_hgc_post : forall F H Q,
  is_local F ->
  F H (Q \*+ \GC) ->
  F H Q.
Proof using. introv L M. applys* is_local_conseq_frame_hgc \[] M; hsimpl. Qed.

Lemma is_local_conseq_post_hgc : forall Q' F H Q,
  is_local F ->
  F H Q' ->
  Q' ===> Q \*+ \GC ->
  F H Q.
Proof using.
  introv L M WQ. applys* is_local_conseq_frame_hgc \[] M.
  { hsimpl. } { hchanges WQ. }
Qed.

(** Variant of the above, useful for tactics to specify
    the garbage collected part *)

Lemma is_local_hgc_pre_on : forall HG H' F H Q,
  is_local F ->
  haffine HG ->
  H ==> HG \* H' ->
  F H' Q ->
  F H Q.
Proof using. introv L K WH M. applys~ is_local_conseq_pre_hgc M. hchanges~ WH. Qed.

(** Weakening on pre and post with gc-post from [local] *)

Lemma is_local_conseq_hgc_post : forall H' Q' F H Q,
  is_local F ->
  F H' Q' ->
  H ==> H' ->
  Q' ===> Q \*+ \GC ->
  F H Q.
Proof using.
  introv L M WH WQ. applys~ is_local_conseq_frame_hgc \[] M.
  { hchanges WH. } { hchanges WQ. }
Qed.

(** Weakening on pre and post with gc-pre from [local] *)

Lemma is_local_conseq_hgc_pre : forall H' Q' F H Q,
  is_local F ->
  F H' Q' ->
  H ==> H' \* \GC ->
  Q' ===> Q ->
  F H Q.
Proof using.
  introv L M WH WQ. applys~ is_local_conseq_frame_hgc \GC M.
  { hchanges WQ. }
Qed.

(** Weakening on pre from [local] *)

Lemma is_local_conseq_pre : forall H' F H Q,
  is_local F ->
  F H' Q ->
  H ==> H' ->
  F H Q.
Proof using. introv L M WH. applys* is_local_conseq M. Qed.

(** Weakening on post from [local] *)

Lemma is_local_conseq_post : forall Q' F H Q,
  is_local F ->
  F H Q' ->
  Q' ===> Q ->
  F H Q.
Proof using. introv L M WQ. applys* is_local_conseq M. Qed.

(** Extraction of pure facts from [local] *)

Lemma is_local_hprop : forall F H P Q,
  is_local F ->
  (P -> F H Q) ->
  F (\[P] \* H) Q.
Proof using.
  introv L M. applys~ is_local_elim_conseq_pre. hpull ;=> HP. hsimpl~ H.
Qed.

(** Extraction of existentials from [local] *)

Lemma is_local_hexists : forall F A (J:A->hprop) Q,
  is_local F ->
  (forall x, F (J x) Q) ->
  F (hexists J) Q.
Proof using.
  introv L M. applys~ is_local_elim_conseq_pre. hpull ;=> x. hsimpl* (J x).
Qed.

(** Extraction of existentials below a star from [local] *)

Lemma is_local_hstar_hexists : forall F H A (J:A->hprop) Q,
  is_local F ->
  (forall x, F ((J x) \* H) Q) ->
   F (hexists J \* H) Q.
Proof using.
  introv L M. rewrite hstar_hexists. applys~ is_local_hexists.
Qed.

(** Extraction of forall from [local] *)

Lemma is_local_hforall : forall A (x:A) F (J:A->hprop) Q,
  is_local F ->
  F (J x) Q ->
  F (hforall J) Q.
Proof using.
  introv L M. applys~ is_local_elim_conseq_pre.
  applys himpl_hforall_l. exists x. hsimpl~ (J x).
Qed.

Lemma is_local_hforall_exists : forall F A (J:A->hprop) Q,
  is_local F ->
  (exists x, F (J x) Q) ->
  F (hforall J) Q.
Proof using. introv L (x&M). applys* is_local_hforall. Qed.

(** Extraction of forall below a star from [local] *)
(* TODO needed? *)

Lemma is_local_hstar_hforall_l : forall F H A (J:A->hprop) Q,
  is_local F ->
  (exists x, F ((J x) \* H) Q) ->
  F (hforall J \* H) Q.
Proof using.
  introv L (x&M). 
  applys is_local_conseq_pre; [ auto | | applys hstar_hforall ].
  (* TODO: fix level for notation \forall and \hstar, so that parentheses show up *)
  (* above line same as: xchanges hstar_hforall. *)
  applys* is_local_hforall.
Qed.

(** Case analysis for [hor] *)

Lemma is_local_hor : forall F H1 H2 Q,
  is_local F ->
  F H1 Q ->
  F H2 Q ->
  F (hor H1 H2) Q.
Proof using. introv L M1 M2. apply* is_local_hexists. intros b. case_if*. Qed.

(** Left branch for [hand] *)

Lemma is_local_hand_l : forall F H1 H2 Q,
  is_local F ->
  F H1 Q ->
  F (hand H1 H2) Q.
Proof using. introv L M1. applys* is_local_hforall true. Qed.

(** Right branch for [hand] *)

Lemma is_local_hand_r : forall F H1 H2 Q,
  is_local F ->
  F H2 Q ->
  F (hand H1 H2) Q.
Proof using. introv L M1. applys* is_local_hforall false. Qed.

(** Extraction of heap representation from [local] *)

Lemma is_local_name_heap : forall F H Q,
  is_local F ->
  (forall h, H h -> F (= h) Q) ->
  F H Q.
Proof using.
  introv L M. applys~ is_local_elim_conseq_pre.
  intros h Hh. exists (= h). rewrite hstar_comm.
  applys* himpl_hpure_r (= h).
Qed.

(** Extraction of pure facts from the precondition under is_local *)

Lemma is_local_prop : forall F H Q P,
  is_local F ->
  (H ==> H \* \[P]) ->
  (P -> F H Q) ->
  F H Q.
Proof using.
  introv L WH M. applys~ is_local_elim_conseq_pre.
  hchanges WH. rew_heap~.
Qed.

(** Extraction of proof obligations from the precondition under is_local *)

Lemma is_local_hwand_hpure_l : forall F (P:Prop) H Q,
  is_local F ->
  P ->
  F H Q ->
  F (\[P] \-* H) Q.
Proof using.
  introv L HP M. applys~ is_local_elim_conseq_pre.
  applys~ hwand_hpure_himpl. hsimpl~. rew_heap~.
  (* TODO: should hsimpl call rew_heap to clean pure heaps when done? *)
Qed.

End IsLocal.

Global Opaque is_local.


(* ********************************************************************** *)
(** * Definition of the predicate transformer [local] *)
(* TODO needed? *)

(** Remark: this section might be specific to old-style characteristic formulae *)

(** The [local] predicate is a predicate transformer that allows
    to turn a formula into a local formula. *)

Definition local B (F:~~B) : ~~B :=
  fun (H:hprop) (Q:B->hprop) =>
    H ==> \exists H1 H2 Q1,
       H1 \* H2 \* \[F H1 Q1 /\ Q1 \*+ H2 ===> Q \*+ \GC].

Section Local.
Transparent is_local.
Variables (B:Type).
Implicit Types (F:~~B).

(** The [local] operator can be freely erased from a conclusion *)

Lemma local_erase : forall F H Q,
  F H Q ->
  local F H Q.
Proof using.
  introv M. unfold local. hsimpl H \[]. splits*. hsimpl.
Qed.

(** [local] is idempotent, i.e. nested applications
   of [local] are redundant *)

Lemma local_local : forall F,
  local (local F) = local F.
Proof using.
  extens. intros H Q. iff M.
  { unfold local. eapply himpl_trans; [apply M|]. hpull ;=> H1 H2 Q1 [P1 P2].
    unfold local in P1. hchange P1. hpull ;=> H1' H2' Q1' [P1' P2'].
    applys himpl_hexists_r H1'. hsimpl. splits*. hchange P2'. hchange P2. hsimpl. }
  { apply~ local_erase. }
Qed.

(** The predicate [local] satisfies [is_local] *)

Lemma is_local_local : forall F,
  is_local (local F).
Proof using. introv M. rewrite <- local_local. applys M. Qed.

(** A [local] can be introduced at the head of a formula satisfying [is_local] *)

Lemma eq_local_of_is_local : forall F,
  is_local F -> 
  F = local F.
Proof using.
  introv L. applys pred_ext_2. intros H Q. iff M.
  { applys~ local_erase. }
  { applys~ is_local_elim. }
Qed.

(** [local] is a covariant transformer w.r.t. predicate inclusion *)

Lemma local_weaken : forall F F',
  F ===> F' ->
  local F ===> local F'.
Proof using.
  unfold local. introv M. intros H Q N. eapply himpl_trans. apply N.
  hsimpl;=> H1 H2 Q' [P1 P2]. split; [apply M, P1|auto].
Qed.

(** Extraction of contradictions from the precondition under local *)

Lemma local_false : forall F H Q,
  local F H Q ->
  (forall H' Q', F H' Q' -> False) ->
  (H ==> \[False]).
Proof using.
  introv M N. hchange M. hpull ;=> H' H1 Q' [HF _]. false* N.
Qed.

End Local.


(* ********************************************************************** *)
(* * Tactics for triples and characteristic formulae *)

(* ---------------------------------------------------------------------- *)
(* ** Tactic [xlocal] to prove side-conditions of the form [local F]. *)

Ltac xlocal_base tt :=
  auto 1.

(* e.g.
Ltac xlocal_base tt ::=
  try first [ applys is_local_local ].
*)

Ltac xlocal_unfold_pred tt :=
  try match goal with |- is_local_pred ?S =>
    let r := fresh "TEMP" in intros r end.

Ltac xlocal_core tt :=
  try first [ assumption | xlocal_unfold_pred tt; xlocal_base tt ].

Tactic Notation "xlocal" :=
  xlocal_core tt.


(* ---------------------------------------------------------------------- *)
(* ** Tactic [xpull_check] tests whether it would be useful
      to call [xpull] to extract things from the precondition.
      Applies to a goal of the form [F H Q]. *)

Ltac xpull_check tt :=
  let H := xprecondition tt in
  hpull_check_rec H.


(* ---------------------------------------------------------------------- *)
(* ** Tactic [xpull] to extract existentials and pure facts from
      preconditions. *)

(** [xpull] plays a similar role to [hpull], except that it works on
   goals of the form [F H Q], where [F] is typically a triple predicate
   or a characteristic formula.

   [xpull] simplifies the precondition [H] as follows:
   - it removes empty heap predicates
   - it pulls pure facts out as hypotheses into the context
   - it pulls existentials as variables into the context.

   At the end, it regeneralizes in the goals the new variables
   from the context, so as to allow the user to introduce them
   by giving appropriate names. *)


(** Lemmas *)

Lemma xpull_start : forall B (F:~~B) H Q,
  F (\[] \* H) Q -> F H Q.
Proof using. intros. rew_heap in *. auto. Qed.

Lemma xpull_keep : forall B (F:~~B) H1 H2 H3 Q,
  F ((H2 \* H1) \* H3) Q -> F (H1 \* (H2 \* H3)) Q.
Proof using. intros. rewrite (hstar_comm H2) in H. rew_heap in *. auto. Qed.

Lemma xpull_assoc : forall B (F:~~B) H1 H2 H3 H4 Q,
  F (H1 \* (H2 \* (H3 \* H4))) Q -> F (H1 \* ((H2 \* H3) \* H4)) Q.
Proof using. intros. rew_heap in *. auto. Qed.

Lemma xpull_starify : forall B (F:~~B) H1 H2 Q,
  F (H1 \* (H2 \* \[])) Q -> F (H1 \* H2) Q.
Proof using. intros. rew_heap in *. auto. Qed.

Lemma xpull_empty : forall B (F:~~B) H1 H2 Q,
  (F (H1 \* H2) Q) -> F (H1 \* (\[] \* H2)) Q.
Proof using. intros. rew_heap. auto. Qed.

Lemma xpull_hprop : forall B (F:~~B) H1 H2 P Q,
  is_local F -> (P -> F (H1 \* H2) Q) -> F (H1 \* (\[P] \* H2)) Q.
Proof using.
  intros. rewrite hstar_comm_assoc. apply~ is_local_hprop.
Qed.

Lemma xpull_id : forall A (x X : A) B (F:~~B) H1 H2 Q,
  is_local F -> (x = X -> F (H1 \* H2) Q) -> F (H1 \* (x ~> Id X \* H2)) Q.
Proof using. intros. unfold Id. apply~ xpull_hprop. Qed.

Lemma xpull_hexists : forall B (F:~~B) H1 H2 A (J:A->hprop) Q,
  is_local F ->
  (forall x, F (H1 \* ((J x) \* H2)) Q) ->
   F (H1 \* (hexists J \* H2)) Q.
Proof using.
  intros. rewrite hstar_comm_assoc. apply~ is_local_hstar_hexists.
  intros. rewrite~ hstar_comm_assoc.
Qed.

Ltac xpull_setup tt :=
  pose ltac_mark;
  intros;
  try match goal with |- ?H ==> ?H' =>
        fail 100 "you should call hpull, not xpull" end;
  hpull_xpull_iris_hook tt;
  apply xpull_start.

Ltac xpull_post_processing_for_hyp H :=
  idtac.

Ltac xpull_cleanup tt :=
  remove_empty_heaps_formula tt;
  gen_until_mark_with_processing ltac:(xpull_post_processing_for_hyp).

Ltac xpull_hprop tt :=
  apply xpull_hprop; [ try xlocal | intro ].
Ltac xpull_hexists tt :=
  apply xpull_hexists; [ try xlocal | intro ].
Ltac xpull_id tt :=
  apply xpull_id; [ try xlocal | intro ].

Ltac xpull_step tt :=
  let go HP :=
    match HP with _ \* ?HN =>
    match HN with
    | ?H \* _ =>
      match H with
      | \[] => apply xpull_empty
      | \[_] => xpull_hprop tt
      | hexists _ => xpull_hexists tt
      | _ ~> Id _ => xpull_id tt
      | _ \* _ => apply xpull_assoc
      | _ => apply xpull_keep
      end
    | \[] => fail 1
    | _ => apply xpull_starify
    end end in
  on_formula_pre ltac:(go).

Ltac xpull_main tt :=
  xpull_setup tt;
  (repeat (xpull_step tt));
  xpull_cleanup tt.

Tactic Notation "xpull" := xpull_main tt.
Tactic Notation "xpull" "~" := xpull; auto_tilde.
Tactic Notation "xpull" "*" := xpull; auto_star.

Ltac xpulls_main tt :=
  xpull_main tt; intros_var_eq_subst tt.

Tactic Notation "xpulls" := xpulls_main tt.
Tactic Notation "xpulls" "~" := xpulls; auto_tilde.
Tactic Notation "xpulls" "*" := xpulls; auto_star.


(* ---------------------------------------------------------------------- *)
(* ** [xapply] and [xapplys] *)

(** [xapply E] applies a lemma [E] modulo frame/weakening.
    It applies to a goal of the form [F H Q], and replaces it
    with [F ?H' ?Q'], applies [E] to the goal, then produces
    the side condition [H ==> ?H'] and,
    - if [Q] is instantiated, then leaves [?Q' ===> Q \* \GC]
    - otherwise it instantiates [Q] with [Q'].

    [xapplys E] is like [xapply E] but also attemps to simplify
    the subgoals using [hsimpl].
*)

Ltac xapply_core H cont1 cont2 :=
  forwards_nounfold_then H ltac:(fun K =>
    match xpostcondition_is_evar tt with
    | true => eapply is_local_conseq_frame; [ xlocal | sapply K | cont1 tt | try apply qimpl_refl ]
    | false => eapply is_local_conseq_frame_hgc; [ xlocal | sapply K | cont1 tt | cont2 tt ]
    end).

Ltac xapply_base H :=
  xpull_check tt;
  xapply_core H ltac:(fun tt => idtac) ltac:(fun tt => idtac).

Ltac xapplys_base H :=
  xpull_check tt;
  xapply_core H ltac:(fun tt => hcancel) ltac:(fun tt => hsimpl).

Tactic Notation "xapply" constr(H) :=
  xapply_base H.
Tactic Notation "xapply" "~" constr(H) :=
  xapply H; auto_tilde.
Tactic Notation "xapply" "*" constr(H) :=
  xapply H; auto_star.

Tactic Notation "xapplys" constr(H) :=
  xapplys_base H.
Tactic Notation "xapplys" "~" constr(H) :=
  xapplys H; auto_tilde.
Tactic Notation "xapplys" "*" constr(H) :=
  xapplys H; auto_star.


(*--------------------------------------------------------*)
(* ** [xchange] *)

(** [xchange E] applies to a goal of the form [F H Q]
    and to a lemma [E] of type [H1 ==> H2] or [H1 = H2].
    It replaces the goal with [F H' Q], where [H']
    is computed by replacing [H1] with [H2] in [H].

    The substraction is computed by solving [H ==> H1 \* ?H']
    with [hsimpl]. If you need to solve this implication by hand,
    use [xchange_no_simpl E] instead.

    [xchange <- E] is useful when [E] has type [H2 = H1]
      instead of [H1 = H2].

    [xchange_show E] is useful to visualize the instantiation
    of the lemma used to implement [xchange].
    *)

(* Lemma used by [xchange] *)

Lemma xchange_lemma : forall H1 H1' H2 B H Q (F:~~B),
  is_local F ->
  (H1 ==> H1') ->
  (H ==> H1 \* H2) ->
  F (H1' \* H2) Q ->
  F H Q.
Proof using.
  introv W1 L W2 M. applys is_local_conseq_frame __ \[]; eauto.
  hsimpl. hchange~ W2. hsimpl~. rew_heap~.
Qed.

Ltac xchange_apply L cont1 cont2 :=
   eapply xchange_lemma;
     [ try xlocal | applys L | cont1 tt | cont2 tt (*xtag_pre_post*) ].

(* Note: the term modif should be either himpl_of_eq or himpl_of_eq_sym *)
Ltac xchange_forwards L modif cont1 cont2 :=
  forwards_nounfold_then L ltac:(fun K =>
  match modif with
  | __ =>
     match type of K with
     | _ = _ => xchange_apply (@himpl_of_eq _ _ _ K) cont1 cont2
     | _ => xchange_apply K cont1 cont2
     end
  | _ => xchange_apply (@modif _ _ _ K) cont1 cont2
  end).

Ltac xchange_with_core cont1 cont2 H H' :=
  eapply xchange_lemma with (H1:=H) (H1':=H');
    [ try xlocal | | cont1 tt | cont2 tt (* xtag_pre_post*)  ].

Ltac xchange_core cont1 cont2 E modif :=
  match E with
  | ?H ==> ?H' => xchange_with_core cont1 cont2 H H'
  | _ => xchange_forwards E modif
          ltac:(fun _ => instantiate; cont1 tt)
          ltac:(fun _ => instantiate; cont2 tt)
  end.

Ltac xchange_base cont1 cont2 E modif :=
  xpull_check tt;
  match goal with
  | |- _ ==> _ => hchange_core E modif ltac:(hcancel_cont) cont2
  | |- _ ===> _ => hchange_core E modif ltac:(hcancel_cont) cont2
  | _ => xchange_core cont1 cont2 E modif
  end.

Ltac hpull_or_xpull tt :=
  match goal with
  | |- _ ==> _ => hpull
  | |- _ ===> _ => hpull
  | |- _ => xpull
  end.

Tactic Notation "xchange" constr(E) :=
  xchange_base ltac:(fun tt => hsimpl) ltac:(idcont) E __.
Tactic Notation "xchange" "~" constr(E) :=
  xchange E; auto_tilde.
Tactic Notation "xchange" "*" constr(E) :=
  xchange E; auto_star.

Tactic Notation "xchange" "<-" constr(E) :=
  xchange_base ltac:(fun tt => hsimpl) ltac:(idcont) E himpl_of_eq_sym.
Tactic Notation "xchange" "~" "<-" constr(E) :=
  xchange <- E; auto_tilde.
Tactic Notation "xchange" "*" "<-" constr(E) :=
  xchange <- E; auto_star.

Tactic Notation "xchanges" constr(E) :=
  xchange_base ltac:(fun tt => hsimpl) ltac:(fun tt => hpull_or_xpull tt) E __.
Tactic Notation "xchanges" "~" constr(E) :=
  xchanges E; auto_tilde.
Tactic Notation "xchanges" "*" constr(E) :=
  xchanges E; auto_star.

Tactic Notation "xchange_no_simpl" constr(E) :=
  xchange_base ltac:(idcont) ltac:(idcont)E __.
Tactic Notation "xchange_no_simpl" "<-" constr(E) :=
  xchange_base ltac:(idcont) E himpl_of_eq_sym.

Tactic Notation "xchange_show" constr(E) :=
  xchange_forwards E __ ltac:(idcont) ltac:(idcont).
Tactic Notation "xchange_show" "<-" constr(E) :=
  xchange_forwards himpl_of_eq_sym ltac:(idcont) ltac:(idcont).



(* ********************************************************************** *)
(* * Weakest-preconditions *)

(* ---------------------------------------------------------------------- *)
(* ** Definition of the weakest precondition for a formula *)

Definition weakestpre (B : Type) (F:hprop->(B->hprop)->Prop) (Q:B->hprop) : hprop :=
  \exists (H:hprop), H \* \[F H Q].

Lemma weakestpre_eq : forall B (F:~~B) H Q,
  is_local F -> (* in fact, only requires weaken-pre and extract-hexists rules to hold *)
  F H Q = (H ==> weakestpre F Q).
Proof using.
  introv L. applys prop_ext. unfold weakestpre. iff M.
  { hsimpl. rew_heap~. }
  { applys~ is_local_conseq_pre M. xpull~. }
Qed.

Lemma weakestpre_conseq : forall B (F:~~B) Q1 Q2,
  is_local F ->
  Q1 ===> Q2 ->
  weakestpre F Q1 ==> weakestpre F Q1.
Proof using.
  introv L W. unfold weakestpre. hpull ;=> H1 M. hsimpl. xapplys M.
Qed.

Lemma weakestpre_conseq_wand : forall B (F:~~B) Q1 Q2, 
  is_local F ->
  (Q1 \--* Q2) \* weakestpre F Q1 ==> weakestpre F Q2.
Proof using.
  introv L. unfold weakestpre. hpull ;=> H1 M.
  hsimpl. rew_heap. xapplys M. intros r.
  hchange (qwand_himpl_hwand r).
  hchanges (hwand_cancel (Q1 r)).
Qed.

Lemma weakestpre_frame : forall B (F:~~B) H Q,
  is_local F ->
  (weakestpre F Q) \* H ==> weakestpre F (Q \*+ H).
Proof using.
  introv L. unfold weakestpre. hpull ;=> H1 M. hsimpl. xapplys M.
Qed.

Lemma weakestpre_absorb : forall B (F:~~B) Q,
  is_local F ->
  weakestpre F Q \* \GC ==> weakestpre F Q.
Proof using.
  introv L. unfold weakestpre. hpull ;=> H1 M. hsimpl. xapplys M.
Qed.

Lemma weakestpre_pre : forall B (F:~~B) Q,
  is_local F ->
  F (weakestpre F Q) Q.
Proof using. intros. unfold weakestpre. xpull ;=> H'. auto. Qed.

Lemma himpl_weakestpre : forall B (F:~~B) H Q,
  F H Q ->
  H ==> weakestpre F Q.
Proof using. introv M. unfold weakestpre. hsimpl~ H. Qed.



(* ********************************************************************** *)
(* * Tactics for representation predicates *)

(* ---------------------------------------------------------------------- *)
(* ** Tactic [xunfold] to unfold heap predicates *)

(** For technical reasons, on a heap predicate [x ~> R X],
  and due to the opacity of the arrow (needed to avoid undesired
  simplifications), a call to [unfold R] does not perform the
  desired unfolding of the representation predicate [R] in the
  form [Rbody X x], but instead leaves something of the
  form [x ~> (fun x' => Rbody X x')]. The latter is  logically
  equivalent to [(fun x' => Rbody X x') x)] and thus to [Rbody X x],
  but it does not simplify by [simpl] as desired.

  The tactic [xunfold] is meant for performing the desired
  unfolding. Its implementation is a bit of a hack, due to limitations
  of [rewrite], which does not work smoothly under binders, and
  fails to properly identify the beta-redex that could be simplified. *)


(** [xunfold at n] unfold the definition of the arrow [~>]
    at the occurence [n] in the goal. *)

Definition repr' (A:Type) (S:A->hprop) (x:A) : hprop := S x.

Ltac xunfold_at_core n :=
  let h := fresh "temp" in
  ltac_set (h := repr) at n;
  change h with repr';
  unfold repr';
  clear h.

Tactic Notation "xunfold" "at" constr(n) :=
  xunfold_at_core n.

(** [xunfold_clean] simplifies instances of
   [p ~> (fun _ => _)] by unfolding the arrow,
   but only when the body does not captures
   locally-bound variables. This tactic should
   normally not be used directly *)

Ltac xunfold_clean_core tt :=
  repeat match goal with |- context C [?p ~> ?E] =>
   match E with (fun _ => _) =>
     let E' := eval cbv beta in (E p) in
     let G' := context C [E'] in
     let G := match goal with |- ?G => G end in
     change G with G' end end.

Tactic Notation "xunfold_clean" :=
  xunfold_clean_core tt.

(** [xunfold E] unfolds all occurences of the representation
    predicate [E].
    Limitation: won't work if E has more than 12 arguments.

    Implementation: converts all occurences of repr to repr',
    then unfolds these occurences one by one, and considers
    them for unfolding. *)

Ltac xunfold_arg_core E :=
  let E := get_head E in (* to get rid of typeclasses arguments *)
  change repr with repr';
  let h := fresh "temp" in
  set (h := repr');
  repeat (
    unfold h at 1;
    let ok := match goal with
      | |- context [ repr' (E) _ ] => constr:(true)
      | |- context [ repr' (E _) _ ] => constr:(true)
      | |- context [ repr' (E _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
      | |- context [ repr' (E _ _ _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
      | _ => constr:(false)
      end in
    match ok with
    | true => unfold repr'
    | false => change repr' with repr
    end);
  clear h;
  first [ progress (simpl E) | unfold E ].

Tactic Notation "xunfold" constr(E) :=
  xunfold_arg_core E.
Tactic Notation "xunfold" "~" constr(E) := xunfold E; auto_tilde.
Tactic Notation "xunfold" "*" constr(E) := xunfold E; auto_star.

(** [xunfold E] unfolds a specific occurence of the representation
    predicate [E]. *)

Ltac xunfold_arg_at_core E n :=
  let E := get_head E in (* to get rid of typeclasses arguments *)
  let n := number_to_nat n in
  change repr with repr';
  let h := fresh "temp" in
  set (h := repr');
  let E' := fresh "tempR" in
  set (E' := E);
  let rec aux n :=
    try (
      unfold h at 1;
      let ok := match goal with
        | |- context [ repr' (E') _ ] => constr:(true)
        | |- context [ repr' (E' _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
        | |- context [ repr' (E' _ _ _ _ _ _ _ _ _ _ _ _) _ ] => constr:(true)
        | _ => constr:(false)
        end in
      match ok with
      | true =>
         match n with
         | (S O)%nat =>
            (* unfold repr' *)
            match goal with
            | |- context [ repr' (E') ?p ] =>
                change (repr' (E') p) with (E p)
            | |- context [ repr' (E' ?x1) ?p ] =>
                change (repr' (E' x1) p) with (E x1 p)
            | |- context [ repr' (E' ?x1 ?x2) ?p ] =>
                change (repr' (E' x1 x2) p) with (E x1 x2 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3) ?p ] =>
                change (repr' (E' x1 x2 x3) p) with (E x1 x2 x3 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4) ?p ] =>
                change (repr' (E' x1 x2 x3 x4) p) with (E x1 x2 x3 x4 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4 ?x5) ?p ] =>
                change (repr' (E' x1 x2 x3 x4 x5) p) with (E x1 x2 x3 x4 x5 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4 ?x5 ?x6) ?p ] =>
                change (repr' (E' x1 x2 x3 x4 x5 x6) p) with (E x1 x2 x3 x4 x5 x6 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4 ?x5 ?x6 ?x7) ?p ] =>
                change (repr' (E' x1 x2 x3 x4 x5 x6 x7) p) with (E x1 x2 x3 x4 x5 x6 x7 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4 ?x5 ?x6 ?x7 ?x8) ?p ] =>
                change (repr' (E' x1 x2 x3 x4 x5 x6 x7 x8) p) with (E x1 x2 x3 x4 x5 x6 x7 x8 p)
            | |- context [ repr' (E' ?x1 ?x2 ?x3 ?x4 ?x5 ?x6 ?x7 ?x8 ?x9) ?p ] =>
                change (repr' (E' x1 x2 x3 x4 x5 x6 x7 x8 x9) p) with (E x1 x2 x3 x4 x5 x6 x7 x8 x9 p)
           end;
            first [ progress (simpl E) | unfold E ]
         | (S ?n')%nat => change repr' with repr; aux n'
         end
      | false => change repr' with repr; aux n
      end)
     in
  aux n;
  unfold h;
  clear h;
  change repr' with repr;
  unfold E';
  clear E'.

Tactic Notation "xunfold" constr(E) "at" constr(n) :=
  xunfold_arg_at_core E n.

Ltac xunfolds_post tt :=
  first [ hpull | xpull ].

Tactic Notation "xunfolds" "at" constr(n) :=
  xunfold at n; xunfolds_post tt.

Tactic Notation "xunfolds" constr(E) :=
  xunfold E; xunfolds_post tt.

Tactic Notation "xunfolds" constr(E) "at" constr(n) :=
  xunfold E at n; xunfolds_post tt.


(* ---------------------------------------------------------------------- *)
(* ** Set [repr] to be opaque *)

Global Opaque repr.

End SepSetup.
