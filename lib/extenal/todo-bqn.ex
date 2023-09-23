defmodule External.TodoBqn do
  @prog "todo.bqn"

  def get_id( {id, _}), do: id
  def get_txt({_, txt}), do: txt
  def ids(list), do: Enum.map(list, &get_id/1)

  def add(txt) do
    {_, 0} = System.cmd(@prog, ["add", txt])
  end
  def search(keywords) do
    {data, 0} = System.cmd(@prog, ["list" | keywords])
    data
  end
  def complete(ids, :ids) do
    {_, 0} = System.cmd(
      @prog,
      ["do" | Enum.map(ids, &to_string/1)])
  end
  def complete(kws, :keywords) do
    search(kws)
    |> parse_list
    |> Enum.map(&get_id/1)
    |> complete(:ids)
  end

  defp parse_list(response) do
    response
    |> String.split("\n")
    |> Enum.map(fn x ->
        [hd | tl] = String.split(x, "\t")
        {hd, Enum.join(tl, "\t")}
      end)
  end
end
