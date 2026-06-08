defmodule Funx.Credo.Check.Readability.PreferLiftPredicateValidator do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :refactor,
    explanations: [
      check: """
      Validation helper functions that simply wrap `Either.lift_predicate/3` should
      usually be expressed using the `LiftPredicate` validator directly in the
      `validate [...]` step.

      This keeps validation logic inline and reduces unnecessary function indirection.

      ## Examples

      Bad:

          defp validate_positive(n) do
            Either.lift_predicate(n, &(&1 > 0), :not_positive)
          end

          either id do
            bind fetch_value()
            bind validate_positive()
          end

      Good:

          either id do
            bind fetch_value()
            validate LiftPredicate.validate(
              pred: &(&1 > 0),
              message: fn _ -> :not_positive end
            )
          end

      ## Rationale

      The LiftPredicate validator is designed to be used inline in validation
      steps. Creating wrapper functions adds indirection without clear benefit,
      unless the predicate logic is complex enough to warrant extraction.

      """,
      params: []
    ]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({definition, meta, [{name, _, args}, body]} = ast, issues, issue_meta)
       when definition in [:def, :defp] and is_atom(name) and is_list(args) do
    if validation_helper_name?(name) and direct_lift_predicate_call?(body) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp validation_helper_name?(name) do
    name
    |> Atom.to_string()
    |> String.starts_with?("validate_")
  end

  defp direct_lift_predicate_call?(body) do
    case unwrap_body(body) do
      {{:., _, [either_module, :lift_predicate]}, _, [_value, _predicate, _on_false]} ->
        either_alias?(either_module)

      _ ->
        false
    end
  end

  defp unwrap_body(do: expression), do: expression
  defp unwrap_body(expression), do: expression

  defp either_alias?({:__aliases__, _, [:Either]}), do: true
  defp either_alias?({:__aliases__, _, [:Funx, :Monad, :Either]}), do: true
  defp either_alias?(_), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Validation helpers built directly on `Either.lift_predicate/3` should usually use `LiftPredicate` in the surrounding `validate [...]` step instead.",
      line_no: line_no
    )
  end
end
