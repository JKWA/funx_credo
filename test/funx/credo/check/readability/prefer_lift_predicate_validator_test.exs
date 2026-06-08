defmodule Funx.Credo.PreferLiftPredicateValidatorCheckTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags validate helpers that directly wrap Either.lift_predicate" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferLiftPredicateValidator,
        """
        defmodule Example do
          alias Funx.Monad.Either

          defp validate_zip_size(binary) do
            Either.lift_predicate(
              binary,
              &(byte_size(&1) <= 1024),
              fn _ -> "too large" end
            )
          end
        end
        """
      )

    assert_issue_lines(issues, [4])
  end

  test "flags fully-qualified Either.lift_predicate in validate helpers" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferLiftPredicateValidator,
        """
        defmodule Example do
          def validate_sharepoint_site(firm) do
            Funx.Monad.Either.lift_predicate(
              firm,
              fn %{site_id: site_id} -> is_binary(site_id) end,
              fn _ -> :missing_site end
            )
          end
        end
        """
      )

    assert_issue_lines(issues, [2])
  end

  test "ignores non-validate helpers using Either.lift_predicate" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferLiftPredicateValidator,
        """
        defmodule Example do
          alias Funx.Monad.Either

          defp require_positive(value) do
            Either.lift_predicate(value, &(&1 > 0), fn _ -> :non_positive end)
          end
        end
        """
      )

    assert issues == []
  end

  test "ignores validate helpers that are not direct lift_predicate wrappers" do
    issues =
      run_check(
        Funx.Credo.Check.Readability.PreferLiftPredicateValidator,
        """
        defmodule Example do
          defp validate_payload(payload) do
            case payload do
              %{ok: true} -> {:ok, payload}
              _ -> {:error, :invalid}
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
