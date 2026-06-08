defmodule FunxCredo do
  @moduledoc """
  Credo checks for teams adopting Funx.

  The checks are intentionally heuristic. They nudge code toward Funx DSLs when
  the local shape is a good fit, while avoiding common false positives such as
  fallback control flow, loose external maps, string classifiers, and predicates
  with collection or IO-heavy logic.
  """
end
