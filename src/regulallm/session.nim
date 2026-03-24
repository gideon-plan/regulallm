## session.nim -- Combined session managing regula + llama lifecycle.

{.experimental: "strict_funcs".}

import lattice, dispatch, validate, confidence, guard

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  AssertFactFn* = proc(fact: ParsedFact): Result[void, BridgeError] {.raises: [].}
    ## Function that inserts a parsed fact into the regula session.

  LlmSession* = object
    inference_fn*: InferenceFn
    assert_fn*: AssertFactFn
    guards*: seq[Guard]
    confidence_config*: ConfidenceConfig
    dispatch_count*: int
    assert_count*: int
    guard_failures*: int
    max_retries*: int

# =====================================================================================================================
# Session management
# =====================================================================================================================

proc new_llm_session*(inference_fn: InferenceFn, assert_fn: AssertFactFn,
                      guards: seq[Guard] = @[],
                      confidence_config: ConfidenceConfig = default_confidence_config(),
                      max_retries: int = 2): LlmSession =
  LlmSession(inference_fn: inference_fn, assert_fn: assert_fn,
             guards: guards, confidence_config: confidence_config,
             max_retries: max_retries)

proc dispatch_and_validate*(session: var LlmSession, request: DispatchRequest,
                            fact_type: string): Result[seq[ParsedFact], BridgeError] =
  ## Dispatch to LLM, parse response, validate with guards, assert facts.
  ## Retries on guard failure up to max_retries.
  var retries = 0
  while retries <= session.max_retries:
    let response = execute_dispatch(request, session.inference_fn)
    if response.is_bad:
      return Result[seq[ParsedFact], BridgeError].bad(response.err)
    inc session.dispatch_count
    let parsed = parse_kv_response(response.val, fact_type)
    if parsed.is_bad:
      return Result[seq[ParsedFact], BridgeError].bad(parsed.err)
    if session.guards.len > 0:
      let guard_result = evaluate_guards(session.guards, response.val, parsed.val)
      if guard_result.is_bad:
        inc session.guard_failures
        inc retries
        continue
    # Assert facts
    for fact in parsed.val:
      let r = session.assert_fn(fact)
      if r.is_bad:
        return Result[seq[ParsedFact], BridgeError].bad(r.err)
      inc session.assert_count
    return Result[seq[ParsedFact], BridgeError].good(parsed.val)
  Result[seq[ParsedFact], BridgeError].bad(
    BridgeError(msg: "Guard validation failed after " & $session.max_retries & " retries"))

proc stats*(session: LlmSession): tuple[dispatches: int, asserts: int, guard_fails: int] =
  (dispatches: session.dispatch_count, asserts: session.assert_count,
   guard_fails: session.guard_failures)
