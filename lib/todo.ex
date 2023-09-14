defmodule Todo do
  defstruct [
    :label,
    children: [],
    done?: false
  ]

  def mark_done(%Todo{} = x) do
    %{x | done?: true}
  end
  def mark_done([head | tail]) do
    [mark_done(head) | tail]
  end
  def mark_done([]), do: []

  def pop_children([head | tail]) do
    head.children ++ [%Todo{head | children: []}] ++ tail
  end
  def pop_children([]), do: []

  def add_to_top(parent, child) do
    [child | parent]
  end

  def add_to_bottom(parent, child) do
    parent ++ [child]
  end
end
