defmodule Util.UnlimitedArithmetic do
  @moduledoc "for counting numbers (0 and Z+) only"
  def subtract(:infinity, _), do: :infinity
  def subtract(a, b) when a >= b, do: a - b
  def subtract(_, _), do: 0

  def add(:infinity, _), do: :infinity
  def add(a, b), do: a + b

  def positive?(0), do: false
  def positive?(_), do: true

  def str(:infinity), do: "∞"
  def str(n), do: "#{n}"
end
