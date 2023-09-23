defmodule CircBuf do
  defstruct [
    :size,
    idx: 0,
    buf: %{}
  ]

  def make(n, fill) do
    %__MODULE__{size: n, buf: Map.new(0..(n - 1), &{&1, fill})}
  end

  def add(%__MODULE__{} = cb, val) do
    %{cb | idx: rem(cb.idx + 1, cb.size), buf: %{cb.buf | cb.idx => val}}
  end

  def take(%__MODULE__{} = cb, n) do
    1..n
    |> Enum.map(fn x -> cb.buf[Integer.mod(cb.idx - x, cb.size)] end)
  end

  def count_while(%__MODULE__{}=cb, f) do
    reduce_while(cb, 0, 0,
      fn x, acc ->
        if f.(x) do
          {:continue, acc + 1}
        else
          false
        end
      end
    )
  end

  defp reduce_while(cb, i, acc, _) when i == cb.size, do: acc
  defp reduce_while(cb, i, acc, f) do
    x = at(cb, i)
    case f.(x, acc) do
      {:continue, y} -> reduce_while(cb, i + 1, y, f)
      _ -> acc
    end
  end

  defp at(cb, i), do: cb.buf[Integer.mod(cb.idx - i, cb.size)]

  def to_list(%__MODULE__{}=cb) do
    cb.buf
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {Integer.mod(cb.idx - k - 1, cb.size), v} end)
    |> Enum.sort_by(& elem(&1, 0))
    |> Enum.map(& elem(&1, 1))
  end
end
