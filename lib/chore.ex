defmodule Chore do
  use Agent

  defstruct [:label, :category, :duration]
  def make(duration, category, label), do: %__MODULE__{
    duration: duration,
    category: category,
    label: label,
  }

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def put(chores) do
    Agent.update(__MODULE__, fn _ -> chores end)
  end
  def get_lines() do
    get()
    |> Enum.map(&serialize/1)
  end

  def get(), do: Agent.get(__MODULE__, & &1)
  def add(x), do: Agent.update(__MODULE__, & [x | &1])
  def pop() do
    f = fn list ->
      case list do
        [h | t] -> {h, t}
        [] -> {nil, []}
      end
    end
    Agent.get_and_update(__MODULE__, f)
  end

  defp serialize(%Chore{}=x), do: "#{x.duration} #{x.category} #{x.label}"
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
end
