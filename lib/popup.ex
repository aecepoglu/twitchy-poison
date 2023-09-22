defmodule String.Wrap do
  def wrap_at(text, width) do
    aux(text, width, [])
  end

  defp aux(text, width, lines) do
    case String.split_at(text, width) do
      {left, ""}    -> [left | lines] |> Enum.reverse
      {left, right} -> aux(right, width, [left | lines])
    end
  end
end

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
    lines
    |> Enum.flat_map(& String.Wrap.wrap_at(&1, width))
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

defmodule Popup do
  defstruct [:label, :actions]

  def make(%Alarm{}=alarm, actions: actions), do: %Popup{
    label: alarm.label,
    actions: actions
  }

  def render(popup, {width, height}) do
    {p_width, p_height} = {80, 5}
    scroll = 0
    x0 = (width - p_width) / 2   |> max(0) |> floor
    y0 = (height - p_height) / 2 |> max(0) |> floor

    actions = popup.actions
    |> Enum.with_index(fn {name, _}, i -> "(#{i + 1}. #{name})" end)
    |> Enum.join(" ")

    body = [
      "#{width}x#{height}," <> popup.label,
      "",
      actions
    ]
    |> Bordered.rows(p_width)
    |> Bordered.panel(scroll, p_height)

    body
    |> Enum.with_index( fn txt, i -> IO.ANSI.cursor(y0 + i, x0) <> txt end)
    |> Enum.join
    |> IO.puts
  end

  # TODO this can be entirely dynamic
  def act(%Popup{actions: actions}, action, model0) do
    i = case action do
      :action_1 -> 0
      :action_2 -> 1
      :escape -> 2
    end
    Enum.at(actions, i)
    |> elem(1)
    |> Enum.reduce(model0, fn f, model -> f.(model) end)
  end
end
