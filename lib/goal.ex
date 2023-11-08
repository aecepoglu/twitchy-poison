defmodule Goal do
  def empty(), do: nil
  def set(_old, new), do: new

  def empty?(nil), do: true
  def empty?(_),   do: false

  def render(nil, _), do: {1, "-"}
  def render(str, {width, height}) do
    lines = String.Wrap.wrap(str, width)
    |> Enum.take(height) # TODO fix
    |> Enum.map(fn x -> IO.ANSI.clear_line <> x end)

    {length(lines), Enum.join(lines, "\n\r")}
  end
end
