defmodule TodoTest do
  use ExUnit.Case
  import Todo
  test "string" do
    right = empty()
    |> add(%Todo{label: "1"})
    |> add(%Todo{label: "2"})
    |> del
    |> add(%Todo{label: "3"})
    |> mark_done
    |> strings

    left = [
      "  [x] 3",
      "  [ ] 1"
    ]

    assert left == right
  end

  test "long lines fold" do
    right = empty()
    |> add(%Todo{label: "hii"})
    |> add(%Todo{label: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen"})
    |> add(%Todo{label: "bye"})
    |> join
    |> add(%Todo{label: "ungrouped"})
    |> strings

    left = [
      "  [ ] ungrouped",
      "╭ [ ] bye",
      "│ [ ] one two three four five six seven ",
      "│     eight nine ten eleven twelve thirt",
      "│     een fourteen fifteen sixteen seven",
      "╰     teen",
      "  [ ] hii",
    ]
    assert left == right
  end
end
