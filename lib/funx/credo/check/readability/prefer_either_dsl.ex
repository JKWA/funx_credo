defmodule Funx.Credo.Check.Readability.PreferEitherDSL do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :readability

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({:with, meta, args} = ast, issues, issue_meta) do
    clauses = Enum.filter(args, &match?({:<-, _, _}, &1))

    if length(clauses) >= 2 and either_with_candidate?(clauses) and
         not ignore_multi_value_with?(clauses, args) do
      {ast, [issue_for_with(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse({:case, _meta, [_expr, [do: clauses]]} = ast, issues, issue_meta) do
    new_issues =
      if either_case_candidate?(clauses) do
        Enum.reduce(clauses, issues, fn
          {:->, _, [_match, {:case, inner_meta, [_inner_expr, [do: inner_clauses]]}]} = clause,
          acc ->
            if not error_clause?(clause) and either_case_candidate?(inner_clauses) do
              [issue_for_nested_case(issue_meta, inner_meta[:line]) | acc]
            else
              acc
            end

          {:->, _, [_match, _result]}, acc ->
            acc
        end)
      else
        issues
      end

    {ast, new_issues}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp ignore_multi_value_with?(clauses, args) do
    used_vars = do_block_used_vars(args)

    multiple_clause_values_used_in_success_body?(clauses, used_vars) or
      bound_value_reused_downstream?(clauses, used_vars)
  end

  defp multiple_clause_values_used_in_success_body?(clauses, used_vars) do
    clauses
    |> Enum.map(&bound_vars_from_clause/1)
    |> Enum.count(&(not MapSet.disjoint?(&1, used_vars)))
    |> Kernel.>=(2)
  end

  defp bound_value_reused_downstream?(clauses, do_block_vars) do
    clauses
    |> Enum.with_index()
    |> Enum.any?(fn {clause, index} ->
      downstream_var_counts =
        clauses
        |> Enum.drop(index + 1)
        |> Enum.map(&rhs_vars_from_clause/1)
        |> Enum.reduce(%{}, &merge_var_counts/2)
        |> merge_var_counts(Map.new(do_block_vars, &{&1, 1}))

      clause
      |> bound_vars_from_clause()
      |> Enum.any?(fn var -> Map.get(downstream_var_counts, var, 0) >= 2 end)
    end)
  end

  defp either_with_candidate?(clauses) do
    Enum.all?(clauses, &either_with_clause?/1) and
      Enum.any?(clauses, &value_binding_with_clause?/1)
  end

  defp either_with_clause?({:<-, _, [pattern, _rhs]}), do: either_success_pattern?(pattern)
  defp either_with_clause?(_clause), do: false

  defp value_binding_with_clause?({:<-, _, [pattern, _rhs]}), do: ok_binding_pattern?(pattern)
  defp value_binding_with_clause?(_clause), do: false

  defp do_block_used_vars(args) do
    args
    |> List.last()
    |> case do
      opts when is_list(opts) -> Keyword.get(opts, :do)
      _other -> nil
    end
    |> used_vars()
  end

  defp bound_vars_from_clause({:<-, _, [pattern, _rhs]}), do: bound_vars(pattern)
  defp rhs_vars_from_clause({:<-, _, [_pattern, rhs]}), do: var_counts(rhs)

  defp bound_vars(ast) do
    Macro.prewalk(ast, MapSet.new(), fn
      {name, _, context} = node, acc when is_atom(name) and is_atom(context) ->
        if variable_name?(name), do: {node, MapSet.put(acc, name)}, else: {node, acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp used_vars(nil), do: MapSet.new()

  defp used_vars(ast) do
    Macro.prewalk(ast, MapSet.new(), fn
      {name, _, context} = node, acc when is_atom(name) and is_atom(context) ->
        if variable_name?(name), do: {node, MapSet.put(acc, name)}, else: {node, acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp var_counts(ast) do
    Macro.prewalk(ast, %{}, fn
      {name, _, context} = node, acc when is_atom(name) and is_atom(context) ->
        if variable_name?(name),
          do: {node, Map.update(acc, name, 1, &(&1 + 1))},
          else: {node, acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp merge_var_counts(left, right) do
    Map.merge(left, right, fn _key, left_count, right_count -> left_count + right_count end)
  end

  defp variable_name?(name) do
    name
    |> Atom.to_string()
    |> String.starts_with?("_")
    |> Kernel.not()
  end

  defp either_case_candidate?(clauses) do
    Enum.any?(clauses, &ok_clause?/1) and Enum.any?(clauses, &error_clause?/1)
  end

  defp ok_clause?({:->, _, [[pattern], _result]}), do: ok_pattern?(pattern)
  defp ok_clause?(_clause), do: false

  defp error_clause?({:->, _, [[pattern], _result]}), do: error_pattern?(pattern)
  defp error_clause?(_clause), do: false

  defp ok_pattern?(pattern), do: ok_binding_pattern?(pattern)

  defp ok_binding_pattern?({:ok, _value}), do: true
  defp ok_binding_pattern?({:{}, _, [:ok, _value]}), do: true

  defp ok_binding_pattern?(pattern) when is_list(pattern),
    do: Keyword.keyword?(pattern) and match?([ok: _], pattern)

  defp ok_binding_pattern?(_pattern), do: false

  defp either_success_pattern?(pattern) do
    ok_binding_pattern?(pattern) or pattern == :ok
  end

  defp error_pattern?(pattern) when is_list(pattern),
    do: Keyword.keyword?(pattern) and match?([error: _], pattern)

  defp error_pattern?({:{}, _, [:error | args]}) when length(args) in [1, 2], do: true
  defp error_pattern?({:error, _reason}), do: true
  defp error_pattern?({:error, _reason, _detail}), do: true
  defp error_pattern?(_pattern), do: false

  defp issue_for_with(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Multi-clause 'with' detected. Consider using the Either DSL (Funx.Monad.Either) for better readability.",
      line_no: line_no
    )
  end

  defp issue_for_nested_case(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Nested 'case' detected. Consider flattening with the Either DSL (Funx.Monad.Either.bind).",
      line_no: line_no
    )
  end
end
