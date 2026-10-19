# Funx Predicate Usage

Guidance for future LLM sessions working in this repository.

## Predicate DSL

Use `Funx.Predicate` for named boolean policy checks where the code is naturally “all of these conditions must hold” or “any of these conditions may hold”.

Good fit:

- Private policy predicates such as `should_retry...?`, `should_stop...?`, `requires_more...?`, and `..._window?`.
- Conditions over a known domain struct.
- Business rules that compose field checks with `IsTrue`, `IsFalse`, `Eq`, `NotEq`, `GreaterThanOrEqual`, `LessThan`, and similar predicate modules.

Poor fit:

- Decision trees that return atoms or structs.
- One-off control-flow branches where `cond`, `case`, or direct field access is clearer.
- Loose external payloads or decoded JSON maps unless missing fields are a normal predicate failure.

## Lens Vs Prism

Choose the projection based on whether field access itself is invariant.

Use a `Lens` when:

- The input is a known struct or schema-enforced shape.
- The field/path should always exist.
- Missing data is a programming error, not normal business logic.

Use a `Prism` or bare atom/list projection when:

- The input is a loose map, external payload, optional data, or branchy shape.
- Absence is normal and should make the predicate fail gracefully.

Remember: the predicate may return `false`; the question is whether the projection is allowed to fail.

## Struct Policy Inputs

If a policy helper relies on a struct invariant, pattern match the struct in the function head:

```elixir
defp best_answer_after_improvement_window?(%AnswerInput{} = input) do
  ...
end
```

This makes the invariant explicit and supports using lens projections safely.

## Lens Helper Naming

When exposing optics from an input module, name them as lenses:

```elixir
def pages_read_count_lens,
  do: Lens.key(:pages_read_count)
```

Avoid `?` suffixes for lens-returning functions. In Elixir, `?` should indicate a boolean-returning predicate, not an optic.

## Predicate DSL With Lens Helpers

Prefer lens helper functions in the input module and pass them to `check`.

Use remote-call syntax with parentheses:

```elixir
predicate =
  pred do
    check AnswerInput.single_document_mode_lens(), IsFalse
    check AnswerInput.factoid_question_lens(), IsFalse
    check AnswerInput.best_answer_present_lens(), IsTrue
    check AnswerInput.question_breadth_lens(), {NotEq, value: :narrow}
    check AnswerInput.pages_read_count_lens(), {GreaterThanOrEqual, value: 3}
  end

predicate.(input)
```

This keeps the policy readable while encoding total field access in the input module.

### Local Lens Helpers

Funx's Predicate DSL does not treat local zero-arity helper calls as projections. Inside the module that defines a lens helper, call it through `__MODULE__`:

```elixir
def final?(%__MODULE__{} = input) do
  predicate =
    pred do
      any do
        check __MODULE__.answer_final_lens(), IsTrue
        check __MODULE__.answer_complete_lens(), IsTrue
      end
    end

  predicate.(input)
end
```

Do not write this inside `pred do`:

```elixir
check answer_final_lens(), IsTrue
```

The Funx parser sees that as an invalid local call projection. Remote calls such as `AnswerInput.answer_final_lens()` and `__MODULE__.answer_final_lens()` are accepted.

## Struct Boundaries

When a loose map has become an implicit domain object, normalize it into a struct at the boundary and move result-only predicates to that struct.

Example: answer results are normalized into `%AnswerResult{}`. The result struct owns predicates that depend only on the answer result:

- `concise_factoid?/1`
- `descriptive_lookup?/1`
- `grounded_text?/1`
- `retryable_same_pages?/1`
- `not_found_text?/1`
- answer-text classifiers such as `yes_no?/1` and `comparative?/1`

The engine/policy module should keep predicates that combine the result with state, retrieval progress, task kind, or transition policy.

## Applying This To `answer.ex`

Good candidates for Predicate DSL conversion:

- `document_answer_requires_more_reading?/1`
- `should_simplify_matter_search?/1`
- `should_retry_single_document_answer?/1`
- `should_stop_factoid_drift?/1`
- `answer_final?/1`
- `best_answer_after_improvement_window?/1`

Use more caution with functions like `single_document_next_step/1` and `matter_next_step/1`. They are transition/decision functions returning atoms, so keep their `cond` structure unless extracting named predicate helpers makes the intent clearer.

Do not force this pattern onto functions like `retry_critique/1`, which accepts arbitrary maps. Loose maps should usually keep `Map.get`, pattern matching, or Prism-style optional access.
