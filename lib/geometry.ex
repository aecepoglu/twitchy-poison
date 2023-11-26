defmodule Geometry do
  def hor_line(width, c) do
    1..width
    |> Enum.map(fn _ -> c end)
    |> to_string
  end
end
