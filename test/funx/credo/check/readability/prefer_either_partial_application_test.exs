defmodule Funx.Credo.Check.Readability.PreferEitherPartialApplicationTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags bind lambda that only places the pipeline value into the first argument" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename, categories) do
            either :bytes do
              bind fn image_bytes -> get_image_metadata(image_bytes, filename, categories) end
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "flags map lambda that only places the pipeline value into the first argument" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename) do
            either :bytes do
              map fn image_bytes -> transform(image_bytes, filename) end
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "flags tap lambda that only places the pipeline value into the first argument" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename) do
            either :bytes do
              tap fn image_bytes -> log(image_bytes, filename) end
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "flags remote calls that only place the pipeline value into the first argument" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename, categories) do
            either :bytes do
              bind fn image_bytes -> Metadata.get(image_bytes, filename, categories) end
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "ignores bind lambda when the pipeline value is transformed" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename) do
            either :bytes do
              bind fn image_bytes -> get_image_metadata(Base.encode64(image_bytes), filename) end
            end
          end
        end
        """
      )

    assert issues == []
  end

  test "ignores bind lambda when the pipeline value is used in another argument too" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferEitherPartialApplication,
        """
        defmodule Example do
          def run(filename) do
            either :bytes do
              bind fn image_bytes -> get_image_metadata(image_bytes, filename, image_bytes) end
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
