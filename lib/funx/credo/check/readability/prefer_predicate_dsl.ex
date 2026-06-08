defmodule Funx.Credo.Check.Readability.PreferPredicateDSL do
  @dialyzer :no_behaviours

  use Credo.Check,
    base_priority: :low,
    category: :readability,
    param_defaults: [min_terms: 4],
    explanations: [
      check: """
      Predicate functions with multiple boolean conditions may be more readable
      using Funx's Predicate DSL, especially when checking domain policy rules
      over known struct types.

      This check uses heuristics to identify good candidates while avoiding cases
      where the Predicate DSL would be a poor fit.

      ## Examples

      Bad (4+ boolean conditions):

          defp retryable?(%Result{} = result) do
            result.answer_present? and
              result.citations_present? and
              result.grounded? and
              not result.failure_text?
          end

      Good (using Predicate DSL):

          defp retryable?(%Result{} = result) do
            predicate =
              pred do
                check :answer_present?, IsTrue
                check :citations_present?, IsTrue
                check :grounded?, IsTrue
                check :failure_text?, IsFalse
              end

            predicate.(result)
          end

      ## When this check is NOT triggered

      This check intentionally avoids flagging cases where Predicate DSL is a poor fit:

      - Functions with fewer than the configured minimum boolean terms (default: 4)
      - Functions not named with `?` suffix (not predicate functions)
      - Loose external maps with string-key access
      - String classifier predicates (contains?, starts_with?, etc.)
      - Collection inspection logic (Enum operations)
      - IO-heavy calls (database queries, HTTP requests)

      """,
      params: [
        min_terms: "Minimum number of boolean terms to trigger this check (default: 4)"
      ]
    ]

  @string_classifier_functions [:contains?, :starts_with?, :ends_with?, :match?]
  @io_like_modules [Ash, Clerk.Documents, Req, Repo]

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    min_terms = Keyword.get(params, :min_terms, 4)
    Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta, min_terms))
  end

  defp traverse({definition, meta, [head, body]} = ast, issues, issue_meta, min_terms)
       when definition in [:def, :defp] do
    if predicate_function_head?(head) and not has_guard_clause?(head) and
         predicate_dsl_candidate?(head, body, min_terms) do
      {ast, [issue_for(issue_meta, meta[:line]) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta, _min_terms), do: {ast, issues}

  defp has_guard_clause?({:when, _, _}), do: true
  defp has_guard_clause?(_head), do: false

  defp predicate_function_head?({:when, _, [head | _guards]}), do: predicate_function_head?(head)

  defp predicate_function_head?({name, _, args}) when is_atom(name) and is_list(args) do
    name
    |> Atom.to_string()
    |> String.ends_with?("?")
  end

  defp predicate_function_head?(_head), do: false

  defp predicate_dsl_candidate?(head, body, min_terms) do
    expression = unwrap_body(body)

    boolean_chain?(expression) and
      boolean_term_count(expression) >= min_terms and
      not contains_predicate_dsl?(expression) and
      not false_positive_shape?(expression) and
      domain_policy_shape?(head, expression)
  end

  defp unwrap_body(do: expression), do: expression
  defp unwrap_body(expression), do: expression

  defp boolean_chain?({operator, _, [_left, _right]}) when operator in [:and, :or], do: true
  defp boolean_chain?(_expression), do: false

  defp boolean_term_count({operator, _, [left, right]}) when operator in [:and, :or] do
    boolean_term_count(left) + boolean_term_count(right)
  end

  defp boolean_term_count(_expression), do: 1

  defp false_positive_shape?(expression) do
    contains_string_key_access?(expression) or
      string_classifier_chain?(expression) or
      contains_io_like_call?(expression) or
      contains_collection_control_flow?(expression)
  end

  defp contains_string_key_access?(expression) do
    {_ast, found?} =
      Macro.prewalk(expression, false, fn
        {{:., _, [Access, :get]}, _, [_target, key]} = node, _found? when is_binary(key) ->
          {node, true}

        node, found? ->
          {node, found?}
      end)

    found?
  end

  defp string_classifier_chain?(expression) do
    terms = boolean_terms(expression)

    terms != [] and Enum.count(terms, &string_classifier_call?/1) / length(terms) >= 0.75
  end

  defp boolean_terms({operator, _, [left, right]}) when operator in [:and, :or] do
    boolean_terms(left) ++ boolean_terms(right)
  end

  defp boolean_terms(expression), do: [expression]

  defp string_classifier_call?({{:., _, [{:__aliases__, _, [:String]}, function]}, _, _args})
       when function in @string_classifier_functions,
       do: true

  defp string_classifier_call?(_expression), do: false

  defp contains_io_like_call?(expression) do
    {_ast, found?} =
      Macro.prewalk(expression, false, fn
        {{:., _, [{:__aliases__, _, module_parts}, _function]}, _, _args} = node, _found? ->
          {node, io_like_module?(Module.concat(module_parts))}

        node, found? ->
          {node, found?}
      end)

    found?
  end

  defp io_like_module?(module) do
    Enum.any?(@io_like_modules, fn io_module ->
      module == io_module or String.starts_with?(Atom.to_string(module), "#{io_module}.")
    end)
  end

  defp contains_collection_control_flow?(expression) do
    {_ast, found?} =
      Macro.prewalk(expression, false, fn
        {{:., _, [{:__aliases__, _, [:Enum]}, function]}, _, _args} = node, _found?
        when function in [:any?, :all?, :find] ->
          {node, true}

        {:case, _, _args} = node, _found? ->
          {node, true}

        {:cond, _, _args} = node, _found? ->
          {node, true}

        node, found? ->
          {node, found?}
      end)

    found?
  end

  defp domain_policy_shape?(head, expression) do
    has_struct_arg?(head) or struct_field_access_count(expression) >= 2
  end

  defp has_struct_arg?({:when, _, [head | _guards]}), do: has_struct_arg?(head)

  defp has_struct_arg?({_name, _, args}) when is_list(args) do
    Enum.any?(args, &struct_pattern?/1)
  end

  defp has_struct_arg?(_head), do: false

  defp struct_pattern?({:%, _, [_module, {:%{}, _, _fields}]}), do: true

  defp struct_pattern?({:=, _, [left, right]}),
    do: struct_pattern?(left) or struct_pattern?(right)

  defp struct_pattern?(_arg), do: false

  defp struct_field_access_count(expression) do
    {_ast, count} =
      Macro.prewalk(expression, 0, fn
        {{:., _, [{variable, _, context}, field]}, _, []} = node, count
        when is_atom(variable) and is_atom(context) and is_atom(field) ->
          {node, count + 1}

        node, count ->
          {node, count}
      end)

    count
  end

  defp contains_predicate_dsl?(expression) do
    {_ast, found?} =
      Macro.prewalk(expression, false, fn
        {:pred, _, [[do: _]]} = node, _found? -> {node, true}
        node, found? -> {node, found?}
      end)

    found?
  end

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Predicate function contains a multi-condition boolean chain. Consider using the Funx Predicate DSL (`pred do ... end`) with lens projections for struct fields.",
      line_no: line_no
    )
  end
end
