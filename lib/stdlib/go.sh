make -C ../../generator \
&& make -C ../coq -j3 \
&& make
coqide -async-proofs off -async-proofs-command-error-resilience off  Array_ml.v &
