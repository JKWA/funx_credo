defmodule Funx.Credo.ConsecutiveEitherValidationsCheckTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags consecutive validate steps in an either block" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.ConsecutiveEitherValidations,
        """
        defmodule Example do
          def run(assigns, matter_id, actor, doc_id) do
            either matter_id do
              bind Matters.get_matter(actor: actor)
              validate validate_firm_access(assigns)
              validate validate_matter_open()
              bind get_document_for_matter(doc_id, actor)
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [5])
  end

  test "does not flag a single validate step" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.ConsecutiveEitherValidations,
        """
        defmodule Example do
          def run(matter_id, actor) do
            either matter_id do
              bind Matters.get_matter(actor: actor)
              validate validate_matter_open()
            end
          end
        end
        """
      )

    assert issues == []
  end

  test "does not flag an existing validate list" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.ConsecutiveEitherValidations,
        """
        defmodule Example do
          def run(assigns, matter_id, actor) do
            either matter_id do
              bind Matters.get_matter(actor: actor)
              validate [validate_firm_access(assigns), validate_matter_open()]
            end
          end
        end
        """
      )

    assert issues == []
  end

  test "does not flag separated validate steps" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.ConsecutiveEitherValidations,
        """
        defmodule Example do
          def run(assigns, matter_id, actor) do
            either matter_id do
              validate validate_firm_access(assigns)
              bind Matters.get_matter(actor: actor)
              validate validate_matter_open()
            end
          end
        end
        """
      )

    assert issues == []
  end

  defp run_check(check, source, filename \\ "lib/example.ex") do
    source
    |> SourceFile.parse(filename)
    |> check.run([])
  end

  defp assert_issue_lines(issues, expected_lines) do
    assert Enum.map(issues, & &1.line_no) |> Enum.sort() == expected_lines
  end
end
