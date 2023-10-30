defmodule Input.Keyboard do
  def report("z"), do: Hub.tick()
  def report("r"), do: Hub.refresh()

  def report("h"), do: Hub.cast({:key, :left});
  def report("t"), do: Hub.cast({:key, :down});
  def report("n"), do: Hub.cast({:key, :up});
  def report("s"), do: Hub.cast({:key, :right});

  def report("escape"), do: Hub.cast({:key, :escape})
  def report("return"), do: Hub.cast({:key, :return})
  def report("space"),  do: Hub.cast({:key, :space})

  def report(k), do: Hub.cast({:key, k})
end
