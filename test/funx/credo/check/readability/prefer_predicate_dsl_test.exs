defmodule Funx.Credo.Check.Readability.PreferPredicateDSLTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags predicate functions with multi-condition boolean chains" do
    issues =
      run_check("""
      defmodule Example do
        defp retryable?(%Result{} = result) do
          result.answer_present? and result.citations_present? and result.grounded? and not result.failure_text?
        end
      end
      """)

    assert_issue_lines(issues, [2])
  end

  test "flags mixed and/or predicate chains" do
    issues =
      run_check("""
      defmodule Example do
        def final?(%Input{} = input) do
          input.done? or input.complete? or input.cancelled? or input.exhausted?
        end
      end
      """)

    assert_issue_lines(issues, [2])
  end

  test "ignores two-condition predicate functions" do
    issues =
      run_check("""
      defmodule Example do
        defp active?(record) do
          record.enabled? and not record.archived?
        end
      end
      """)

    assert issues == []
  end

  test "ignores three-condition predicate functions" do
    issues =
      run_check("""
      defmodule Example do
        defp rename_triggers_sharepoint_sync?(doc) do
          Document.sharepoint_syncable?(doc) and
            is_binary(doc.sharepoint_item_id) and doc.sharepoint_item_id != ""
        end
      end
      """)

    assert issues == []
  end

  test "ignores non-predicate function names" do
    issues =
      run_check("""
      defmodule Example do
        def status(record) do
          record.enabled? and record.ready? and not record.archived?
        end
      end
      """)

    assert issues == []
  end

  test "ignores predicate functions already using Predicate DSL" do
    issues =
      run_check("""
      defmodule Example do
        use Funx.Predicate

        defp retryable?(result) do
          predicate =
            pred do
              check :answer, String
              check :citations, NonEmpty
              fn result -> not failure_text?(result) end
            end

          predicate.(result)
        end
      end
      """)

    assert issues == []
  end

  test "ignores loose external maps with string-key access" do
    issues =
      run_check("""
      defmodule Example do
        defp direct_user_identity?(identity) do
          is_map(identity["user"]) and
            is_nil(identity["group"]) and
            is_nil(identity["application"]) and
            is_nil(identity["device"])
        end
      end
      """)

    assert issues == []
  end

  test "ignores string classifier predicates" do
    issues =
      run_check("""
      defmodule Example do
        defp sharepoint_locked_error_message?(message) do
          String.contains?(message, "resourceLocked") or
            String.contains?(message, "resourceCheckedOut") or
            String.contains?(message, ":lock, 423") or
            String.contains?(message, ":unlock, 423") or
            String.contains?(message, ":checkin, 423")
        end
      end
      """)

    assert issues == []
  end

  test "ignores predicates with collection inspection" do
    issues =
      run_check("""
      defmodule Example do
        defp grounded_attempt_present?(%State{} = state) do
          state.documents != [] and
            Enum.any?(state.documents, fn doc -> doc.content != "" end) and
            state.phase == :answer and
            not state.cancelled?
        end
      end
      """)

    assert issues == []
  end

  defp run_check(source, filename \\ "lib/example.ex") do
    source
    |> SourceFile.parse(filename)
    |> Funx.Credo.Check.Readability.PreferPredicateDSL.run([])
  end

  defp assert_issue_lines(issues, expected_lines) do
    assert Enum.map(issues, & &1.line_no) |> Enum.sort() == expected_lines
  end
end
