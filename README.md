# rag-backend-cross-encoder

Pairwise **`rerank`** for [`rag-protocol`](https://github.com/egao1980/rag-protocol). Same GF as the in-tree identity reranker — not a new protocol.

Neural cross-encoder is `:score-fn` `(query-text doc-text) → real` or `:batch-fn` `(query-text texts) → scores`. We do not ship BERT weights. Default is unique-token overlap (`pair-overlap-score`) — **not** a CE model.

```lisp
(asdf:load-system "rag-backend-cross-encoder")

(let ((r (rag-backend-cross-encoder:make-cross-encoder-reranker
          :score-fn (lambda (q d) (your-cross-encoder q d)))))
  (stack-rag:rerank r "apple"
                    (list (stack-rag:make-rag-hit
                           :chunk (stack-rag:make-rag-chunk :id "a" :text "red apple")
                           :score 0.1))
                    :top-k 5))
```

Bind on a pipeline (`:reranker`) or `*rag-reranker*`. Vector-only query (no text) falls back to identity (score desc).

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
