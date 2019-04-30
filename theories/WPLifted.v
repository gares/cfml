(**

This file formalizes characteristic formulae in weakest-precondition form
for lifted Separation Logic.

Author: Arthur Charguéraud.
License: MIT.

*)


Set Implicit Arguments.
From Sep Require Export WPBase SepLifted.
Open Scope heap_scope.
Generalizable Variables A.

Implicit Types v w : val.
Implicit Types t : trm.



(* ********************************************************************** *)
(* * WP generator *)


(* ---------------------------------------------------------------------- *)
(* ** Type of a WP *)

(** A formula is a predicate over a post-condition. *)

Definition Formula := forall A (EA:Enc A), (A -> hprop) -> hprop.

Global Instance Inhab_Formula : Inhab Formula.
Proof using. apply (Inhab_of_val (fun _ _ _ => \[])). Qed.

Notation "^ F Q" := ((F:Formula) _ _ Q)
  (at level 45, F at level 0, Q at level 0,
   format "^ F  Q") : wp_scope.

Open Scope wp_scope.
Delimit Scope wp_scope with wp.


(* ---------------------------------------------------------------------- *)
(* ** Semantic interpretation of a WP *)

(** Lifted version of [weakestpre] *)

Definition Weakestpre (T:forall `{Enc A},hprop->(A->hprop)->Prop) : Formula :=
  fun A (EA:Enc A) => weakestpre T.

(** Lifted version of [wp] *)

Definition Wp (t:trm) : Formula :=
  Weakestpre (@Triple t).

(** Lifted version of [wpsubst E t] *)

Definition Wpsubst (E:ctx) (t:trm) : Formula :=
  Wp (isubst E t).


(* ---------------------------------------------------------------------- *)
(* ** Constraining the return type *)

(** Constructor to force the return type of a Formula *)

Definition Formula_typed `{Enc A1} (F:(A1->hprop)->hprop) : Formula :=
  fun A2 (EA2:Enc A2) (Q:A2->hprop) =>
    \exists (Q':A1->hprop), F Q' \* \[RetypePost Q' Q].

(** [Wpgen_cast X Q] applies a postcondition [Q] of type [A2->hprop] to a value
    [X] of type [A1], with [X] converted on-the-fly to a value of type [A2]. *)

Definition Wpgen_cast `{Enc A1} (X:A1) A2 (EA2:Enc A2) (Q:A2->hprop) : hprop :=
  \exists (Y:A2), \[enc X = enc Y] \* Q Y.

(* TODO: is Wpgen_cast not similar to (Wpgen_val `X) *)

(* ---------------------------------------------------------------------- *)
(* ** Definition of [Local] for WP *)

(** The [Local] predicate lifts [local]. *)

Definition Local (F:Formula) : Formula :=
  fun A `{EA:Enc A} Q => mkflocal (@F A EA) Q.

Lemma mkflocal_Local_eq : forall A `{EA:Enc A} (F:Formula),
  mkflocal (@Local F A EA) = (@Local F A EA).
Proof using.
  intros. apply fun_ext_1. intros Q.
  unfold Local. rewrite mkflocal_mkflocal. split~.
Qed.

Lemma flocal_Local : forall A `{EA:Enc A} (F:Formula),
  flocal (@Local F A EA).
Proof using. intros. rewrite <- mkflocal_Local_eq. apply flocal_mkflocal. Qed.

Hint Resolve flocal_Local.


(* ---------------------------------------------------------------------- *)
(* ** Tag for improved pretty-printing of CF *)

Definition Wptag (F:Formula) : Formula := F.

Notation "'`' F" :=
  ((Wptag F%wp))
  (at level 69, F at level 100, format "'`' F") : wp_scope.


(* ---------------------------------------------------------------------- *)
(* ** Definition of CF blocks *)

(** These auxiliary definitions give the characteristic formula
    associated with each term construct. *)

Definition Wpgen_fail : Formula :=
  Local (fun A (EA:Enc A) Q =>
    \[False]).

Definition Wpgen_val (v:val) : Formula :=
  Local (fun A (EA:Enc A) Q =>
    \exists (V:A), \[v = enc V] \* Q V).

(* DEPRECATED
Definition Wpgen_val_typed `{EA1:Enc A1} (V:A1) : Formula :=
  Local (fun A (EA:Enc A) Q => Q V1).
*)

Definition Wpaux_var (E:ctx) (x:var) : Formula :=
  match Ctx.lookup x E with
  | None => `Wpgen_fail
  | Some v => `Wpgen_val v
  end.

Definition Wpgen_let (F1:Formula) (F2of:forall `{EA1:Enc A1},A1->Formula) : Formula :=
  Local (fun A (EA:Enc A) Q =>
    \exists (A1:Type) (EA1:Enc A1),
      ^F1 (fun (X:A1) => ^(F2of X) Q)).

Definition Wpgen_let_typed `{EA1:Enc A1} (F1:Formula) (F2of:A1->Formula) : Formula :=
  Local (fun `{Enc A} Q =>
    ^F1 (fun (X:A1) => ^(F2of X) Q)).

Definition Wpgen_seq (F1 F2:Formula) : Formula :=
  Local (fun A (EA:Enc A) Q =>
    ^F1 (fun (X:unit) => ^F2 Q)).

Definition Wpgen_letval (v:val) (F2of:forall `{EA1:Enc A1},A1->Formula) : Formula :=
  Local (fun A (EA:Enc A) Q =>
    \exists (A1:Type) (EA1:Enc A1) (V:A1), \[v = enc V] \* ^(F2of V) Q).

Definition Wpgen_letval_typed `{EA1:Enc A1} (v:val) (F2of:A1->Formula) : Formula :=
  Local (fun A (EA:Enc A) Q =>
    \exists (V:A1), \[v = enc V] \* ^(F2of V) Q).

Definition Wpaux_getval_typed Wpgen (E:ctx) `{EA1:Enc A1} (t1:trm) (F2of:A1->Formula) : Formula :=
  match t1 with
  | trm_val v => `Wpgen_letval_typed v F2of
  | trm_var x => match Ctx.lookup x E with
                        | Some v => `Wpgen_letval_typed v F2of
                        | None => `Wpgen_fail
                        end
  | _ => `Wpgen_let_typed (Wpgen E t1) F2of
  end.

Definition Wpaux_getval Wpgen (E:ctx) (t1:trm) (F2of:val->Formula) : Formula :=
  match t1 with
  | trm_val v => F2of v
  | trm_var x => match Ctx.lookup x E with
                        | Some v => F2of v
                        | None => `Wpgen_fail
                        end
  | _ => `Wpgen_let (Wpgen E t1) (fun `{EA1:Enc A1} (V1:A1) => F2of (``V1))
  end.

Definition Wpaux_getval_val := Wpaux_getval.

Definition Wpaux_getval_int Wpgen (E:ctx) (t1:trm) (F2of:int->Formula) : Formula :=
  match t1 with
  | trm_val (val_int n) => F2of n
  | _ => Wpaux_getval_typed Wpgen E t1 F2of
  end.

Definition Wpaux_constr Wpgen (E:ctx) (id:idconstr) : list val -> list trm -> Formula := 
  fix mk (rvs : list val) (ts : list trm) : Formula :=
    match ts with
    | nil => `Wpgen_val (val_constr id (List.rev rvs))
    | t1::ts' => Wpaux_getval Wpgen E t1 (fun v1 => mk (v1::rvs) ts')
    (* DEPRECATED Wpgen_getval_val wp E t1 (fun v1 => mk (v1::rvs) ts') *)
    end.

Definition Wpgen_app (t:trm) : Formula := 
  Local (Wp t).

Definition Wpaux_apps Wpgen (E:ctx) (v0:func) : list val -> list trm -> Formula := 
  (fix mk (rvs : list val) (ts : list trm) : Formula :=
    match ts with
    | nil => `Wpgen_app (trm_apps v0 (trms_vals (List.rev rvs)))
    | t1::ts' => Wpaux_getval Wpgen E t1 (fun v1 => mk (v1::rvs) ts')
    end).

Definition Wpaux_apps_or_prim Wpgen (E:ctx) (t0:trm) (ts:list trm) : Formula :=
  match t0, ts with
  | trm_val (val_prim val_add), (t1::t2::nil) => 
     Wpaux_getval_int Wpgen E t1 (fun n1 => 
       Wpaux_getval_int Wpgen E t2 (fun n2 => 
         `Formula_typed (fun (Q:int->hprop) => Q (n1 + n2))))
  | _,_ => Wpaux_getval_val Wpgen E t0 (fun v0 => Wpaux_apps Wpgen E v0 nil ts)
  end.

Definition Wpgen_if_val (b:bool) (F1 F2:Formula) : Formula :=
  Local (fun `{Enc A} Q =>
    if b then ^F1 Q else ^F2 Q).

Definition Wpaux_if (F0 F1 F2:Formula) : Formula :=
  `Wpgen_let_typed F0 (fun (b:bool) => `Wpgen_if_val b F1 F2).

Definition Wpgen_while (F1 F2:Formula) : Formula :=
  Local (`Formula_typed (fun (Q:unit->hprop) =>
    \forall (R:Formula),
    let F := Wpaux_if F1 (Wpgen_seq F2 R) (Wpgen_val val_unit) in
    \[ flocal (@R unit _) /\ (forall Q', ^F Q' ==> ^R Q')] \-* (^R Q))).
    (* TODO: use a lifted version of flocal *)

Definition Wpgen_for_int (n1 n2:int) (F1:int->Formula) : Formula := 
  Local (Formula_typed (fun (Q:unit->hprop) =>
    \forall (S:int->Formula),
    let F i := If (i <= n2) then (`Wpgen_seq (F1 i) (S (i+1)))
                            else (`Wpgen_val val_unit) in
    \[   (forall i, flocal (S i unit _)) 
      /\ (forall i Q', ^(F i) Q' ==> ^(S i) Q')] \-* (^(S n1) Q))).
     (* TODO: use a lifted version of flocal_pred *)

Definition Wpgen_case_val (F1:Formula) (P:Prop) (F2:Formula) : Formula :=
  Local (fun `{Enc A} Q =>
    hand (^F1 Q) (\[P] \-* ^F2 Q)).

Definition Wpaux_match Wpgen (E:ctx) (v:val) : list (pat*trm) ->  Formula :=
  fix mk (pts:list(pat*trm)) : Formula :=
    match pts with
    | nil => `Wpgen_fail
    | (p,t)::pts' =>
        let xs := patvars p in
        let F1 A (EA:Enc A) (Q:A->hprop) := 
           hforall_vars (fun G => let E' := (Ctx.app G E) in
              \[v = patsubst G p] \-* ^(Wpgen E' t) Q) Ctx.empty xs in
        let P := forall_vars (fun G => v <> patsubst G p) Ctx.empty xs in
        Wpgen_case_val F1 P (mk pts')
    end.
  (* Note: the body of the cons case above, if put in an auxiliary definition,
     does not appear to simplify well using [xwp_simpl] *)


(* ---------------------------------------------------------------------- *)
(* ** Definition of the CF generator *)

Fixpoint Wpgen (E:ctx) (t:trm) : Formula :=
  let aux := Wpgen E in
  match t with
  | trm_val v => `Wpgen_val v
  | trm_var x => Wpaux_var E x
  | trm_fixs f xs t1 =>
      match xs with 
      | nil => `Wpgen_fail
      | _ => `Wpgen_val (val_fixs f xs (isubst (Ctx.rem_vars xs (Ctx.rem f E)) t1))
      end
  | trm_constr id ts => Wpaux_constr Wpgen E id nil ts
  | trm_if t0 t1 t2 =>
     Wpaux_getval_typed Wpgen E t0 (fun b0 => 
       `Wpgen_if_val b0 (aux t1) (aux t2))
  | trm_let z t1 t2 =>
     match z with
     | bind_anon => `Wpgen_seq (aux t1) (aux t2)
     | bind_var x => `Wpgen_let (aux t1) (fun `{EA:Enc A} (X:A) => Wpgen (Ctx.add x (enc X) E) t2)
     end
  | trm_apps t0 ts => Wpaux_getval_val Wpgen E t0 (fun v0 => Wpaux_apps Wpgen E v0 nil ts)
      (* Wpgen_apps_or_prim Wpgen E t0 ts *)
  | trm_while t1 t2 => `Wpgen_while (aux t1) (aux t2)
  | trm_for x t1 t2 t3 => 
     Wpaux_getval_typed Wpgen E t1 (fun n1 =>
       Wpaux_getval_typed Wpgen E t2 (fun n2 =>
         `Wpgen_for_int n1 n2 (fun n => Wpgen (Ctx.add x (enc n) E) t3)))
  | trm_match t0 pts =>
      Wpaux_getval Wpgen E t0 (fun v0 =>
        Wpaux_match Wpgen E v0 pts)
  | trm_fail => `Wpgen_fail
  end.


(* ********************************************************************** *)
(* * Soundness proof *)

(* ---------------------------------------------------------------------- *)
(* ** Properties of semantical wp *)

(** [Wp t] is a local formula *)

Lemma flocal_Wp : forall `{EA:Enc A} t,
  flocal ((Wp t) A EA).
Proof using.
  intros. unfolds Wp. unfolds Weakestpre.
  applys flocal_weakestpre. applys is_local_Triple.
Qed.

(** Equivalence between a [triple] and its weakest-precondition presentation. *)

Lemma Triple_eq_himpl_Wp : forall `{EA:Enc A} H (Q:A->hprop) t,
  Triple t H Q = (H ==> ^(Wp t) Q).
Proof using. intros. applys weakestpre_eq. applys is_local_Triple. Qed.

(** Reformulation of the left-to-right implication above in the form
    of an entailment. *)

Lemma qimpl_Wp : forall t `{EA:Enc A} F,
  (forall Q, Triple t (F Q) Q) ->
  F ===> ((Wp t) A EA).
Proof using. introv M. intros Q. rewrite~ <- Triple_eq_himpl_Wp. Qed.

(** Another formulation of the same corrolary --- not currently used *)
Lemma himpl_Wp_of_Triple : forall A `{EA:Enc A} (Q1:A->hprop) t H1,
  Triple t H1 Q1 ->
  H1 ==> ^(Wp t) Q1.
Proof using. introv M. rewrite* <- Triple_eq_himpl_Wp. Qed.


(* ---------------------------------------------------------------------- *)
(* ** Soundness of the [local] transformer *)

(** [The [Local] transformer may be stripped from the postcondition. *)

Lemma Local_erase : forall H F `{EA:Enc A} (Q:A->hprop),
  H ==> ^F Q ->
  H ==> ^(Local F) Q.
Proof using.
  introv M. hchanges M. applys mkflocal_erase.
Qed.

(** The [Local] transformer is sound w.r.t. [Triple], in other words, it
    may be stripped from the precondition. *)

Lemma Triple_Local_pre : forall t (F:Formula) `{EA:Enc A} (Q:A->hprop),
  (forall Q, Triple t (^F Q) Q) ->
  Triple t (^(Local F) Q) Q.
Proof using.
  introv M. applys~ is_local_elim.
  unfold Local, mkflocal. hpull ;=> Q'.
  hsimpl (^F Q') ((Q' \--* Q \*+ \GC)) Q'. split~.
  { hsimpl. }
Qed.

(** The tactic [remove_Local] applies to goal of the form [triple t (local F Q) Q]
    and turns it into [triple t (F Q) Q] for a fresh [Q]. *)

Ltac remove_Local :=
  match goal with |- @Triple _ _ _ _ ?Q =>
    applys Triple_Local_pre; try (clear Q; intros Q); fold wp end.

(*
(* ---------------------------------------------------------------------- *)
(* ** Soundness of [wp] *)

(* [F1 ====> F2] asserts that a Formula entails another one at all types. *)

Notation "F1 ====> F2" := (forall `{EA:Enc A}, F1 A EA ===> F2 A EA)
  (at level 67).


(** [Wpgen_sound t] asserts that [wp] is sound for all contexts [E],
    in the sense that the syntactic wp entails the semantics wp.
    The definition below is equivalent to:
[[
    Definition Wpgen_sound t := 
       forall E `{EA:Enc A} (Q:A->hprop),
       ^(Wpgen E t) Q ==> ^(Wpsubst E t) Q.
]]
*)

Definition Wpgen_sound t := forall E,
  (Wpgen E t) ====> (Wpsubst E t).

(** Lemma for [wpgen_fail] *)

Lemma himpl_Wpgen_fail_l : forall `{EA:Enc A} (Q:A->hprop) H,
  ^Wpgen_fail Q ==> H.
Proof using. intros. unfold Wpgen_fail, Local, local. hpull. Qed.

(* TODO: use lemma below for all occurences of wpgen_fail *)
Lemma Triple_Wpgen_fail : forall t Q Q',
  Triple t (^Wpgen_fail Q) Q'.
Proof using. 
  intros. apply triple_of_wp. applys himpl_wpgen_fail_l.
Qed.

(** Soundness of the [wp] for the various constructs *)

Lemma Wpgen_sound_var : forall x,
  Wpgen_sound (trm_var x).
Proof using.
  intros. intros E A EA. simpl. applys qimpl_Wp.
  intros Q. unfold Wpgen_var. simpl. destruct (Ctx.lookup x E).
  { remove_Local. xpull ;=> V EQ. applys* Triple_val. }
  { remove_Local. xpull*. intros; false. 
    (* TODO: decide whether xpull should automatically discard goal
       when extracting false *) }
Qed.

Lemma Wpgen_sound_val : forall v,
  Wpgen_sound (trm_val v).
Proof using.
  intros. intros E A EA. simpl. applys qimpl_Wp.
  intros Q. remove_Local. xpull ;=> V EQ.
  simpl. intros. applys* Triple_val.
Qed.

Lemma Wpgen_sound_fix : forall f x t,
  Wpgen_sound (trm_fix f x t).
Proof using.
  intros. intros E A EA. simpl. applys qimpl_Wp.
  intros Q. remove_Local. xpull ;=> V EQ. simpl.
  applys Triple_enc_val_inv (fun r => \[r = enc V] \* (Q V)).
  { applys Triple_fix. rewrite EQ. hsimpl~. }
  { hpull ;=> X EX. subst X. hsimpl~. }
Qed.

Lemma Wpgen_sound_if : forall F0 F1 F2 E t0 t1 t2,
  F0 ====> (Wpsubst E t0) ->
  F1 ====> (Wpsubst E t1) ->
  F2 ====> (Wpsubst E t2) ->
  Wpgen_if F0 F1 F2 ====> Wpsubst E (trm_if t0 t1 t2).
Proof using.
  introv M0 M1 M2. intros A EA. applys qimpl_Wp. intros Q.
  remove_Local. xpull. intros _. simpl. applys Triple_if.
  { rewrite Triple_eq_himpl_Wp. applys* M0. }
  { intros b. simpl. remove_Local. case_if.
    { rewrite Triple_eq_himpl_Wp. applys* M1. }
    { rewrite Triple_eq_himpl_Wp. applys* M2. } }
Qed.

Lemma Wpgen_sound_seq : forall F1 F2 E t1 t2,
  F1 ====> Wpsubst E t1 ->
  F2 ====> Wpsubst E t2 ->
  Wpgen_seq F1 F2 ====> Wpsubst E (trm_seq t1 t2).
Proof using.
  introv M1 M2. intros A EA. applys qimpl_Wp. intros Q.
  remove_Local. simpl. applys Triple_seq.
  { rewrite Triple_eq_himpl_Wp. applys* M1. }
  { rewrite Triple_eq_himpl_Wp. applys* M2. }
Qed.

Lemma Wpgen_sound_let : forall (F1:Formula) (F2of:forall `{EA1:Enc A1},A1->Formula) E (x:var) t1 t2,
  F1 ====> Wpsubst E t1 ->
  (forall `{EA:Enc A} (X:A), F2of X ====> Wpsubst (Ctx.add x (enc X) E) t2) ->
  Wpgen_let F1 (@F2of) ====> Wpsubst E (trm_let x t1 t2).
Proof using.
  Opaque Ctx.rem.
  introv M1 M2. intros A EA. applys qimpl_Wp. intros Q.
  remove_Local. xpull ;=> A1 EA1. simpl. applys Triple_let.
  { rewrite Triple_eq_himpl_Wp. applys* M1. }
  { intros X. rewrite Triple_eq_himpl_Wp.
    unfold Subst1. rewrite <- isubst_add_eq_subst1_isubst. applys* M2. }
Qed.

Lemma Wpgen_sound_app : forall t1 t2,
  Wpgen_sound (trm_app t1 t2).
Proof using.
  intros. intros E A EA. simpl. applys qimpl_Wp.
  intros Q. remove_Local. simpl.
  rewrite Triple_eq_himpl_Wp. hsimpl.
Qed.

Lemma Wpgen_sound_while : forall F1 F2 E t1 t2,
  F1 ====> Wpsubst E t1 ->
  F2 ====> Wpsubst E t2 ->
  Wpgen_while F1 F2 ====> Wpsubst E (trm_while t1 t2).
Proof using.
  introv M1 M2. intros A EA. applys qimpl_Wp. intros Q.
  remove_Local. simpl.
  unfold Formula_typed. xpull ;=> Q' C. applys Triple_enc_change (rm C).
  set (R := Wp (trm_while (isubst E t1) (isubst E t2))).
  applys Triple_hforall R. simpl. applys Triple_hwand_hpure_l.
  { split.
    { applys @is_local_Wp. }
    { clears Q. applys qimpl_Wp. intros Q.
      applys Triple_while_raw.
      asserts_rewrite~ (
         trm_if (isubst E t1) (trm_seq (isubst E t2) (trm_while (isubst E t1) (isubst E t2))) val_unit
       = isubst E (trm_if t1 (trm_seq t2 (trm_while t1 t2)) val_unit)).
      rewrite Triple_eq_himpl_Wp. applys~ Wpgen_sound_if.
      { applys~ Wpgen_sound_seq. }
      { intros A1 EA1 Q''. applys Wpgen_sound_val. } } }
  { rewrite~ @Triple_eq_himpl_Wp. }
Qed.

Lemma Wpgen_sound_for_val : forall (x:var) v1 v2 F1 E t1,
  (forall X, F1 X ====> Wpsubst (Ctx.add x X E) t1) ->
  Wpgen_for_val v1 v2 F1 ====> Wpsubst E (trm_for x v1 v2 t1).
Proof using. Opaque Ctx.add Ctx.rem.
  introv M. intros A EA. applys qimpl_Wp. intros Q.
  remove_Local. simpl.
  unfold Formula_typed. xpull ;=> Q' n1 n2 (->&->) C.
  applys Triple_enc_change (rm C).
  set (S := fun (i:int) => Wp (isubst E (trm_for x i n2 t1))).
  applys Triple_hforall S. simpl. applys Triple_hwand_hpure_l.
  { split.
    { intros r. applys @is_local_Wp. }
    { clears Q. intros i. applys qimpl_Wp. intros Q.
      applys Triple_for_raw. fold isubst.
      rewrite~ @Triple_eq_himpl_Wp. case_if.
      { unfold Subst1. rewrite <- isubst_add_eq_subst1_isubst.
        asserts_rewrite (trm_seq (isubst (Ctx.add x (``i) E) t1) (trm_for x (i + 1)%I n2 (isubst (Ctx.rem x E) t1))
          = (isubst (Ctx.add x (``i) E) (trm_seq t1 (trm_for x (i + 1)%I n2 t1)))).
        { simpl. rewrite Ctx.rem_anon, Ctx.rem_add_same. auto. }
        applys Wpgen_sound_seq.
        { applys* M. }
        { unfold S. unfold Wp_. simpl. rewrite~ Ctx.rem_add_same. } }
      { applys Wpgen_sound_val E. } } }
  { rewrite~ @Triple_eq_himpl_Wp. }
Qed.

(** Putting it all together *)

Lemma Wpgen_sound_trm : forall t,
  Wpgen_sound t.
Proof using.
  intros t. induction t; intros E A EA Q.
  { applys Wpgen_sound_val. }
  { applys Wpgen_sound_var. }
  { applys Wpgen_sound_fix. }
  { applys* Wpgen_sound_if. }
  { (* todo factorize? *)
    destruct b as [|x].
    { applys* Wpgen_sound_seq. }
    { applys* Wpgen_sound_let. } }
  { applys* Wpgen_sound_app. }
  { applys* Wpgen_sound_while. }
  { destruct t1; try solve [ applys @himpl_Wpgen_fail_l ].
    destruct t2; try solve [ applys @himpl_Wpgen_fail_l ].
    applys* Wpgen_sound_for_val. }
Qed.
 *)


(* ---------------------------------------------------------------------- *)
(* ** Corrolaries of the soundness of [wp] *)

Lemma Triple_isubst_Wpgen : forall t E `{EA:Enc A} (Q:A->hprop),
  Triple (isubst E t) (^(Wpgen E t) Q) Q.
Proof using. Admitted. (* TODO
  intros. rewrite Triple_eq_himpl_Wp. applys Wpgen_sound_trm.
Qed.*)

Lemma Triple_isubst_of_Wpgen : forall t E H `{EA:Enc A} (Q:A->hprop),
  H ==> ^(Wpgen E t) Q ->
  Triple (isubst E t) H Q.
Proof using. introv M. xchanges M. applys Triple_isubst_Wpgen. Qed.

Lemma Triple_of_Wpgen : forall (t:trm) H `{EA:Enc A} (Q:A->hprop),
  H ==> ^(Wpgen Ctx.empty t) Q ->
  Triple t H Q.
Proof using.
  introv M. xchanges M. pattern t at 1; rewrite <- (isubst_empty t).
  applys Triple_isubst_Wpgen.
Qed.

(* not used *)
Lemma Wp_of_Wpgen : forall t H `{EA:Enc A} (Q:A->hprop),
  H ==> ^(Wpgen Ctx.empty t) Q ->
  H ==> ^(Wp t) Q.
Proof using. introv M. applys himpl_weakestpre. applys* Triple_of_Wpgen. Qed.

(* not used *)
Lemma himpl_Wpgen_app_of_Triple : forall A `{EA:Enc A} (Q:A->hprop) t H,
  Triple t H Q ->
  H ==> ^(Wpgen_app t) Q.
Proof using. intros. applys Local_erase. rewrite~ <- Triple_eq_himpl_Wp. Qed.


(* ********************************************************************** *)
(* * Notation for characteristic formulae *)

(* ---------------------------------------------------------------------- *)
(* ** Notation for computed WP *)

Notation "'Fail'" :=
  ((Wpgen_fail))
  (at level 69) : wp_scope.

Notation "'Val' v" :=
  ((Wpgen_val v))
  (at level 69) : wp_scope.

Notation "'Return' F " :=
  (Formula_typed F)
  (at level 68) : wp_scope.

Notation "'`Let' x ':=' F1 'in' F2" :=
  ((Wpgen_let_typed F1 (fun x => F2)))
  (at level 69, x ident, right associativity,
  format "'[v' '[' '`Let'  x  ':='  F1  'in' ']'  '/'  '[' F2 ']' ']'") : wp_scope.

Notation "'Let' [ A EA ] x ':=' F1 'in' F2" :=
  ((Wpgen_let F1 (fun A EA x => F2)))
  (at level 69, A at level 0, EA at level 0, x ident, right associativity,
  format "'[v' '[' 'Let'  [ A  EA ]  x  ':='  F1  'in' ']'  '/'  '[' F2 ']' ']'") : wp_scope.

Notation "'Seq' F1 ;;; F2" :=
  ((Wpgen_seq F1 F2))
  (at level 68, right associativity,
   format "'[v' 'Seq'  '[' F1 ']'  ;;;  '/'  '[' F2 ']' ']'") : wp_scope.

Notation "'`Letval' x ':=' v 'in' F2" :=
  ((Wpgen_letval_typed v (fun x => F2)))
  (at level 69, x ident, right associativity,
  format "'[v' '[' '`Letval'  x  ':='  v  'in' ']'  '/'  '[' F2 ']' ']'") : wp_scope.

Notation "'Letval' [ A EA ] x ':=' v 'in' F2" :=
  ((Wpgen_letval v (fun A EA x => F2)))
  (at level 69, A at level 0, EA at level 0, x ident, right associativity,
  format "'[v' '[' 'Letval'  [ A  EA ]  x  ':='  v  'in' ']'  '/'  '[' F2 ']' ']'") : wp_scope.
 
(*
Notation "'App' f t1 " :=
  (Wpgen_app (trm_apps f (t1::nil)))
  (at level 68, f, t1 at level 0) : wp_scope.

Notation "'App' f t1 t2 " :=
  (Wpgen_app (trm_apps f (t1::t2::nil)))
  (at level 68, f, t1, t2 at level 0) : wp_scope.

Notation "'App' f t1 t2 t3 " :=
  (Wpgen_app (trm_apps f (t1::t2::t3::nil)))
  (at level 68, f, t1, t2, t3 at level 0) : wp_scope.
*)

Notation "'App' f v1 " :=
  ((Wpgen_app (trm_apps f (trms_vals (v1::nil)))))
  (at level 68, f, v1 at level 0) : wp_scope.

Notation "'App' f v1 v2 " :=
  ((Wpgen_app (trm_apps f (trms_vals (v1::v2::nil)))))
  (at level 68, f, v1, v2 at level 0) : wp_scope.

Notation "'App' f v1 v2 v3 " :=
  ((Wpgen_app (trm_apps f (trms_vals (v1::v2::v3::nil)))))
  (at level 68, f, v1, v2, v3 at level 0) : wp_scope.

(* TODO: recursive notation for App *)

Notation "'Ifval' b 'Then' F1 'Else' F2" :=
  ((Wpgen_if_val b F1 F2))
  (at level 69) : wp_scope.

(* DEPRECATED
Notation "'If' F0 'Then' F1 'Else' F2" :=
  ((Wpgen_if F0 F1 F2))
  (at level 69, F0 at level 0) : wp_scope.
*)

Notation "'While' F1 'Do' F2 'Done'" :=
  ((Wpgen_while F1 F2))
  (at level 69, F2 at level 68,
   format "'[v' 'While'  F1  'Do'  '/' '[' F2 ']' '/'  'Done' ']'")
   : wp_scope.

Notation "'For' x '=' n1 'To' n2 'Do' F3 'Done'" :=
  ((Wpgen_for_int n1 n2 (fun x => F3)))
  (at level 69, x ident,
   format "'[v' 'For'  x  '='  n1  'To'  n2  'Do'  '/' '[' F3 ']' '/'  'Done' ']'")
  : wp_scope.


Notation "'Case' v '=' vp ''=>' F1 ''|' F2" :=
  ((Wpgen_case_val (fun A EA Q => \[v = vp%val] \-* F1 A EA Q) (v <> vp%val) F2))
  (at level 69, v, vp at level 69,
   format "'[v' 'Case'  v  '='  vp  ''=>'  '[' '/' F1 ']' '[' '/'  ''|'  F2 ']' ']'")
   : wp_scope.

Notation "'Case' v '=' vp [ x1 ] ''=>' F1 ''|' F2" :=
  ((Wpgen_case_val (fun A EA Q => \forall x1, \[v = vp%val] \-* F1 A EA Q) (forall x1, v <> vp%val) F2))
  (at level 69, v, vp at level 69, x1 ident,
   format "'[v' 'Case'  v  '='  vp  [ x1 ]  ''=>'  '[' '/' F1 ']' '[' '/'  ''|'  F2 ']' ']'")
   : wp_scope.

Notation "'Case' v '=' vp [ x1 x2 ] ''=>' F1 ''|' F2" :=
  ((Wpgen_case_val (fun A EA Q => \forall x1 x2, \[v = vp%val] \-* F1 A EA Q) (forall x1 x2, v <> vp%val) F2))
  (at level 69, v, vp at level 69, x1 ident, x2 ident,
   format "'[v' 'Case'  v  '='  vp  [ x1  x2 ]  ''=>'  '[' '/' F1 ']' '[' '/'  ''|'  F2 ']' ']'")
   : wp_scope.


(* DEPRECATED
Notation "'Match_' v 'With' ''|' vp1 ''=>' F1 ''|' vp2 ''=>' F2" :=
  (Case v = vp1%val Then F1 Else 
   Wptag (Case v = vp2%val Then F2 Else 
   Wptag (Fail))) (at level 69, v, vp1, vp2 at level 69,
   format "'[v' 'Match_'  v  'With'  '[' '/' ''|'  vp1  ''=>'  '/' F1 ']'  '[' '/' ''|'  vp2  ''=>'  '/' F2 ']' ']'")
  : wp_scope.

Notation "'Match_' v 'With' ''|' vp1 ''=>' F1 ''|' vp2 [ x21 ] ''=>' F2" :=
  (Case v = vp1%val Then F1 Else 
   Wptag (Case v = vp2%val [ x21 ] Then F2 Else 
   Wptag (Fail))) (at level 69, v, vp1, vp2 at level 69, x21 ident,
   format "'[v' 'Match_'  v  'With'  '[' '/' ''|'  vp1  ''=>'  '/' F1 ']'  '[' '/' ''|'  vp2  [ x21 ]  ''=>'  '/' F2 ']' ']'")
  : wp_scope.

Notation "'Match_' v 'With' ''|' vp1 ''=>' F1 ''|' vp2 [ x21 x22 ] ''=>' F2" :=
  (Case v = vp1%val Then F1 Else 
   Wptag (Case v = vp2%val [ x21 x22 ] Then F2 Else 
   Wptag (Fail))) (at level 69, v, vp1, vp2 at level 0, x21 ident, x22 ident,
   format "'[v' 'Match_'  v  'With'  '[' '/' ''|'  vp1  ''=>'  '/' F1 ']'  '[' '/' ''|'  vp2  [ x21  x22 ]  ''=>'  '/' F2 ']' ']'")
  : wp_scope.

Notation "'Match_' v 'With' Fof 'End'" :=
  ((Wpgen_match_val v Fof))
  (at level 69,
   format "'[v' 'Match_'  v  'With'  '/' '[' Fof ']' '/'  'End' ']'")
   : wp_scope.


*)


(* NEEDED?
Notation "'Apptrm' t " :=
  ((Wpgen_app t))
  (at level 68, t at level 0) : wp_scope.
*)


