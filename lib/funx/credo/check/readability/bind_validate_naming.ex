defmodule Funx.Credo.Check.Readability.BindValidateNaming do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :normal,
    category: :consistency,
    explanations: [
      check: """
      In the Either DSL, `bind` is used for transformations that return Either
      values, while `validate` is used for precondition checks.

      When a `bind` operation calls a function named with the `validate_*` prefix,
      it creates semantic confusion about whether this is a transformation or a
      validation check.

      ## Examples

      Bad:

          either user do
            bind validate_permissions()  # Stops on first error, loses other validation failures
            bind validate_account_status()
          end

      Good (collect all validation errors):

          either user do
            validate [
              check_permissions(),
              check_account_status()
            ]
          end

      Good (if it's actually a transformation that returns Either):

          either user do
            bind load_permissions()  # Clear transformation, not validate_*
          end

      ## Rationale

      Clear naming helps readers understand the flow:
      - `bind` with `validate_*` -> semantic mismatch
      - `validate` with `check_*` or predicates -> clear validation
      - `bind` with transformation verbs -> clear transformation

      """,
      params: []
    ]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse({:bind, meta, [operation]} = ast, issues, issue_meta) do
    if validate_named_operation?(operation) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp validate_named_operation?({name, _, args})
       when is_atom(name) and is_list(args) do
    validate_named_function?(name)
  end

  defp validate_named_operation?({{:., _, [_module_ast, name]}, _, args})
       when is_atom(name) and is_list(args) do
    validate_named_function?(name)
  end

  defp validate_named_operation?(_), do: false

  defp validate_named_function?(name) do
    name
    |> Atom.to_string()
    |> String.starts_with?("validate")
  end

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "`bind` is calling a `validate*` helper. Prefer `validate [...]` for predicate/precondition checks, or rename the helper if it is a transforming bind step.",
      line_no: line_no
    )
  end
end
