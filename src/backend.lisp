(in-package #:rag-backend-cross-encoder)

;;; Pairwise rerank. Neural cross-encoder is :score-fn or :batch-fn.
;;; Default = token overlap — not a CE model. We do not ship weights.

(defun pair-overlap-score (query-text doc-text &key analyzer)
  "Unique-token overlap |q ∩ d| / |q|. Empty query → 0.0."
  (let* ((a (or analyzer (rag-protocol:make-simple-analyzer)))
         (qt (rag-protocol:analyze a query-text))
         (seen (make-hash-table :test 'equal))
         (qset (make-hash-table :test 'equal)))
    (dolist (tok qt)
      (setf (gethash tok qset) t))
    (if (zerop (hash-table-count qset))
        0f0
        (let ((inter 0))
          (dolist (tok (rag-protocol:analyze a doc-text))
            (when (and (gethash tok qset) (not (gethash tok seen)))
              (setf (gethash tok seen) t)
              (incf inter)))
          (float (/ inter (hash-table-count qset)) 1f0)))))

(defclass cross-encoder-reranker (rag-protocol:rag-reranker)
  ((score-fn :initarg :score-fn :accessor cross-encoder-score-fn :initform nil)
   (batch-fn :initarg :batch-fn :accessor cross-encoder-batch-fn :initform nil)
   (analyzer :initarg :analyzer :accessor cross-encoder-analyzer :initform nil)))

(defun make-cross-encoder-reranker (&key score-fn batch-fn analyzer)
  (make-instance 'cross-encoder-reranker
                 :score-fn score-fn
                 :batch-fn batch-fn
                 :analyzer analyzer))

(defun use-cross-encoder-reranker (&rest args &key &allow-other-keys)
  (setf rag-protocol:*rag-reranker* (apply #'make-cross-encoder-reranker args)))

(defun %hit-text (hit)
  (rag-protocol:rag-chunk-text (rag-protocol:rag-hit-chunk hit)))

(defun %score-one (reranker query-text doc-text)
  (let ((fn (cross-encoder-score-fn reranker)))
    (if fn
        (float (funcall fn query-text doc-text) 1f0)
        (pair-overlap-score query-text doc-text
                            :analyzer (cross-encoder-analyzer reranker)))))

(defun %apply-scores (hits scores)
  (unless (= (length scores) (length hits))
    (error 'rag-protocol:rag-error
           :message (format nil "batch-fn returned ~d scores for ~d hits"
                            (length scores) (length hits))))
  (mapc (lambda (hit score)
          (setf (rag-protocol:rag-hit-score hit) (float score 1f0)))
        hits scores)
  hits)

(defmethod rag-protocol:rerank ((reranker cross-encoder-reranker) query hits
                                &key top-k)
  (let ((text (rag-protocol:query-text query)))
    (cond
      ((or (null hits)
           (null text)
           (zerop (length text)))
       (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                            query hits :top-k top-k))
      ((cross-encoder-batch-fn reranker)
       (let ((scores (funcall (cross-encoder-batch-fn reranker)
                              text
                              (mapcar #'%hit-text hits))))
         (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                              query (%apply-scores hits scores) :top-k top-k)))
      (t
       (dolist (hit hits)
         (setf (rag-protocol:rag-hit-score hit)
               (%score-one reranker text (%hit-text hit))))
       (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                            query hits :top-k top-k)))))
