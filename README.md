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
  checks: [
    {Funx.Credo.Check.Readability.PreferEitherDSL, []},
    {Funx.Credo.Check.Readability.PreferPredicateDSL, []}
  ]
}
```

## Checks

### `Funx.Credo.Check.Readability.PreferEitherDSL`

Flags simple multi-clause `with` and nested `case` flows that look like linear
`{:ok, value}` / `{:error, reason}` pipelines.

It avoids cases where native Elixir is usually clearer:

- success logic needs multiple independently bound values
- earlier bound values are reused downstream
- nested `case` is fallback logic in an error branch
- the outer case is not Either-shaped

### `Funx.Credo.Check.Readability.PreferPredicateDSL`

Flags larger predicate functions that look like domain policy checks over known
structs and may read better as `pred do ... end`.

It avoids cases where Predicate DSL is usually a poor fit:

- small boolean chains
- loose external maps with string-key access
- string classifier predicates
- collection inspection
- IO-like calls
