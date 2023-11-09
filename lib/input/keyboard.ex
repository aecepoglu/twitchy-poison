defmodule Input.Keyboard do
  def report("z"), do: Hub.tick()
  def report("r"), do: Hub.refresh()

  def report("escape"), do: Hub.cast({:key, :escape})
  def report("return"), do: Hub.cast({:key, :return})
  def report("space"),  do: Hub.cast({:key, :space})

  def report(k), do: Hub.cast({:key, k})
end
