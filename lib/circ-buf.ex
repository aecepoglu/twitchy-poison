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
end
