defmodule Funx.Credo.Check.Readability.VerboseConditionalPipeTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags then lambda that returns the piped value from the else branch" do
    issues =
      run_check("""
      defmodule Example do
        def run(value, enabled?) do
          value
          |> then(fn result -> if enabled?, do: transform(result), else: result end)
        end
      end
      """)

    assert_issue_lines(issues, [4])
  end

  test "ignores ordinary pipes" do
    issues =
      run_check("""
      defmodule Example do
        def run(value) do
          value
          |> transform()
        end
      end
      """)

    assert issues == []
  end

  test "ignores conditional pipe when else branch returns a different expression" do
    issues =
      run_check("""
      defmodule Example do
        def run(value, enabled?) do
          value
          |> then(fn result -> if enabled?, do: transform(result), else: fallback(result) end)
        end
      end
      """)

    assert issues == []
  end

  defp run_check(source, filename \\ "lib/example.ex") do
    source
    |> SourceFile.parse(filename)
    |> Funx.Credo.Check.Readability.VerboseConditionalPipe.run([])
  end

  defp assert_issue_lines(issues, expected_lines) do
    assert Enum.map(issues, & &1.line_no) |> Enum.sort() == expected_lines
  end
end
