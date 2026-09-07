(in-package #:rag-backend-cross-encoder/tests)

(defun %hit (id text score)
  (rag-protocol:make-rag-hit
   :chunk (rag-protocol:make-rag-chunk :id id :text text)
   :score score))

(deftest overlap-reranks
  (let* ((r (rag-backend-cross-encoder:make-cross-encoder-reranker))
         (hits (list (%hit "b" "blue car" 0.9)
                     (%hit "a" "red apple" 0.1)))
         (out (rag-protocol:rerank r "apple" hits :top-k 2)))
    (ok (equal "a" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))
    (ok (> (rag-protocol:rag-hit-score (first out))
           (rag-protocol:rag-hit-score (second out))))))

(deftest score-fn-hook
  (let* ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
             :score-fn (lambda (q d)
                         (declare (ignore q))
                         (if (search "keep" d) 1.0 0.0))))
         (out (rag-protocol:rerank
               r "query"
               (list (%hit "a" "drop this" 1.0)
                     (%hit "b" "keep this" 0.0))
               :top-k 1)))
    (ok (equal "b" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))))

(deftest batch-fn-hook
  (let* ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
             :batch-fn (lambda (q texts)
                         (declare (ignore q))
                         (mapcar (lambda (d)
                                   (if (search "win" d) 2.0 0.1))
                                 texts))))
         (out (rag-protocol:rerank
               r "q"
               (list (%hit "a" "lose" 1.0)
                     (%hit "b" "win" 0.0))
               :top-k 2)))
    (ok (equal "b" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))))

(deftest batch-fn-length-mismatch
  (let ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
            :batch-fn (lambda (q texts)
                        (declare (ignore q texts))
                        '()))))
    (ok (signals (rag-protocol:rerank r "q" (list (%hit "a" "x" 0.0))
                                     :top-k 1)
                 'rag-protocol:rag-error))))

(deftest vector-only-keeps-identity
  (let* ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
             :score-fn (lambda (q d)
                         (declare (ignore q d))
                         99.0)))
         (out (rag-protocol:rerank r #(1.0 0.0)
                                  (list (%hit "a" "x" 0.2)
                                        (%hit "b" "y" 0.9))
                                  :top-k 1)))
    (ok (equal "b" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))))

(deftest overlap-with-analyzer
  (let* ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
             :analyzer (rag-protocol:make-simple-analyzer
                        :stemmer :porter :stopwords :english)))
         (out (rag-protocol:rerank r "the running cats"
                                  (list (%hit "a" "run cat" 0.0)
                                        (%hit "b" "blue car" 1.0))
                                  :top-k 1)))
    (ok (equal "a" (rag-protocol:rag-chunk-id
                    (rag-protocol:rag-hit-chunk (first out)))))))

(deftest use-binds
  (let ((rag-protocol:*rag-reranker* nil))
    (rag-backend-cross-encoder:use-cross-encoder-reranker)
    (ok (typep rag-protocol:*rag-reranker*
               'rag-backend-cross-encoder:cross-encoder-reranker))
    (setf rag-protocol:*rag-reranker* nil)))
