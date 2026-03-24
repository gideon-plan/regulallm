## dispatch.nim -- Regula rule actions that invoke llama inference.
##
## When a rule fires with low confidence, dispatch to LLM for augmentation.

{.experimental: "strict_funcs".}

import std/tables
import lattice

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  DispatchRequest* = object
    rule_name*: string
    bindings*: Table[string, string]
    prompt*: string
    confidence*: float64

  InferenceFn* = proc(prompt: string): Result[string, BridgeError] {.raises: [].}
    ## Function that runs LLM inference and returns generated text.

# =====================================================================================================================
# Dispatch
# =====================================================================================================================

proc create_dispatch*(rule_name: string, bindings: Table[string, string],
                      prompt: string, confidence: float64): DispatchRequest =
  DispatchRequest(rule_name: rule_name, bindings: bindings,
                  prompt: prompt, confidence: confidence)

proc execute_dispatch*(request: DispatchRequest, inference_fn: InferenceFn
                      ): Result[string, BridgeError] =
  ## Send prompt to LLM and return response.
  inference_fn(request.prompt)
