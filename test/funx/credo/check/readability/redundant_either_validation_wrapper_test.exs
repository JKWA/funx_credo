defmodule Funx.Credo.Check.Readability.RedundantEitherValidationWrapperTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags validation case that wraps into Either.right/left" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.RedundantEitherValidationWrapper,
        """
        defmodule Example do
          alias Funx.Monad.Either

          defp check_sharepoint_tracking(document) do
            case validate_sharepoint_tracking(document) do
              :ok -> Either.right(document)
              {:error, reason} -> Either.left({:validation, reason})
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [5])
  end

  test "flags piped validation case that wraps into Either.right/left" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.RedundantEitherValidationWrapper,
        """
        defmodule Example do
          alias Funx.Monad.Either

          defp check_client_state(subscription, notification) do
            validate_client_state(subscription, notification)
            |> case do
              :ok -> Either.right(subscription)
              {:error, reason} -> Either.left({:error, reason})
            end
          end
        end
        """
      )

    assert_issue_lines(issues, [6])
  end

  test "ignores non-validate case wrappers" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.RedundantEitherValidationWrapper,
        """
        defmodule Example do
          alias Funx.Monad.Either

          defp load_document(id) do
            case fetch_document(id) do
              {:ok, document} -> Either.right(document)
              {:error, reason} -> Either.left(reason)
            end
          end
        end
        """
      )

    assert issues == []
  end

  test "ignores validation case that does not wrap into Either" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.RedundantEitherValidationWrapper,
        """
        defmodule Example do
          defp validate_document(document) do
            case validate_sharepoint_tracking(document) do
              :ok -> :ok
              {:error, reason} -> {:error, reason}
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
