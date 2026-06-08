defmodule Funx.Credo.Check.Readability.PreferEitherPartialApplication do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :readability

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse(
         {op, meta, [{:fn, _, [{:->, _, [[arg], body]}]}]} = ast,
         issues,
         issue_meta
       )
       when op in [:bind, :map, :tap] do
    if partial_application_candidate?(arg, body) do
      {ast, [issue_for(issue_meta, meta[:line], op) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _), do: {ast, issues}

  defp partial_application_candidate?({name, _, context} = arg, call_ast)
       when is_atom(name) and is_atom(context) do
    case call_ast do
      {{:., _, [_module_ast, _function_name]}, _, [first_arg | remaining_args]} ->
        same_variable?(arg, first_arg) and not variable_used?(arg, remaining_args)

      {function_name, _, [first_arg | remaining_args]}
      when is_atom(function_name) and function_name not in [:__block__] ->
        same_variable?(arg, first_arg) and not variable_used?(arg, remaining_args)

      _ ->
        false
    end
  end

  defp partial_application_candidate?(_, _), do: false

  defp same_variable?({name, _, context}, {name, _, context}), do: true
  defp same_variable?(_, _), do: false

  defp variable_used?(arg, ast_nodes) do
    Enum.any?(ast_nodes, fn ast ->
      {_ast, found?} =
        Macro.prewalk(ast, false, fn
          node, false ->
            {node, same_variable?(arg, node)}

          node, true ->
            {node, true}
        end)

      found?
    end)
  end

  defp issue_for(issue_meta, line_no, op) do
    format_issue(issue_meta,
      message:
        "Inline #{op} lambda only threads the pipeline value into the first argument. Prefer direct Either partial application.",
      line_no: line_no
    )
  end
end
