defmodule Progress.CurWin do
  def make() do
    :none
  end

  def work(:none, x), do: x
  def work(x, :none), do: x
  def work(_, x),     do: x

  def idle?(:none),   do: true
  def idle?(_),       do: false

  def string(:none),  do: "0"
  def string(:small), do: "/"
  def string(:big),   do: "X"
end
