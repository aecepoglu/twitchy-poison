defmodule Geometry do
  def hor_line(width, c) do
    1..width
    |> Enum.map(fn _ -> c end)
    |> to_string
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

defmodule Popup do
  defstruct [:id, :label, actions: %{}, snooze: 0]

  def make(id, label, opts \\ []) do
    %Popup{
      id: id,
      label: label,
      snooze: Keyword.get(opts, :snooze, 0),
      actions: default_actions(),
    }
    |> set_actions()
  end

  def default_actions(), do: %{
    {:key, "d"}     => {"delete", [&Popup.Actions.delete/2]},
    {:key, :escape} => {"rotate",  [&Popup.Actions.rotate/2]},
  }

  def set_actions(%__MODULE__{snooze: t, actions: aa}=popup) when t > 0 do
    x = %{{:key, "s"} => {"snooze #{t}'",  [&Popup.Actions.delete/2, &Popup.Actions.snooze/2]}}
    %{popup | actions: Map.merge(aa, x)}
  end
  def set_actions(%__MODULE__{}=popup), do: popup

  def render(%Popup{}=popup, {width, height}, remaining) do
    {p_width, p_height} = {min(80, floor(width * 0.8)), 5}
    scroll = 0
    x0 = (width - p_width) / 2   |> max(0) |> floor
    y0 = (height - p_height) / 2 |> max(0) |> floor

    actions = popup.actions
    |> Map.to_list
    |> Enum.map(fn {{:key, key}, {name, _}} -> "(#{key} => #{name})" end)
    |> Enum.join(" ")

    body = [
      popup.label,
      "",
      actions
    ] ++ (if remaining > 0 do ["#{remaining} more popups to view..."] else [] end)
    |> Bordered.rows(p_width)
    |> Bordered.panel(scroll, p_height)

    body
    |> Enum.with_index( fn txt, i -> IO.ANSI.cursor(y0 + i, x0) <> txt end)
    |> Enum.join
  end

  def update(%Popup{actions: actions}=popup, action, model0) do
    case Map.fetch(actions, action) do
      {:ok, {_, funs}} -> Enum.reduce(funs, model0, fn f, model -> f.(model, popup) end)
      _ -> model0
    end
  end

end

defmodule Popup.List do
  def new_id?(_, nil), do: true
  def new_id?([], _), do: true
  def new_id?(ids, id), do: !MapSet.member?(ids, id)

  def has_id?(list, id), do: Enum.any?(list, & &1.id == id)

  def ids(list), do: list |> Enum.map(& &1.id) |> MapSet.new()

  def delete(list, nil), do: list
  def delete(list, id) when is_atom(id) do
    Enum.filter(list, fn %Popup{id: x} -> id == x end)
  end
end
