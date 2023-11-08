defmodule Todo.Parser do
  def parse(txt) do
    {done, rest} =  case txt do
      "x " <> k -> {true, k}
      "  " <> k -> {false, k}
      k         -> {false, k}
    end

    found = String.split(rest)
    |> Enum.map(&categorise/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    label = Map.get(found, :label, []) |> Enum.join(" ")
    defaults = %Todo{
      label: "",
      done: done,
    }

    defaults
    |> Map.merge(found)
    |> Map.merge(%{label: label})
  end
  defp categorise("todobqn:" <> key), do: {:hook, {:todobqn, key}}
  defp categorise(x), do: {:label, x}
end
