defmodule Chore do
  use Agent

  defstruct [:label, :category, :duration]
  def make(duration, category, label), do: %__MODULE__{
    duration: duration,
    category: category,
    label: label,
  }

  def empty(), do: []
  def rotate([h | t]), do: t ++ [h]
  def retate([]), do: []

  def serialise(list) when is_list(list), do: Enum.map(list, &serialise/1)
  def serialise(%Chore{}=x), do: "#{x.duration} #{x.category} #{x.label}"
  def deserialise(line) when is_binary(line) do
    with [dur_str, cat, word | words] <- String.split(line, " "),
         {dur, _} <- Integer.parse(dur_str) do
      %Chore{
        label: [word | words] |> Enum.join(" "),
        duration: dur,
        category: cat,
      }
    end
  end

  def string(%Chore{label: l}), do: l
  def string(nil), do: "-"
end
