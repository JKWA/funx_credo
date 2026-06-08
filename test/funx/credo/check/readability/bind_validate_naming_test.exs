defmodule Funx.Credo.BindValidateNamingCheckTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags bind with local validate helper" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.BindValidateNaming,
        """
        defmodule Example do
          def run(assigns, matter_id, actor, doc_id) do
            either matter_id do
              bind Matters.get_matter(actor: actor)
              bind validate_firm_access(assigns)
              bind validate_matter_open()
              bind get_and_validate_document(doc_id, actor)
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [5, 6])
  end

  test "flags bind with remote validate helper" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.BindValidateNaming,
        """
        defmodule Example do
          def run(value) do
            either value do
              bind Validators.validate_open()
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "ignores non-validate bind helpers" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.BindValidateNaming,
        """
        defmodule Example do
          def run(value, actor) do
            either value do
              bind Matters.get_matter(actor: actor)
              bind get_and_validate_document("doc-1", actor)
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
