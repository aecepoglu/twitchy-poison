defmodule Popup do
  defstruct [:label, :actions]

  def make(%Alarm{}=alarm, actions \\ []), do: %Popup{
    label: alarm.label,
    actions: actions
  }

  # TODO this function is a bit too long for my liking
  def render(popup) do
    {:ok, width} = :io.columns()
    {:ok, height} = :io.rows()
    p_width = 80

    actions = popup.actions
    |> Enum.with_index(fn _, i -> "(#{i + 1}. action)" end) #TODO button label
    |> Enum.join(" ")

    body = [
      "",
      popup.label,
      "",
      actions <> " (2. close & delete)" #TODO
    ] |> Enum.map(fn txt -> "# " <> string_take(txt, p_width - 4) <> " #" end)

    p_height = length(body) + 2
    x0 = (width - p_width) / 2   |> max(0) |> floor
    y0 = (height - p_height) / 2 |> max(0) |> floor
    hor_border  = 1..p_width |> Enum.map(fn _ -> '#' end) |> to_string
    # TODO fold lines to fit the panel

    [hor_border] ++ body ++ [hor_border]
    |> Enum.with_index(fn txt, i -> IO.ANSI.cursor(y0 + i, x0) <> IO.ANSI.clear_line <> txt end)
    |> Enum.join
    |> IO.puts
  end

  defp string_take(str, n) do
    k = String.length(str)
    if k > n do
      {left, _} = String.split_at(str, n)
      left
    else
      pad_right = 1..(n - k) |> Enum.map(fn _ -> ' ' end) |> to_string
      str <> pad_right
    end
  end

  # TODO this can be entirely dynamic
  def act(%Popup{actions: [f]}, :action_1, model) do
    f.(model)
  end
end
