defmodule Funx.Credo.Check.Readability.EitherWrappedResultTuple do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :high,
    category: :readability,
    explanations: [
      check: """
      Either.left and Either.right represent error and success channels respectively.
      Wrapping result tuples like `{:ok, value}` or `{:error, reason}` creates
      unnecessary double-wrapping since Either already provides that structure.

      ## Examples

      Bad:

          either id do
            bind fn user_id ->
              case fetch_user(user_id) do
                {:ok, user} -> Either.right({:ok, user})  # Double-wrapped!
                {:error, reason} -> Either.left({:error, reason})  # Double-wrapped!
              end
            end
          end

      Good:

          either id do
            bind fn user_id ->
              case fetch_user(user_id) do
                {:ok, user} -> Either.right(user)
                {:error, reason} -> Either.left(reason)
              end
            end
          end

      ## Rationale

      Either.left already represents an error, so wrapping it in `{:error, ...}`
      is redundant. Similarly, Either.right already represents success, so
      `{:ok, ...}` adds no value.

      """,
      params: []
    ]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse(
         {{:., meta, [either_module, branch]}, _call_meta, [tuple_arg]} = ast,
         issues,
         issue_meta
       )
       when branch in [:left, :right] do
    if either_alias?(either_module) and wrapped_result_tuple?(branch, tuple_arg) do
      {ast, [issue_for(issue_meta, meta[:line], branch) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp either_alias?({:__aliases__, _, [:Either]}), do: true
  defp either_alias?({:__aliases__, _, [:Funx, :Monad, :Either]}), do: true
  defp either_alias?(_), do: false

  defp wrapped_result_tuple?(:left, {:error, _reason}), do: true
  defp wrapped_result_tuple?(:left, {:{}, _, [:error, _reason]}), do: true

  defp wrapped_result_tuple?(:left, keyword) when is_list(keyword),
    do: match?([error: _], keyword)

  defp wrapped_result_tuple?(:right, {:ok, _value}), do: true
  defp wrapped_result_tuple?(:right, {:{}, _, [:ok, _value]}), do: true
  defp wrapped_result_tuple?(:right, keyword) when is_list(keyword), do: match?([ok: _], keyword)

  defp wrapped_result_tuple?(_, _), do: false

  defp issue_for(issue_meta, line_no, :left) do
    format_issue(issue_meta,
      message:
        "`Either.left({:error, ...})` double-wraps an error. Prefer `Either.left(reason)`.",
      line_no: line_no
    )
  end

  defp issue_for(issue_meta, line_no, :right) do
    format_issue(issue_meta,
      message:
        "`Either.right({:ok, ...})` double-wraps a success value. Prefer `Either.right(value)`.",
      line_no: line_no
    )
  end
end
