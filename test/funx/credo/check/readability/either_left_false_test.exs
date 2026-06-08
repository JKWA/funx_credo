defmodule Funx.Credo.EitherLeftFalseCheckTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags Either.left(false) with alias" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherLeftFalse,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run do
            Either.left(false)
          end
        end
        """
      )

    assert_issue_lines(issues, [5])
  end

  test "flags fully qualified Either.left(false)" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherLeftFalse,
        """
        defmodule Example do
          def run do
            Funx.Monad.Either.left(false)
          end
        end
        """
      )

    assert_issue_lines(issues, [3])
  end

  test "ignores meaningful left values" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherLeftFalse,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run do
            Either.left(:document_not_in_matter)
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
