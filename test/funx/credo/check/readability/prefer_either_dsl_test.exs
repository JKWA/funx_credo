defmodule Funx.Credo.Check.Readability.PreferEitherDSLTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  test "flags multi-clause with when success body uses one clause value" do
    issues =
      run_check("""
      defmodule Example do
        def run(id) do
          with {:ok, user} <- fetch_user(id),
               {:ok, account} <- fetch_account(user.account_id) do
            {:ok, account}
          else
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """)

    assert_issue_lines(issues, [3])
  end

  test "ignores multi-clause with when success body needs values from multiple clauses" do
    issues =
      run_check("""
      defmodule Example do
        def export(id) do
          with {:ok, firm} <- fetch_firm(id),
               {:ok, activity} <- fetch_activity(firm.id),
               {:ok, binary} <- build_export(firm, activity.results) do
            {:ok, %{firm: firm.name, binary: binary}}
          else
            {:error, reason} -> {:error, reason}
          end
        end
      end
      """)

    assert issues == []
  end

  test "ignores with when bound values are reused downstream" do
    issues =
      run_check("""
      defmodule Example do
        def record(provider, operation, usage, usage_context) do
          with {:ok, actor} <- fetch_actor(usage_context),
               {:ok, firm_id} <- resolve_firm_id(usage_context),
               {:ok, event_attrs} <- build_event_attrs(provider, operation, usage, usage_context, firm_id),
               {:ok, event} <- create_event(event_attrs, actor, firm_id),
               :ok <- attach_scopes(event, usage_context, actor, firm_id) do
            {:ok, event}
          else
            {:skip, _reason} = skip -> skip
            {:error, _reason} = error -> error
          end
        end
      end
      """)

    assert issues == []
  end

  test "flags nested case statements" do
    issues =
      run_check("""
      defmodule Example do
        def run(id) do
          case fetch_user(id) do
            {:ok, user} ->
              case fetch_account(user.account_id) do
                {:ok, account} -> {:ok, account}
                {:error, reason} -> {:error, reason}
              end

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
      """)

    assert_issue_lines(issues, [5])
  end

  test "ignores nested case when outer flow is not either-shaped" do
    issues =
      run_check("""
      defmodule Example do
        def run(current_permissions, email) do
          case Map.fetch(current_permissions, email) do
            {:ok, %{id: permission_id}} ->
              case remove_permission(permission_id, email) do
                :ok -> {:ok, email}
                {:error, reason} -> {:error, email, reason}
              end

            :error ->
              {:error, email, :missing_permission_id}
          end
        end
      end
      """)

    assert issues == []
  end

  test "ignores nested case fallback in error branch" do
    issues =
      run_check("""
      defmodule Example do
        def resolve(query) do
          case direct_lookup(query) do
            {:ok, document} ->
              {:ok, document.id, document.name}

            {:error, _reason} ->
              case fallback_search(query) do
                {:ok, [result | _rest]} -> {:ok, result.id, result.title}
                {:ok, []} -> {:error, :not_found}
                {:error, reason} -> {:error, {:lookup_failed, reason}}
              end
          end
        end
      end
      """)

    assert issues == []
  end

  defp run_check(source, filename \\ "lib/example.ex") do
    source
    |> SourceFile.parse(filename)
    |> Funx.Credo.Check.Readability.PreferEitherDSL.run([])
  end

  defp assert_issue_lines(issues, expected_lines) do
    assert Enum.map(issues, & &1.line_no) |> Enum.sort() == expected_lines
  end
end
