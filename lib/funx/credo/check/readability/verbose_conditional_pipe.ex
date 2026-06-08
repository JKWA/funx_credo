defmodule Funx.Credo.Check.Readability.VerboseConditionalPipe do
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
         {:|>, meta,
          [
            _,
            {:then, _,
             [
               {:fn, _,
                [
                  {:->, _,
                   [
                     [{var_name, _, var_context}],
                     {:if, _, [_condition, clauses]}
                   ]}
                ]}
             ]}
          ]} = ast,
         issues,
         issue_meta
       ) do
    if same_variable?(Keyword.get(clauses, :else), {var_name, [], var_context}) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _), do: {ast, issues}

  defp same_variable?({name, _, context}, {name, _, context}), do: true
  defp same_variable?(_, _), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message: "Verbose conditional pipe detected. Consider a 'maybe' helper function.",
      line_no: line_no
    )
  end
end
