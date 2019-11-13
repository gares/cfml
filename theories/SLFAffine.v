(**

Separation Logic Foundations

Chapter: "Affine".

Author: Arthur Charguéraud.
License: MIT.

*)

Set Implicit Arguments.
From Sep Require Export SLFDirect.

Implicit Types f : var.
Implicit Types b : bool.
Implicit Types v : val.
Implicit Types h : heap.
Implicit Types P : Prop.
Implicit Types H : hprop.
Implicit Types Q : val->hprop.


(* ####################################################### *)
(** * The chapter in a rush *)

(** This chapter introduces the notion of weakest precondition
    for Separation Logic triples. *)


(* ******************************************************* *)
(** ** Notion of weakest precondition *)



(** The "top" heap predicate, written [\Top], holds of any heap predicate.
    It plays a useful role for denoting pieces of state that needs to be
    discarded, reflecting in the logic the action of the garbage collector. *)

Definition htop : hprop :=
  fun (h:heap) => True.

Notation "\Top" := (htop).



Lemma htop_intro : forall h,
  \Top h.
Proof using. intros. hnf. auto. Qed.


Lemma htop_inv : forall h, (* Note: this lemma is of no practical interest. *)
  \Top h ->
  True.
Proof using. intros. auto. Qed.



(* ******************************************************* *)
(** ** Separation Logic triples and the garbage collection rule *)

(** To conduct verification proofs in a language equipped with a garbage
    collector, we need to be able to discard pieces of states when they
    become useless. Concretely, we need the rule shown below to hold.
    The [\Top] predicate captures any (un)desired piece of state. *)

Parameter triple_htop_post' : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.

(** Above, recall that [\Top] is defined as [fun h => True]. Thus, for 
    some value [v], the heap predicate [(Q \*+ \Top) v] holds of any state
    that decomposes as a disjoint union of the form [h1 \u h2], such that
    [Q v h1] holds. In other words, [(Q \*+ \Top) v] holds of any state
    that contains a sub-state [h1] such that [Q v h1] holds. *)

(** The definition [triple1] provided earlier does not allow deriving the
    rule [triple_htop_post']. However, we can tweak slightly the definition
    to enable it. Concretely, in the definition of [triple1], we augment the 
    postcondition of the underlying Hoare triple with an extra [\Top].
    Intuitively, this added [\Top] captures any piece of state that we do not 
    wish to mention explicitly in the postcondition.

    The updated definition, called [triple], is as follows. *)

Definition triple (t:trm) (H:hprop) (Q:val->hprop) : Prop :=
  forall (H':hprop), hoare t (H \* H') (Q \*+ H' \*+ \Top).

(** From there, we can prove that the desired rule for discarding pieces 
    of postconditions holds. We can also prove that the frame rule still holds
    for the modified definition. The proof of these two results is studied further. *)

Parameter triple_htop_post : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.

Parameter triple_frame : forall t H Q H',
  triple t H Q ->
  triple t (H \* H') (Q \*+ H').

(** Remark: it may also be useful to set up finer-grained versions of Separation Logic, 
    where only certain types of heap predicates  can be discarded, but not all. Technically, 
    only "affine" predicates may be discarded. Such a set up is discussed in the chapter
    [SLFRich.v]. *)



(** The top heap predicate [\Top] is equivalent to [\exists H, H],
    which is a heap predicate that also characterizes any state.
    Again, because we need [hexists] anyway, we prefer in practice
    to define [\Top] in terms of [hexists], as done in the definition
    of [htop'] shown below. *)

Lemma htop_eq_hexists_hprop :
  \Top = (\exists (H:hprop), H).
Proof using.
  unfold htop, hexists. apply hprop_eq. intros h. iff Hh.
  { exists (=h). auto. }
  { auto. }
Qed.

Definition htop' : hprop :=
  \exists (H:hprop), H.

(** In summary, in subsequent chapters, we assume the following definitions:

[[

  Definition htop : hprop :=
    \exists (H:hprop), H.
]]
*)




(* ******************************************************* *)
(** ** Establishing properties of [triple]: exercises. *)

(* EX1! (triple_frame) *)
(** Prove the frame rule for the actual definition of [triple].
    Take inspiration from the proof of [SL_frame_rule]. *)

Lemma triple_frame' : forall t H Q H',
  triple t H Q ->
  triple t (H \* H') (Q \*+ H').
Proof using.
(* SOLUTION *)
  introv M. unfold triple in *. rename H' into H1. intros H2.
  specializes M (H1 \* H2). applys_eq M 1 2.
  { rewrite hstar_assoc. auto. }
  { applys qprop_eq. intros v.
    repeat rewrite hstar_assoc. auto. }
(* /SOLUTION *)
Qed.

(** The other main property to establish is [triple_htop_post].

    The proof expoits associativity and commutativity of the star
    operator, as well as a property asserting that [\Top \* \Top]
    simplifies to [\Top]: both heap predicate can be used
    to describe arbitrary heaps. These properties are assumed here;
    they are proved in the next chapter ([SLFHimpl]). *)

Parameter hstar_assoc' : forall H1 H2 H3,
  (H1 \* H2) \* H3 = H1 \* (H2 \* H3).

Parameter hstar_comm : forall H1 H2,
  H1 \* H2 = H2 \* H1.

Parameter hstar_htop_htop :
  \Top \* \Top = \Top.

(* EX3! (triple_htop_post'') *)
(** Prove lemma [triple_htop_post], by unfolding the definition of [triple]
    to reveal [hoare]. Note, however, that your proof should not attempt to
    unfold the definition of a [hoare] triple. *)

Lemma triple_htop_post'' : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.
Proof using.
(* SOLUTION *)
  introv M. unfold triple in *. intros H2.
  specializes M H2. applys_eq M 1.
  { applys qprop_eq. intros v. repeat rewrite hstar_assoc.
    rewrite (hstar_comm H2).
    rewrite <- (hstar_assoc \Top \Top).
    rewrite hstar_htop_htop. auto. }
(* /SOLUTION *)
Qed.



(** Recall the final definition of [triple], as:
    [forall (H':hprop), hoare (H \* H') t (Q \*+ H' \*+ \Top)].

    This definition can also be reformulated directly in terms of union
    of heaps. All we need to do is introduce an additional piece of
    state to describe the part covered by new [\Top] predicate.

    In order to describe disjointness of the 3 pieces of heap that
    describe the final state, we first introduce an auxiliary definition:
    [Fmap.disjoint_3 h1 h2 h3] asserts that the three arguments denote
    pairwise disjoint heaps. *)

Definition fmap_disjoint_3 (h1 h2 h3:heap) : Prop :=
     Fmap.disjoint h1 h2
  /\ Fmap.disjoint h2 h3
  /\ Fmap.disjoint h1 h3.

(** We then generalize the result heap from [h1' \u h2] to
    [h1' \u h2 \u h3'], where [h3'] denotes the piece of the
    final state that is described by the [\Top] heap predicate
    that appears in the definition of [triple]. *)

Definition triple_lowlevel (t:trm) (H:hprop) (Q:val->hprop) : Prop :=
  forall h1 h2,
  Fmap.disjoint h1 h2 ->
  H h1 ->
  exists v h1' h3',
       fmap_disjoint_3 h1' h2 h3'
    /\ eval (h1 \u h2) t (h1' \u h2 \u h3') v
    /\ Q v h1'.

(** One can prove the equivalence of [triple] and [triple_lowlevel]
    following a similar proof pattern as previously. The proof is a bit
    more technical and requires additional tactic support to deal with
    the tedious disjointness conditions, so we omit the details here. *)

Parameter triple_iff_triple_lowlevel : forall t H Q,
  triple t H Q <-> triple_lowlevel t H Q.

(* INSTRUCTORS *)
(** The proof of the above lemma is included in the file [SepBase.v] from CFML2. *)
(* /INSTRUCTORS *)



(* ******************************************************* *)
(** ** The [xsimpl] tactic *)

    4. Eliminate any redundant [\Top] from the RHS.


(** Finally, [xsimpl] provides support for eliminating [\Top] on the RHS.
    First, if the RHS includes several occurences of [\Top], then they
    are replaced with a single one. *)

Lemma xsimpl_demo_rhs_htop_compact : forall H1 H2 H3 H4,
  H1 \* H2 ==> H3 \* \Top \* H4 \* \Top.
Proof using.
  intros. xsimpl.
Abort.

(** Second, if after cancellations the RHS consists of exactly
   [\Top] and nothing else, then the goal is discharged. *)

Lemma xsimpl_demo_rhs_htop : forall H1 H2 H3,
  H1 \* H2 \* H3 ==> H3 \* \Top \* H2 \* \Top.
Proof using.
  intros. xsimpl.
Abort.



Lemma himpl_example_3 : forall (p q:loc),
  p ~~~> 3 \* q ~~~> 3 ==>
  p ~~~> 3 \* \Top.
Proof using. xsimpl. Qed.


   Note: [q ~~~> 4 \* p ~~~> 3 ==> p ~~~> 3 \* \Top] would be true.


(* ******************************************************* *)
(** ** Combined structural rules *)


(** The "combined structural rule" generalizes the rule above
    by also integrating the garbage collection rule. *)

Lemma triple_conseq_frame_htop : forall H2 H1 Q1 t H Q,
  triple t H1 Q1 ->
  H ==> H1 \* H2 ->
  Q1 \*+ H2 ===> Q \*+ \Top ->
  triple t H Q.

(* EX1! (triple_conseq_frame_htop) *)
(** Prove the combined structural rule. 
    Hint: recall lemma [triple_htop_post]. *)

Proof using.
(* SOLUTION *)
  introv M WH WQ. applys triple_htop_post.
  applys~ triple_conseq_frame M WH WQ.
(* /SOLUTION *)
Qed.





(* ******************************************************* *)
(** ** Entailment lemmas for [\Top] *)

(* EX1! (himpl_htop_r) *)
(** Prove that any heap predicate entails [\Top] *)

Lemma himpl_htop_r : forall H,
  H ==> \Top.
Proof using.
(* SOLUTION *)
  intros. intros h Hh.
  applys htop_intro. (* hnf; auto. *)
(* /SOLUTION *)
Qed.

(* EX2! (hstar_htop_htop) *)
(** Prove that [\Top \* \Top] is equivalent to [\Top] *)

Lemma hstar_htop_htop :
  \Top \* \Top = \Top.
Proof using.
(* SOLUTION *)
  applys himpl_antisym.
  { applys himpl_htop_r. }
  { rewrite <- hstar_hempty_l at 1. applys himpl_frame_l.
    applys himpl_htop_r. }
(* /SOLUTION *)
Qed.



(* ******************************************************* *)
(** ** Variants for the garbage collection rule *)

(** Recall the lemma [triple_htop_post] from the previous chapter. *)

Parameter triple_htop_post : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.

(* EX2! (triple_hany_post) *)
(** The following lemma provides an alternative presentation of the
    same result as [triple_htop_post]. Prove that it is derivable
    from [triple_htop_post] and [triple_conseq]. *)

Lemma triple_hany_post : forall t H H' Q,
  triple t H (Q \*+ H') ->
  triple t H Q.
Proof using.
(* SOLUTION *)
  introv M. applys* triple_htop_post. applys triple_conseq M.
  { applys himpl_refl. }
  { intros v. applys himpl_frame_r. applys himpl_htop_r. }
(* /SOLUTION *)
Qed.

(** Reciprocally, [triple_htop_post] is trivially derivable from
    [triple_hany_post], simply by instantiating [H'] as [\Top]. *)

Lemma triple_htop_post_derived_from_triple_hany_post : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.
Proof using. intros. applys triple_hany_post \Top. auto. Qed.

(** The reason we prefer [triple_htop_post] to [triple_hany_post]
    is that it does not require providing [H'] at the time of applying
    the rule. The instantiation is postponed through the introduction
    of [\Top], which is equivalent to [\exists H', H']. Delaying the
    instantiation of [H'] using [\Top] rather than throught the
    introduction of an evar enables more robust proof scripts and
    tactic support. *)

(* EX2! (triple_htop_pre) *)
(** The rule [triple_htop_post] enables discarding pieces of
    heap from the postcondition. The symmetric rule [triple_htop_pre]
    enables discarding pieces of heap from the precondition.

    Prove that it is derivable from [triple_htop_post] and
    [triple_frame] (and, optionally, [triple_conseq]). *)

Lemma triple_htop_pre : forall t H Q,
  triple t H Q ->
  triple t (H \* \Top) Q.
Proof using.
(* SOLUTION *)
  introv M. applys triple_htop_post. applys triple_frame. auto.
(* /SOLUTION *)
Qed.

(* EX2! (triple_htop_pre) *)
(** The rule [triple_hany_pre] is a variant of [triple_htop_pre].
    Prove that it is derivable.
    You may exploit [triple_htop_pre], or [triple_hany_post],
    or [triple_htop_post], whichever you find simpler. *)

Lemma triple_hany_pre : forall t H H' Q,
  triple t H Q ->
  triple t (H \* H') Q.
Proof using.
(* SOLUTION *)
  dup 3.
  (* first proof, based on [triple_hany_post]: *)
  introv M. applys triple_hany_post. applys triple_frame. auto.
  (* second proof, based on [triple_htop_pre]: *)
  introv M. lets N: triple_htop_pre M. applys triple_conseq N.
  { applys himpl_frame_r. applys himpl_htop_r. }
  { applys qimpl_refl. }
  (* third proof, based on [triple_htop_post]: *)
  introv M. applys triple_htop_post.
  lets N: triple_frame H' M.
  applys triple_conseq N.
  { applys himpl_refl. }
  { intros v. applys himpl_frame_r. applys himpl_htop_r. }
(* /SOLUTION *)
Qed.

(** Here again, the reciprocal holds: [triple_hany_pre] is trivially
    derivable from [triple_htop_pre]. The variant of the rule that is
    most useful in practice is actually yet another presentation,
    which applies to any goal and enables specifying explicitly the
    piece of the precondition that one wishes to discard. *)

Lemma triple_hany_pre_trans : forall H1 H2 t H Q,
  triple t H1 Q ->
  H ==> H1 \* H2 ->
  triple t H Q.
Proof using.
  introv M WH. applys triple_conseq (H1 \* H2) Q.
  { applys triple_hany_pre. auto. }
  { applys WH. }
  { applys qimpl_refl. }
Qed.

(** Remark: the lemmas that enable discarding pieces of precondition
    (e.g., [triple_htop_pre]) are derivable from those that enable
    discarding pices of postconditions (e.g., [triple_htop_post]),
    but not the other way around.

    Advanced remark: the above remark can be mitigated. If we expose
    that [triple t H Q <-> triple t' H Q] holds whenever [t] and [t']
    are observationally equivalent with respect to the semantics
    defined by [eval], and if we are able to prove that [let x = t in x]
    is observationally equivalent to [t] for some fresh variable x,
    then it is possible to prove that [triple_htop_post] is derivable
    from [triple_htop_pre]. Indeed, the postcondition of [t] can be viewed 
    as the precondition of the [x] occuring in the right-hand side of the 
    term [let x = t in x]. Thus, discarding a heap predicate from the
    postcondition of [t] can be simulated by discarding a heap predicate
    from the precondition of [x]. *)




(* ******************************************************* *)
(** ** Strucutral rules *)


(** The garbage collection rules enable to discard any desired
    piece of heap from the precondition or the postcondition.
    Recall that the first rule is derivable from the second one.
    Moreover, it is equivalent to state these two rules by writing 
    [H'] instead of [\Top]. *)

Parameter triple_htop_pre : forall t H Q,
  triple t H Q ->
  triple t (H \* \Top) Q.

Parameter triple_htop_post : forall t H Q,
  triple t H (Q \*+ \Top) ->
  triple t H Q.





(** Recall from the previous chapter the combined structural
    rule [triple_conseq_frame_htop], which generalizes the rule
    [triple_conseq_frame] with the possibility to discard
    undesired heap predicate. This rule will be handy at
    some point in the exercise that follows. *)

Parameter triple_conseq_frame_htop : forall H2 H1 Q1 t H Q,
  triple t H1 Q1 ->
  H ==> H1 \* H2 ->
  Q1 \*+ H2 ===> Q \*+ \Top ->
  triple t H Q.




Lemma triple_seq : forall t1 t2 H Q H1,
  triple t1 H (fun v => H1) ->
  triple t2 H1 Q ->
  triple (trm_seq t1 t2) H Q.
Proof using.
  (* 1. We unfold the definition of [triple] to reveal a [hoare] judgment. *)
  introv M1 M2. intros H'. (* optional: *) unfolds triple.
  (* 2. We invoke the reasoning rule [hoare_seq] that we have just established. *)
  applys hoare_seq.
  { (* 3. For the hypothesis on the first subterm [t1],
       we can invoke directly our first hypothesis. *)
    applys M1. }
    ...
  { (* 4. For the hypothesis on the first subterm [t2],
       we need a little more work to exploit our second hypothesis.
       Indeed, the precondition features an extra [\Top].
       To handle it, we need to instantiate [M2] with [H' \* \Top],
       then merge the two [\Top] that appear into a single one.
       We could begin the proof script with:
         [specializes M2 (H' \* \Top). rewrite <- hstar_assoc in M2.]
       However, it is simpler to directly invoke the consequence rule,
       and let [xsimpl] do all the tedious work for us. *)
    applys hoare_conseq. { applys M2. } { xsimpl. } { xsimpl. } }
Qed.






(** [wp] is defined on top of [hoare] triples. More precisely [wp t Q]
    is a heap predicate such that [H ==> wp t Q] if and
    only if [SL_triple t H Q], where [SL_triple t H Q]
    is defined as [forall H', hoare t (H \* H') (Q \*+ H' \*+ \Top)]. *)

Definition wp (t:trm) := fun (Q:val->hprop) =>
  \exists H, H \* \[forall H', hoare t (H \* H') (Q \*+ H' \*+ \Top)].



Lemma wp_ramified : forall Q1 Q2 t,
  (wp t Q1) \* (Q1 \--* Q2 \*+ \Top) ==> (wp t Q2).
Proof using.
  intros. unfold wp. xpull ;=> H M.
  xsimpl (H \* (Q1 \--* Q2 \*+ \Top)). intros H'.
  applys hoare_conseq M; xsimpl.
Qed.


Lemma wp_hany_pre : forall t H Q,
  (wp t Q) \* H ==> wp t Q.
Proof using. intros. applys himpl_trans_r wp_ramified. xsimpl. Qed.

Lemma wp_hany_post : forall t H Q ,
  wp t (Q \*+ H) ==> wp t Q.
Proof using. intros. applys himpl_trans_r wp_ramified. xsimpl. Qed.


Definition triple (t:trm) (H:hprop) (Q:val->hprop) : Prop :=
  forall (H':hprop), hoare t (H \* H') (Q \*+ H' \*+ \Top).


Definition mkstruct (F:formula) : formula :=
  fun Q => \exists Q', F Q' \* (Q' \--* (Q \*+ \Top)).


Lemma mkstruct_ramified : forall Q1 Q2 F,
  (mkstruct F Q1) \* (Q1 \--* Q2 \*+ \Top) ==> (mkstruct F Q2).
Proof using. unfold mkstruct. xsimpl. Qed.




Lemma xcf_lemma_fun : forall v1 v2 x t H Q,
  v1 = val_fun x t ->
  H ==> wpgen ((x,v2)::nil) t (Q \*+ \Top) ->
  triple (trm_app v1 v2) H Q.
Proof using.
  introv M1 M2. rewrite wp_equiv.
  applys himpl_trans; [| applys (>> wp_hany_post \Top)].
  xchange M2.
  xchange (>> wpgen_sound ((x,v2)::nil) t (Q \*+ \Top)).
  rewrite <- subst_eq_isubst_one. applys* wp_app_fun.
Qed.

Lemma xcf_lemma_fix : forall v1 v2 f x t H Q,
  v1 = val_fix f x t ->
  H ==> wpgen ((f,v1)::(x,v2)::nil) t (Q \*+ \Top) ->
  triple (trm_app v1 v2) H Q.
Proof using.
  introv M1 M2. rewrite wp_equiv. xchange M2.
  applys himpl_trans; [| applys (>> wp_hany_post \Top)].
  xchange (>> wpgen_sound (((f,v1)::nil) ++ (x,v2)::nil) t (Q \*+ \Top)).
  rewrite isubst_app. do 2 rewrite <- subst_eq_isubst_one.
  applys* wp_app_fix.
Qed.



