## tregulallm.nim -- Tests for regulallm bridge.

{.experimental: "strict_funcs".}

import std/[unittest, strutils, tables]
import regulallm

# =====================================================================================================================
# Dispatch tests
# =====================================================================================================================

suite "dispatch":
  test "create dispatch request":
    var bindings: Table[string, string]
    bindings["input"] = "ambiguous data"
    let req = create_dispatch("classify_rule", bindings, "Classify: ambiguous data", 0.3)
    check req.rule_name == "classify_rule"
    check req.confidence == 0.3

  test "execute dispatch with mock":
    var bindings: Table[string, string]
    let req = create_dispatch("test", bindings, "What is this?", 0.5)
    let mock_inf: InferenceFn = proc(p: string): Result[string, BridgeError] {.raises: [].} =
      Result[string, BridgeError].good("category=animal")
    let result = execute_dispatch(req, mock_inf)
    check result.is_good
    check result.val == "category=animal"

# =====================================================================================================================
# Validate tests
# =====================================================================================================================

suite "validate":
  test "parse kv response":
    let response = "name=cat\ntype=animal"
    let result = parse_kv_response(response, "classification")
    check result.is_good
    check result.val.len == 1
    check result.val[0].fields["name"] == "cat"
    check result.val[0].fields["type"] == "animal"

  test "parse kv multiple facts":
    let response = "a=1\nb=2\n\nc=3\nd=4"
    let result = parse_kv_response(response, "data")
    check result.is_good
    check result.val.len == 2

  test "parse csv response":
    let response = "alice,30,engineer\nbob,25,designer"
    let result = parse_csv_response(response, "person", @["name", "age", "role"])
    check result.is_good
    check result.val.len == 2
    check result.val[0].fields["name"] == "alice"
    check result.val[1].fields["role"] == "designer"

# =====================================================================================================================
# Confidence tests
# =====================================================================================================================

suite "confidence":
  test "full match has high confidence":
    let score = score_match("rule1", 5, 5)
    check score.score == 1.0
    check not score.below_threshold

  test "partial match below threshold":
    let config = ConfidenceConfig(threshold: 0.7, default_score: 1.0)
    let score = score_match("rule1", 1, 5, config)
    check score.score == 0.2
    check score.below_threshold

  test "should_dispatch returns true for low confidence":
    let score = MatchScore(rule_name: "r", score: 0.3, below_threshold: true)
    check should_dispatch(score)

# =====================================================================================================================
# Guard tests
# =====================================================================================================================

suite "guard":
  test "required fields guard passes":
    let facts = @[ParsedFact(fact_type: "t", fields: {"name": "a", "type": "b"}.toTable)]
    let result = check_required_fields(facts, @["name", "type"])
    check result.passed

  test "required fields guard fails":
    let facts = @[ParsedFact(fact_type: "t", fields: {"name": "a"}.toTable)]
    let result = check_required_fields(facts, @["name", "type"])
    check not result.passed

  test "allowed values guard passes":
    let facts = @[ParsedFact(fact_type: "t", fields: {"color": "red"}.toTable)]
    let result = check_allowed_values(facts, "color", @["red", "blue"])
    check result.passed

  test "allowed values guard fails":
    let facts = @[ParsedFact(fact_type: "t", fields: {"color": "green"}.toTable)]
    let result = check_allowed_values(facts, "color", @["red", "blue"])
    check not result.passed

  test "max length guard":
    check check_max_length("short", 100).passed
    check not check_max_length("x".repeat(200), 100).passed

  test "evaluate_guards all pass":
    let guards = @[
      Guard(kind: gkMaxLength, max_chars: 1000)]
    let result = evaluate_guards(guards, "short response", @[])
    check result.is_good

# =====================================================================================================================
# Session tests
# =====================================================================================================================

suite "session":
  test "dispatch and validate end-to-end":
    let mock_inf: InferenceFn = proc(p: string): Result[string, BridgeError] {.raises: [].} =
      Result[string, BridgeError].good("category=animal\nconfidence=0.95")
    var asserted: seq[ParsedFact]
    let mock_assert: AssertFactFn = proc(f: ParsedFact): Result[void, BridgeError] {.raises: [].} =
      asserted.add(f)
      Result[void, BridgeError](ok: true)
    var session = new_llm_session(mock_inf, mock_assert)
    var bindings: Table[string, string]
    let req = create_dispatch("classify", bindings, "Classify this", 0.4)
    let result = session.dispatch_and_validate(req, "classification")
    check result.is_good
    check result.val.len == 1
    check asserted.len == 1
    let (dispatches, asserts, fails) = session.stats()
    check dispatches == 1
    check asserts == 1
    check fails == 0
