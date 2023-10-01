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
  def remove(%__MODULE__{} = cb) do
    %{cb | idx: rem(cb.idx - 1, cb.size)}
  end

  def take(%__MODULE__{} = cb, n) do
    Enum.map(1..n, &at(cb, &1))
  end

  def scan_bi(%__MODULE__{} = cb, acc, f) do
    scan_bi_(cb, 1, acc, f)
  end
  defp scan_bi_(%__MODULE__{size: n}=cb, i, _, _) when i > n, do: cb
  defp scan_bi_(%__MODULE__{}=cb, i, acc, f) do
    {x_, acc_} = f.(at(cb, i), acc)
    scan_bi_(put(cb, i, x_), i + 1, acc_, f)
  end

  def count_while(%__MODULE__{}=cb, f) do
    reduce_while(cb, 0,
      fn x, acc ->
        if f.(x) do
          {:continue, acc + 1}
        else
          false
        end
      end
    )
  end

  def reduce_while(cb, acc, f), do: reduce_while_(cb, 1, acc, f)
  def reduce_while(cb, acc, [skip: skip], f), do: reduce_while_(cb, skip + 1, acc, f)
  defp reduce_while_(cb, i, acc, _) when i == cb.size, do: acc
  defp reduce_while_(cb, i, acc, f) do
    x = at(cb, i)
    case f.(x, acc) do
      {:continue, y} -> reduce_while_(cb, i + 1, y, f)
      _ -> acc
    end
  end

  def to_list(%__MODULE__{}=cb) do
    cb.buf
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {Integer.mod(cb.idx - k - 1, cb.size), v} end)
    |> Enum.sort_by(& elem(&1, 0))
    |> Enum.map(& elem(&1, 1))
  end

  defp at(cb, i), do: cb.buf[Integer.mod(cb.idx - i, cb.size)]
  defp put(cb, i, v) do
    j = Integer.mod(cb.idx - i, cb.size)
    Map.update!(cb, :buf, & Map.put(&1, j, v))
  end
end
