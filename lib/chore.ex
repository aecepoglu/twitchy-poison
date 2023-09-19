defmodule Chore do
  use Agent

  defstruct [:label]
  def make(label), do: %__MODULE__{label: label}

  def start_link(_) do
    list = [
      Chore.make("chore 1"),
      Chore.make("chore 2"),
      Chore.make("chore 3"),
    ]
    Agent.start_link(fn -> list end, name: __MODULE__)
  end

  def put_lines(lines) do
    chores = Enum.map(lines, &deserialise/1)
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

  defp serialize(x), do: x.label
  defp deserialise(x), do: %Chore{label: x}
end
