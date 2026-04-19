## guard.nim -- Output guard rules that reject/retry LLM responses.
##
## Validates LLM output against structural and content constraints.

{.experimental: "strict_funcs".}

import std/tables
import basis/code/choice, validate

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  GuardKind* {.pure.} = enum
    RequiredFields   ## All specified fields must be present
    AllowedValues    ## Field values must be in allowed set
    MaxLength        ## Response must not exceed length

  Guard* = object
    case kind*: GuardKind
    of GuardKind.RequiredFields:
      required*: seq[string]
    of GuardKind.AllowedValues:
      field*: string
      allowed*: seq[string]
    of GuardKind.MaxLength:
      max_chars*: int

  GuardResult* = object
    passed*: bool
    reason*: string

# =====================================================================================================================
# Guard evaluation
# =====================================================================================================================

proc check_required_fields*(facts: seq[ParsedFact], required: seq[string]): GuardResult =
  for fact in facts:
    for r in required:
      if r notin fact.fields:
        return GuardResult(passed: false, reason: "Missing field: " & r & " in fact type " & fact.fact_type)
  GuardResult(passed: true, reason: "")

proc check_allowed_values*(facts: seq[ParsedFact], field: string, allowed: seq[string]): GuardResult =
  for fact in facts:
    if field in fact.fields:
      if fact.fields[field] notin allowed:
        return GuardResult(passed: false,
                           reason: "Invalid value for " & field & ": " & fact.fields[field])
  GuardResult(passed: true, reason: "")

proc check_max_length*(response: string, max_chars: int): GuardResult =
  if response.len > max_chars:
    GuardResult(passed: false, reason: "Response too long: " & $response.len & " > " & $max_chars)
  else:
    GuardResult(passed: true, reason: "")

proc evaluate_guard*(guard: Guard, response: string, facts: seq[ParsedFact]): GuardResult =
  case guard.kind
  of GuardKind.RequiredFields:
    check_required_fields(facts, guard.required)
  of GuardKind.AllowedValues:
    check_allowed_values(facts, guard.field, guard.allowed)
  of GuardKind.MaxLength:
    check_max_length(response, guard.max_chars)

proc evaluate_guards*(guards: seq[Guard], response: string,
                      facts: seq[ParsedFact]): Choice[bool] =
  ## Evaluate all guards. Returns bad on first failure.
  for g in guards:
    let r = evaluate_guard(g, response, facts)
    if not r.passed:
      return bad[bool]("regulallm", r.reason)
  good(true)
