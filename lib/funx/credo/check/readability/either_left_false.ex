defmodule Funx.Credo.Check.Readability.EitherLeftFalse do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :high,
    category: :readability,
    explanations: [
      check: """
      Using `false` as an error value in `Either.left(false)` is ambiguous and
      provides no semantic information about what went wrong.

      Error values should be meaningful domain-specific atoms or tuples that
      clearly communicate the failure reason.

      ## Examples

      Bad:

          either user do
            bind fn u ->
              if valid?(u) do
                Either.right(u)
              else
                Either.left(false)  # Ambiguous!
              end
            end
          end

      Good:

          either user do
            bind fn u ->
              if valid?(u) do
                Either.right(u)
              else
                Either.left(:invalid_user)
              end
            end
          end

      Good:

          either user do
            bind fn u ->
              if valid?(u) do
                Either.right(u)
              else
                Either.left({:validation_failed, "User must be active"})
              end
            end
          end

      """,
      params: []
    ]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse(
         {{:., meta, [either_module, :left]}, _call_meta, [false]} = ast,
         issues,
         issue_meta
       ) do
    if either_alias?(either_module) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp either_alias?({:__aliases__, _, [:Either]}), do: true
  defp either_alias?({:__aliases__, _, [:Funx, :Monad, :Either]}), do: true
  defp either_alias?(_), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "`Either.left(false)` is ambiguous. Prefer a meaningful domain error atom or tuple.",
      line_no: line_no
    )
  end
end
