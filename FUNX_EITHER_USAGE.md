# Funx Either DSL — Usage Rules

For LLM consumption.

## When to Use

**Use**: 2+ sequential fallible operations, short-circuiting errors, eliminating nested `case`

**Don't use**: Single operation (use `case`), threading multiple independent values

## Standard Pattern

```elixir
use Funx.Monad.Either
alias Funx.Monad.Either.{Left, Right}

either input_value do
  bind fetch(extra_arg, authorize?: false)
  map fn record -> build_params(record) end
  bind mutate(extra_arg, actor: actor)
end
|> case do
  %Right{right: result} -> success_response(result)
  %Left{left: %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> not_found()
  %Left{left: error} -> error_response(error)
end
```

## Operators

**`bind`** - Fallible operations. Partial application: `bind action(arg)` → `fn val -> action(val, arg) end`

```elixir
bind download(token, drive)  # (file_id, token, drive)
bind store(filename, type)   # (content, filename, type)

# Inside lambdas, qualify:
bind fn x -> case fetch(x) do
  {:ok, r} -> Either.right(r)
  _ -> Either.left(:not_found)
end end
```

**`map`** - Infallible transforms. Remove `{:ok, _}` wrappers:

```elixir
# Before: defp norm(p), do: {:ok, do_norm(p)}; bind norm()
# After:  defp norm(p), do: do_norm(p); map norm()
```

**`validate`** - Value-preserving checks:

```elixir
validate [check_config(), check_site(), check_drive()]
```

**`tap`** - Side effects (logs, telemetry). No "maybe_" prefix—tap implies optional.

**`map_left`** - Tag errors for pattern matching. Don't use solely for logging—log in helpers.

## Pattern Matching

**Default**: `%Right{}`/`%Left{}`

```elixir
|> case do
  %Right{right: text} -> text
  %Left{} -> ""
end
```

**`as: :tuple`**: Only at API boundaries returning `{:ok, _}`/`{:error, _}`

```elixir
# Good: returning tuple directly
def api_fn(id) do
  either id, as: :tuple do
    bind fetch(); bind process()
  end
end

# Bad: tuple then case match
either id, as: :tuple do ... end
|> case do {:ok, x} -> x; _ -> "" end
```

**Rule**: `as: :tuple` + return = ✅ | `as: :tuple` + case = ❌

## Boundaries & Sentinels

**Private helpers**: Prefer returning Either (`%Right{}`/`%Left{}`) from private fallible helpers. Use `as: :tuple` for public/API functions that must return `{:ok, _}`/`{:error, _}`.

**Tuple conversion**: Use the built-ins at boundaries:

```elixir
Either.from_result(scoped_call())
Either.to_result(either_value)
```

Don't hand-roll:

```elixir
case result do
  {:ok, value} -> %Right{right: value}
  {:error, reason} -> %Left{left: reason}
end
```

**No sentinel errors**: Don't use domain values like `[]`, `nil`, or fallback structs to mean failure inside an Either workflow. Return `Left` for failure and convert to a domain fallback only at the boundary that owns the fallback policy.

```elixir
either query do
  bind embed(usage_context)
  bind fetch_pages(state)
  filter_or_else fn pages -> pages != [] end, fn -> :no_pages end
end
|> case do
  %Right{right: pages} -> pages
  %Left{} -> []
end
```

**Use `filter_or_else` for required non-empty values**: If `Right([])` means the workflow cannot contribute, convert it to `Left` in the pipeline. If `[]` is a valid domain result, leave it as `Right([])`.

**Domain fallback values are okay when named clearly**: A fallback like `unindexed_document_fallback_queue/1` is an infallible `map` result, not a `Left`, because it intentionally represents a valid downstream read strategy.

## Validation

**Built-ins first**: `IsTrue`, `IsFalse`, `NonEmpty`, `In`, `Pattern`, `Not`

```elixir
validate do
  at [:result, :found], IsFalse
  at [:result, :citations], NonEmpty
end
```

**LiftPredicate**: Simple checks

```elixir
LiftPredicate.validate(plan, pred: fn _ -> available?(state) end, message: fn _ -> "no reads" end)
```

**Custom validators** (`lib/domain/validations/`):

```elixir
defmodule Domain.Validations.Check do
  use Funx.Validator
  def valid?(val, _, _), do: test(val)
  def default_message(_, _), do: "failed"
end
```

**Funx.Validate**: Field paths. Add `Required` explicitly—`at` uses Prism (missing → `Nothing`).

```elixir
validate do
  at :action, [Required, {In, values: [:create, :update]}]
end
```

**Predicate DSL**: Complex boolean logic

```elixir
pred do
  check :val, {PredicateNotEq, value: true}
  check :question, fn q -> test?(q) end
  negate check :answer, Predicates.Insufficiency
end
```

**Validation-gated infallible**:

```elixir
case Either.validate(ctx, preconditions) do
  %Right{} -> synthesize(...)  # infallible
  %Left{} -> original
end
```

Why not `or_else`? Function is infallible (returns plain value), `or_else` expects Either.

## Helpers

**Argument order**: Pipeline value first if helper exists for pipeline

**Naming**: Domain step (not `*_result`). `?` for boolean predicates, not Either returns.

**Hoist**: Build params before `either` block

**Keep logic in parent pipelines**: Long, sequential `either` blocks are EASIER for humans to read than jumping between helpers. Show the full workflow in one place.

```elixir
# Good: humans read top-to-bottom
either context, as: :tuple do
  bind fetch_rows()
  map decode_rows(context)
  bind load_records()
  map build_results()
end

# Bad: forces mental jumps to helpers
either context, as: :tuple do
  bind fetch_rows()
  map decode_rows(context)
  bind load_and_build_results()
end

defp load_and_build_results(context) do
  either context.ids, as: :tuple do
    bind load_records()
    map build_results(context)
  end
end
```

Extract to nested `either` only for reusable workflows, not to shorten parent.

**Avoid tiny adapter wrappers**: If a helper only exists to adapt argument order or wrap one final operation, prefer keeping that operation visible in the parent pipeline.

```elixir
# Good: final operation remains visible
either document, as: :tuple do
  bind load_document_content(opts)
  bind require_live_draft_content_target()
  bind update_document_draft_content(attrs, opts)

  bind fn updated_draft ->
    update_document(
      document,
      Map.take(updated_draft, @draft_attrs),
      opts
    )
  end
end

# Avoid: hides the final operation behind a one-off adapter
either document, as: :tuple do
  bind load_document_content(opts)
  bind require_live_draft_content_target()
  bind update_document_draft_content(attrs, opts)
  bind replace_document_content_attrs(document, opts)
end

defp replace_document_content_attrs(updated_draft, document, opts) do
  update_document(document, Map.take(updated_draft, @draft_attrs), opts)
end
```

**Logging**: In helpers where errors occur, not `map_left` tags

```elixir
# Good
defp download(url, file) do
  case HTTP.get(url) do
    {:ok, c} -> {:ok, c}
    {:error, r} -> Logger.error("Download failed: #{inspect(r)}"); {:error, r}
  end
end

# Avoid
either do bind download(); map_left fn r -> {:failed, r} end end
|> case do {:error, {:failed, r}} -> Logger.error(...) end
```

## Bind Modules

Location: `lib/domain/binds/`

```elixir
defmodule Domain.Binds.GetChild do
  @behaviour Funx.Monad.Behaviour.Bind
  alias Funx.Monad.Either

  def bind(parent, opts, _) do
    case get(opts[:child_id]) do
      {:ok, child} when child.parent_id == parent.id -> Either.right(child)
      _ -> Either.left(:not_found)
    end
  end
end

# Usage: bind {GetChild, child_id: id}
```

Don't `use Funx.Monad.Either` in Bind modules.

## LiveView

**Never bang methods** (`Ash.load!`, `Ash.read!`)—crashes tear down process.

**Centralized error mapping**:

```elixir
defp handle_error(socket, path, errors) do
  cond do
    Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) ->
      put_flash(socket, :error, "Not found") |> redirect(to: path)
    Enum.any?(errors, &match?(%Ash.Error.Forbidden{}, &1)) ->
      put_flash(socket, :error, "Access denied") |> redirect(to: path)
    true ->
      put_flash(socket, :error, "Error") |> redirect(to: path)
  end
end
```

**Unified loading**: Same shape in mount and reloads

## DELETE Pattern

```elixir
def delete_child(conn, %{"parent_id" => pid, "id" => cid}) do
  Logger.metadata(action: "delete_child", parent_id: pid, child_id: cid)

  either pid do
    bind get_parent(shop, authorize?: false)
    bind {GetChildForParent, child_id: cid}
    bind Ash.destroy(authorize?: false)
  end
  |> case do
    %Right{} ->
      :telemetry.execute([:app, :delete_child, :success], %{count: 1})
      Logger.reset_metadata(); json(conn, %{deleted: true})
    %Left{left: :not_found} ->
      :telemetry.execute([:app, :delete_child, :failure], %{count: 1})
      Logger.reset_metadata(); not_found(conn, "Not found")
    %Left{left: error} ->
      :telemetry.execute([:app, :delete_child, :failure], %{count: 1})
      Logger.error("Delete failed: #{inspect(error)}")
      Logger.reset_metadata(); conn |> put_status(422) |> json(%{error: "Failed"})
  end
end
```

Requirements: Bind module for ownership, telemetry every branch, `reset_metadata()` every branch, log errors only on unexpected failures.

## Error Conventions

| Case | Status | Log |
|------|--------|-----|
| Ash NotFound | 404 | No |
| Tagged atom | 404 | No |
| Validation | 422 | Yes |
| Unexpected | 500 | Yes |

## Anti-Patterns

- `as: :tuple` then case match
- Helpers that pattern match `{:ok, _}`/`{:error, _}` (inline in `either` block)
- Wrapping single fallible operations in case helpers (use `bind`)
- `Ash.load!` in pipelines
- Bang methods in LiveViews
- Inline lambdas reused 2+ times (use Bind module)
- Either for single call (use `case`)
- `map_left` solely for logging
- "maybe_" prefix on tap'd functions
- `bind` for infallible (use `map`)
- `bind` for checks (use `validate`)

## No Tuple-Matching Helpers

```elixir
# Bad: helper pattern matches tuples
defp fetch_and_transform(id) do
  case fetch(id) do
    {:ok, x} -> transform(x)
    {:error, r} -> {:error, r}
  end
end

# Good: inline in either block
either id do
  bind fetch()
  map transform()
end

# Bad: multiple clause helper
defp handle_result({:ok, data}), do: process(data)
defp handle_result({:error, _}), do: default()

# Good: case on Either result
either input do
  bind fetch()
  map process()
end
|> case do
  %Right{right: x} -> x
  %Left{} -> default()
end
```
