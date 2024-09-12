# credo:disable-for-this-file
defmodule Mix.Tasks.DumpStyleTable do
  @shortdoc "dump the table with the default styles used in the docs"

  use Mix.Task

  @impl true
  def run(_) do
    LiveSelect.Component.styles()
    |> Enum.map(fn {style, styles} ->
      Enum.map(styles, fn {el, class} -> {el, style, class} end)
    end)
    |> List.flatten()
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {el, list} -> {el, Enum.map(list, &Tuple.delete_at(&1, 0)) |> Enum.sort()} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.with_index()
    |> Enum.map(fn {{el, styles}, idx} ->
      header =
        if idx == 0 do
          "| Element | " <>
            (Keyword.keys(styles) |> Enum.map_join(" | ", &"Default #{&1} classes")) <>
            " | Class override option | Class extend option |\n" <>
            "|----|" <>
            (Keyword.keys(styles) |> Enum.map_join("|", fn _ -> "----" end)) <> "|----|----|\n"
        else
          ""
        end

      header <>
        "| *#{el}* | " <>
        (Keyword.values(styles) |> Enum.map_join(" | ", &format_styles(&1))) <>
        " | #{class_override_option(el)} | #{class_extend_option(el)} |\n"
    end)
    |> IO.write()
  end

  defp class_override_option(el) do
    option_name = to_string(el) <> "_class"
    if option_name in class_options(), do: option_name, else: ""
  end

  defp class_extend_option(el) do
    option_name = to_string(el) <> "_extra_class"
    if option_name in class_options(), do: option_name, else: ""
  end

  defp class_options(),
    do: Enum.map(LiveSelect.Component.default_opts() |> Keyword.keys(), &to_string/1)

  defp format_styles(nil), do: ""

  defp format_styles(styles) do
    styles
    |> Enum.sort()
    |> Enum.join(" ")
  end
end
