## confidence.nim -- Confidence scoring on rule matches.
##
## Computes a confidence score for a rule match. Below threshold -> LLM fallback.

{.experimental: "strict_funcs".}

import std/tables

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  ConfidenceConfig* = object
    threshold*: float64       ## Below this -> dispatch to LLM
    default_score*: float64   ## Default confidence when no score available

  MatchScore* = object
    rule_name*: string
    score*: float64
    below_threshold*: bool

# =====================================================================================================================
# Configuration
# =====================================================================================================================

proc default_confidence_config*(): ConfidenceConfig =
  ConfidenceConfig(threshold: 0.7, default_score: 1.0)

# =====================================================================================================================
# Scoring
# =====================================================================================================================

proc score_match*(rule_name: string, bound_count: int, total_conditions: int,
                  config: ConfidenceConfig = default_confidence_config()
                 ): MatchScore =
  ## Score a rule match based on how many conditions were bound vs total.
  ## Full match = 1.0; partial match = fraction.
  let score = if total_conditions > 0: float64(bound_count) / float64(total_conditions)
              else: config.default_score
  MatchScore(rule_name: rule_name, score: score,
             below_threshold: score < config.threshold)

proc score_by_specificity*(rule_name: string, bindings: Table[string, string],
                           config: ConfidenceConfig = default_confidence_config()
                          ): MatchScore =
  ## Score based on how many variables are bound (more bindings = higher confidence).
  let score = if bindings.len > 0: min(1.0, float64(bindings.len) / 5.0)
              else: 0.0
  MatchScore(rule_name: rule_name, score: score,
             below_threshold: score < config.threshold)

proc should_dispatch*(score: MatchScore): bool =
  ## Whether this match should be dispatched to LLM.
  score.below_threshold
