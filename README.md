# Funx Credo

Credo checks for teams adopting Funx. These checks are meant to guide selective
use of Funx DSLs, not to replace idiomatic Elixir control flow everywhere.

## Installation

Add `funx_credo` to your development and test dependencies:

```elixir
def deps do
  [
    {:funx_credo, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

Then enable the checks in `.credo.exs`:

```elixir
%{
  configs: [
    %{
      name: "default",
      checks: %{
        enabled: [
          # High priority - clear anti-patterns
          {Funx.Credo.Check.Readability.EitherLeftFalse, []},
          {Funx.Credo.Check.Readability.ConsecutiveEitherValidations, []},
          {Funx.Credo.Check.Readability.EitherWrappedResultTuple, []},

          # Normal priority - best practices
          {Funx.Credo.Check.Readability.BindValidateNaming, []},
          {Funx.Credo.Check.Readability.RedundantEitherValidationWrapper, []},
          {Funx.Credo.Check.Readability.PreferLiftPredicateValidator, []},

          # Low priority - style suggestions (configurable)
          {Funx.Credo.Check.Readability.PreferEitherDSL, [min_clauses: 2]},
          {Funx.Credo.Check.Readability.PreferPredicateDSL, [min_terms: 4]},
          {Funx.Credo.Check.Readability.PreferEitherPartialApplication, []}
        ]
      }
    }
  ]
}
```

## Checks

### High Priority (Clear Anti-Patterns)

**`EitherLeftFalse`** - Flags `Either.left(false)` which is ambiguous as an error value.

**`ConsecutiveEitherValidations`** - Detects multiple consecutive `validate` steps that should be combined into a single `validate [...]` list.

**`EitherWrappedResultTuple`** - Detects double-wrapping like `Either.right({:ok, value})` or `Either.left({:error, reason})`.

### Normal Priority (Best Practices)

**`BindValidateNaming`** - Ensures semantic consistency between `bind` operations and function naming (functions named `validate_*` should use `validate`, not `bind`).

**`RedundantEitherValidationWrapper`** - Detects manual wrapping of validation results into `Either.right/left`.

**`PreferLiftPredicateValidator`** - Suggests using `LiftPredicate` validator directly instead of wrapping `Either.lift_predicate/3`.

### Low Priority (Style Suggestions)

**`PreferEitherDSL`** - Suggests using Either DSL for simple linear `{:ok, value}` / `{:error, reason}` pipelines.

Configuration:
- `min_clauses` - Minimum `with` clauses to trigger (default: 2)

Avoids flagging when:
- Success logic needs multiple independently bound values
- Earlier bound values are reused downstream
- Nested case appears in error branch
- Pattern matching involves non-Either shapes

**`PreferPredicateDSL`** - Suggests using Predicate DSL for complex boolean condition chains in predicate functions.

Configuration:
- `min_terms` - Minimum boolean terms to trigger (default: 4)

Avoids flagging when:
- Small boolean chains
- Loose external maps with string-key access
- String classifier predicates
- Collection inspection logic
- IO-heavy calls

**`PreferEitherPartialApplication`** - Suggests using partial application instead of inline lambdas that only thread the value as the first argument.

## Documentation

Each check includes comprehensive inline documentation with examples. Use `mix credo explain Funx.Credo.Check.Readability.EitherLeftFalse` to see detailed explanations and examples for a check.
