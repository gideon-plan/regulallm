## validate.nim -- Parse LLM output and assert as regula facts.

{.experimental: "strict_funcs".}

import std/[strutils, tables]
import basis/code/choice

# =====================================================================================================================
# Types
# =====================================================================================================================

type
  ParsedFact* = object
    fact_type*: string
    fields*: Table[string, string]

  ValidateFn* = proc(facts: seq[ParsedFact]): Choice[seq[ParsedFact]] {.raises: [].}
    ## Function that validates parsed facts against guard rules.

# =====================================================================================================================
# Parsing
# =====================================================================================================================

proc parse_kv_response*(response: string, fact_type: string): Choice[seq[ParsedFact]] =
  ## Parse LLM response as key=value lines into facts.
  ## Expected format: one key=value pair per line.
  var facts: seq[ParsedFact]
  var current_fields: Table[string, string]
  for line in response.splitLines():
    let trimmed = line.strip()
    if trimmed.len == 0:
      if current_fields.len > 0:
        facts.add(ParsedFact(fact_type: fact_type, fields: current_fields))
        current_fields = initTable[string, string]()
      continue
    let eq_pos = trimmed.find('=')
    if eq_pos > 0:
      let key = trimmed[0 ..< eq_pos].strip()
      let val = trimmed[eq_pos + 1 ..< trimmed.len].strip()
      current_fields[key] = val
  if current_fields.len > 0:
    facts.add(ParsedFact(fact_type: fact_type, fields: current_fields))
  good(facts)

proc parse_csv_response*(response: string, fact_type: string,
                         headers: seq[string]): Choice[seq[ParsedFact]] =
  ## Parse LLM response as CSV lines into facts.
  var facts: seq[ParsedFact]
  for line in response.splitLines():
    let trimmed = line.strip()
    if trimmed.len == 0: continue
    let values = trimmed.split(",")
    if values.len != headers.len: continue
    var fields: Table[string, string]
    for i, h in headers:
      fields[h] = values[i].strip()
    facts.add(ParsedFact(fact_type: fact_type, fields: fields))
  good(facts)
