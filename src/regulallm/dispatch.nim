## dispatch.nim -- Regula rule actions that invoke llama inference.
##
## When a rule fires with low confidence, dispatch to LLM for augmentation.

{.experimental: "strict_funcs".}

import std/tables
import basis/code/choice

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  DispatchRequest* = object
    rule_name*: string
    bindings*: Table[string, string]
    prompt*: string
    confidence*: float64

  InferenceFn* = proc(prompt: string): Choice[string] {.raises: [].}
    ## Function that runs LLM inference and returns generated text.

# =====================================================================================================================
# Dispatch
# =====================================================================================================================

proc create_dispatch*(rule_name: string, bindings: Table[string, string],
                      prompt: string, confidence: float64): DispatchRequest =
  DispatchRequest(rule_name: rule_name, bindings: bindings,
                  prompt: prompt, confidence: confidence)

proc execute_dispatch*(request: DispatchRequest, inference_fn: InferenceFn
                      ): Choice[string] =
  ## Send prompt to LLM and return response.
  inference_fn(request.prompt)
