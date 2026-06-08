defmodule Funx.Credo.EitherWrappedResultTupleCheckTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags Either.left({:error, reason})" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherWrappedResultTuple,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run(reason) do
            Either.left({:error, reason})
          end
        end
        """
      )

    assert_issue_lines(issues, [5])
  end

  test "flags Either.right({:ok, value})" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherWrappedResultTuple,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run(value) do
            Either.right({:ok, value})
          end
        end
        """
      )

    assert_issue_lines(issues, [5])
  end

  test "ignores plain Either.left(reason)" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherWrappedResultTuple,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run(reason) do
            Either.left(reason)
          end
        end
        """
      )

    assert issues == []
  end

  test "ignores plain Either.right(value)" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.EitherWrappedResultTuple,
        """
        defmodule Example do
          alias Funx.Monad.Either

          def run(value) do
            Either.right(value)
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
