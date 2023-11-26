defmodule Bordered do
  defp fill(txt, width, fill) do
    k = String.length(txt)
    if k < width do
      pad = (k+1)..width
      |> Enum.map(fn _ -> fill end)
      |> to_string
      txt <> pad
      else
        String.split_at(txt, width)
        |> elem(0)
      end
  end

  defp row(left, right, content, width, filler) do
    left <> fill(content, width, filler) <> right
  end

  def rows(lines, width) do
    String.Wrap.wrap_lines(lines, width)
    |> Enum.map(& row("▌", "│", &1, width, " "))
  end

  def panel([first|_]=lines, scroll, height) do
    selected = lines
    |> Enum.drop(scroll)
    |> Enum.take(height)
    w = String.length(first)
    top =   row("┌", "┐", "", w - 2, "─")
    bot = [ row("▙", "┘", "", w - 2, "▄"), ]
    [top | selected] ++ bot
  end
end
