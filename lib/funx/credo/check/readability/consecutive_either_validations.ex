defmodule Funx.Credo.Check.Readability.ConsecutiveEitherValidations do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :readability

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({:either, _meta, args} = ast, issues, issue_meta) do
    operations =
      args
      |> extract_do_block()
      |> block_lines()

    new_issues =
      operations
      |> consecutive_validate_runs()
      |> Enum.reduce(issues, fn run, acc ->
        [issue_for(issue_meta, run) | acc]
      end)

    {ast, new_issues}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp block_lines({:__block__, _, lines}) when is_list(lines), do: lines
  defp block_lines(nil), do: []
  defp block_lines(single), do: [single]

  defp extract_do_block(args) when is_list(args) do
    args
    |> List.last()
    |> case do
      opts when is_list(opts) -> Keyword.get(opts, :do)
      _other -> nil
    end
  end

  defp consecutive_validate_runs(operations) do
    operations
    |> Enum.chunk_by(&validate_call?/1)
    |> Enum.filter(fn chunk ->
      length(chunk) >= 2 and Enum.all?(chunk, &validate_call?/1)
    end)
    |> Enum.reject(fn chunk -> Enum.any?(chunk, fn op -> validate_list_call?(op) end) end)
  end

  defp validate_call?({:validate, _, [_arg]}), do: true
  defp validate_call?(_), do: false

  defp validate_list_call?({:validate, _, [arg]}) when is_list(arg), do: true
  defp validate_list_call?(_), do: false

  defp issue_for(issue_meta, [first | _rest]) do
    line_no =
      case first do
        {:validate, meta, _} -> meta[:line]
        _ -> nil
      end

    format_issue(issue_meta,
      message:
        "Multiple consecutive `validate` steps detected in an Either block. Combine them into a single `validate [...]` list.",
      line_no: line_no
    )
  end
end
