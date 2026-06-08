defmodule Funx.Credo.Check.Readability.RedundantEitherValidationWrapper do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :readability

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({:|>, meta, [expr, {:case, _, [[do: clauses]]}]} = ast, issues, issue_meta) do
    if validate_wrapper_case?(expr, clauses) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse({:case, meta, [expr, [do: clauses]]} = ast, issues, issue_meta) do
    if validate_wrapper_case?(expr, clauses) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp validate_wrapper_case?(expr, clauses) do
    validate_named_operation?(expr) and wrapper_clauses?(clauses)
  end

  defp validate_named_operation?({name, _, args}) when is_atom(name) and is_list(args) do
    name
    |> Atom.to_string()
    |> String.starts_with?("validate")
  end

  defp validate_named_operation?({{:., _, [_module_ast, name]}, _, args})
       when is_atom(name) and is_list(args) do
    name
    |> Atom.to_string()
    |> String.starts_with?("validate")
  end

  defp validate_named_operation?(_), do: false

  defp wrapper_clauses?(clauses) when is_list(clauses) do
    has_ok_clause? = Enum.any?(clauses, &ok_right_clause?/1)
    has_error_clause? = Enum.any?(clauses, &error_left_clause?/1)
    has_ok_clause? and has_error_clause?
  end

  defp ok_right_clause?({:->, _, [[pattern], body]}) do
    pattern == :ok and either_remote_call?(body, :right, 1)
  end

  defp ok_right_clause?(_), do: false

  defp error_left_clause?({:->, _, [[pattern], body]}) do
    case pattern do
      keyword when is_list(keyword) ->
        if Keyword.keyword?(keyword) do
          case keyword do
            [error: reason_var] ->
              either_left_uses_reason?(body, reason_var)

            _ ->
              false
          end
        else
          false
        end

      {:error, reason_var} ->
        either_left_uses_reason?(body, reason_var)

      {:{}, _, [:error, reason_var]} ->
        either_left_uses_reason?(body, reason_var)

      _ ->
        false
    end
  end

  defp error_left_clause?(_), do: false

  defp either_left_uses_reason?(body, reason_var) do
    either_remote_call?(body, :left, 1) and ast_uses_var?(body, reason_var)
  end

  defp either_remote_call?({{:., _, [_module_ast, function_name]}, _, args}, function_name, arity)
       when is_list(args) do
    length(args) == arity
  end

  defp either_remote_call?(_, _, _), do: false

  defp ast_uses_var?(ast, target_var) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        node, false ->
          {node, same_variable?(node, target_var)}

        node, true ->
          {node, true}
      end)

    found?
  end

  defp same_variable?({name, _, context}, {name, _, context})
       when is_atom(name) and is_atom(context),
       do: true

  defp same_variable?(_, _), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Validation result is manually wrapped into Either.right/left. Prefer `validate [...]` or return the validation result directly to an Either adapter.",
      line_no: line_no
    )
  end
end
