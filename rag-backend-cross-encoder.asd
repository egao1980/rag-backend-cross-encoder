(defsystem "rag-backend-cross-encoder"
  :version "0.1.0"
  :description "Cross-encoder reranker for rag-protocol (score-fn / batch-fn)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rag-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "rag-backend-cross-encoder/tests"))))

(defsystem "rag-backend-cross-encoder/tests"
  :depends-on ("rag-backend-cross-encoder" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
