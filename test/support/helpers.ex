defmodule LiveSelect.TestHelpers do
  @moduledoc false

  use LiveSelectWeb.ConnCase, async: true

  @default_style :tailwind
  def default_style(), do: @default_style

  @expected_class [
    daisyui: [
      active_option: ~S(active),
      available_option: ~S(cursor-pointer),
      clear_button: ~S(hidden cursor-pointer),
      clear_tag_button: ~S(cursor-pointer),
      container: ~S(dropdown dropdown-open),
      dropdown:
        ~S(dropdown-content z-[1] menu menu-compact shadow rounded-box bg-base-200 p-1 w-full),
      selected_option: ~S(disabled),
      tag: ~S(p-1.5 text-sm badge badge-primary),
      tags_container: ~S(flex flex-wrap gap-1 p-1),
      text_input: ~S(input input-bordered w-full pr-6),
      text_input_selected: ~S(input-primary)
    ],
    tailwind: [
      active_option: ~S(text-white bg-gray-600),
      available_option: ~S(cursor-pointer hover:bg-gray-400 rounded),
      clear_button: ~S(hidden cursor-pointer),
      clear_tag_button: ~S(cursor-pointer),
      container: ~S(h-full text-black relative),
      dropdown: ~S(absolute rounded-md shadow z-50 bg-gray-100 inset-x-0 top-full),
      option: ~S(rounded px-4 py-1),
      selected_option: ~S(text-gray-400),
      tag: ~S(p-1 text-sm rounded-lg bg-blue-400 flex),
      tags_container: ~S(flex flex-wrap gap-1 p-1),
      text_input:
        ~S(rounded-md w-full disabled:bg-gray-100 disabled:placeholder:text-gray-400 disabled:text-gray-400 pr-6),
      text_input_selected: ~S(border-gray-600 text-gray-600)
    ]
  ]
  def expected_class(), do: @expected_class

  @override_class_option [
    available_option: :available_option_class,
    clear_button: :clear_button_class,
    clear_tag_button: :clear_tag_button_class,
    container: :container_class,
    dropdown: :dropdown_class,
    option: :option_class,
    selected_option: :selected_option_class,
    tag: :tag_class,
    tags_container: :tags_container_class,
    text_input: :text_input_class
  ]
  def override_class_option, do: @override_class_option

  @extend_class_option [
    clear_button: :clear_button_extra_class,
    clear_tag_button: :clear_tag_button_extra_class,
    container: :container_extra_class,
    dropdown: :dropdown_extra_class,
    option: :option_extra_class,
    tag: :tag_extra_class,
    tags_container: :tags_container_extra_class,
    text_input: :text_input_extra_class
  ]
  def extend_class_option(), do: @extend_class_option

  @selectors [
    container: "div[phx-hook=LiveSelect]",
    clear_button: "button[phx-click=clear]",
    clear_tag_button: "div[phx-hook=LiveSelect] > div:first-child > div > button",
    dropdown: "div[phx-hook=LiveSelect] > ul",
    dropdown_entries: "div[phx-hook=LiveSelect] > ul > li > div",
    hidden_input: "input#my_form_city_search",
    option: "div[phx-hook=LiveSelect] > ul > li > div",
    tags_container: "div[phx-hook=LiveSelect] > div:first-child",
    tag: "div[phx-hook=LiveSelect] > div:first-child > div",
    text_input: "input#my_form_city_search_text_input"
  ]
  def selectors(), do: @selectors

  @component_id "my_form_city_search_live_select_component"

  defmacro refute_push_event(view, event, payload, timeout \\ 100) do
    quote do
      %{proxy: {ref, _topic, _}} = unquote(view)

      refute_receive {^ref, {:push_event, unquote(event), unquote(payload)}}, unquote(timeout)
    end
  end

  def select_nth_option(live, n, opts \\ []) do
    opts =
      Keyword.validate!(opts,
        method: :key,
        component: @selectors[:container],
        flunk_if_not_selectable: true
      )

    component = Keyword.fetch!(opts, :component)
    {flunk_if_not_selectable, opts} = Keyword.pop(opts, :flunk_if_not_selectable)
    {method, opts} = Keyword.pop(opts, :method)

    case method do
      :key ->
        navigate(live, n, :down, opts)
        keydown(live, "Enter", opts)

      :click ->
        option_selector = "#{component} li > div[data-idx=#{n - 1}]"

        cond do
          has_element?(live, option_selector) ->
            element(live, component)
            |> render_hook("option_click", %{idx: to_string(n - 1)})

          flunk_if_not_selectable ->
            flunk("could not find element: #{option_selector}")

          true ->
            :not_selectable
        end
    end
  end

  def unselect_nth_option(live, n) do
    selector = "#{@selectors[:tags_container]} button[data-idx=#{n - 1}]"

    if has_element?(live, selector) do
      element(live, @selectors[:container])
      |> render_hook("option_remove", %{idx: to_string(n - 1)})
    else
      flunk("could not find element: #{selector}")
    end
  end

  def keydown(live, key, opts \\ []) do
    opts = Keyword.validate!(opts, component: @selectors[:container])

    component = Keyword.fetch!(opts, :component)

    element(live, component)
    |> render_hook("keydown", %{"key" => key})
  end

  def dropdown_visible(live), do: has_element?(live, @selectors[:dropdown])

  def stub_options(options, opts \\ []) do
    Mox.stub(LiveSelect.ChangeEventHandlerMock, :handle, fn params, _ ->
      unless opts[:delay_forever] do
        send(
          self(),
          {:update_live_select, params, options}
        )
      end
    end)

    :ok
  end

  def assert_option_size(live, size) when is_integer(size) do
    assert_option_size(live, &(&1 == size))
  end

  def assert_option_size(live, fun) when is_function(fun, 1) do
    assert render(live)
           |> Floki.parse_document!()
           |> Floki.find(@selectors[:dropdown_entries])
           |> Enum.count()
           |> then(&fun.(&1))
  end

  def type(live, text, opts \\ []) do
    opts =
      Keyword.validate!(opts, update_min_len: 3, component: @selectors[:container], parent: live)

    update_min_len = Keyword.fetch!(opts, :update_min_len)
    component = Keyword.fetch!(opts, :component)
    parent = Keyword.fetch!(opts, :parent)

    text = String.trim(text)

    if String.length(text) >= update_min_len do
      element(live, component)
      |> render_hook("change", %{
        text: text
      })

      parent =
        case parent do
          %Phoenix.LiveViewTest.View{} -> parent
          selector -> element(live, selector)
        end

      component_id =
        element(live, component)
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.attribute("id")
        |> hd()

      parent
      |> render_hook("live_select_change", %{
        text: text,
        id: component_id,
        field: "city_search"
      })
    else
      element(live, component)
      |> render_hook("options_clear", %{})
    end
  end

  def assert_options(rendered, elements) when is_binary(rendered) do
    assert rendered
           |> Floki.parse_document!()
           |> Floki.find(@selectors[:dropdown_entries])
           |> Floki.text()
           |> String.replace(~r/\s+/, ",")
           |> String.trim(",")
           |> String.split(",")
           |> Enum.reject(&(&1 == ""))
           |> Enum.sort() == elements |> Enum.map(&to_string/1) |> Enum.sort()
  end

  def assert_options(live, elements), do: assert_options(render(live), elements)

  def assert_option_active(live, pos, active_class \\ "active")

  def assert_option_active(_live, _pos, "") do
    assert true
  end

  def assert_option_active(live, pos, active_class) do
    element_classes =
      render(live)
      |> Floki.parse_document!()
      |> Floki.attribute(@selectors[:dropdown_entries], "class")
      |> Enum.map(&String.trim/1)

    assert length(element_classes) >= pos

    for {element_class, idx} <- Enum.with_index(element_classes, 1) do
      if idx == pos do
        assert String.contains?(element_class, active_class)
      else
        refute String.contains?(element_class, active_class)
      end
    end
  end

  def assert_selected(live, label, value \\ nil) do
    {label, value} = assert_selected_static(live, label, value)

    assert_push_event(live, "select", %{
      id: @component_id,
      selection: [%{label: ^label, value: ^value}],
      input_event: true,
      mode: :single
    })
  end

  def assert_selected_static(html, label, value \\ nil)

  def assert_selected_static(html, label, value) when is_binary(html) do
    value = if value, do: value, else: label

    assert Floki.attribute(html, @selectors[:hidden_input], "value") == [encode_value(value)]

    text_input = Floki.find(html, @selectors[:text_input])

    assert Floki.attribute(text_input, "readonly") ==
             ["readonly"]

    assert Floki.attribute(text_input, "value") ==
             [to_string(label)]

    {label, value}
  end

  def assert_selected_static(live, label, value),
    do: assert_selected_static(render(live), label, value)

  def refute_selected(live) do
    hidden_input =
      live
      |> element(@selectors[:hidden_input])
      |> render()
      |> Floki.parse_fragment!()

    assert hidden_input
           |> Floki.attribute("value") ==
             []

    text_input =
      live
      |> element(@selectors[:text_input])
      |> render()
      |> Floki.parse_fragment!()

    assert text_input
           |> Floki.attribute("readonly") ==
             []
  end

  def normalize_selection(selection) do
    for element <- selection do
      if is_binary(element) || is_integer(element) || is_atom(element) do
        %{value: element, label: element}
      else
        element
      end
    end
  end

  def assert_selected_multiple_static(html, selection) when is_binary(html) do
    normalized_selection = normalize_selection(selection)

    {values, tag_labels} =
      normalized_selection
      |> Enum.map(&{&1[:value], &1[:tag_label] || &1[:label]})
      |> Enum.unzip()

    assert Floki.attribute(html, "#{@selectors[:container]} input[type=hidden]", "value") ==
             encode_values(values)

    assert html
           |> Floki.find(@selectors[:tag])
           |> Floki.text(sep: ",")
           |> String.split(",")
           |> Enum.reject(&(&1 == ""))
           |> Enum.map(&String.trim/1) ==
             tag_labels

    normalized_selection
  end

  def assert_selected_multiple_static(live, selection) do
    assert_selected_multiple_static(render(live), selection)
  end

  def assert_selected_multiple(live, selection) do
    normalized_selection = assert_selected_multiple_static(live, selection)

    assert_push_event(live, "select", %{
      id: @component_id,
      selection: ^normalized_selection
    })
  end

  def assert_selected_option_class(_live, _selected_pos, ""), do: true

  def assert_selected_option_class(html, selected_pos, selected_class) when is_binary(html) do
    element_classes =
      html
      |> Floki.attribute("ul[name=live-select-dropdown] > li", "class")
      |> Enum.map(&String.trim/1)

    # ensure we're checking both selected and unselected elements
    assert length(element_classes) > selected_pos || selected_pos > 1

    for {element_class, idx} <- Enum.with_index(element_classes, 1) do
      if idx == selected_pos do
        assert String.contains?(element_class, selected_class)
      else
        refute String.contains?(element_class, selected_class)
      end
    end
  end

  def assert_available_option_class(_live, _selected_pos, ""), do: true

  def assert_available_option_class(html, selected_pos, available_class) when is_binary(html) do
    element_classes =
      html
      |> Floki.attribute("ul[name=live-select-dropdown] > li", "class")
      |> Enum.map(&String.trim/1)

    # ensure we're checking both selected and unselected elements
    assert length(element_classes) > selected_pos || selected_pos > 1

    for {element_class, idx} <- Enum.with_index(element_classes, 1) do
      if idx == selected_pos do
        refute String.contains?(element_class, available_class)
      else
        assert String.contains?(element_class, available_class)
      end
    end
  end

  def assert_clear(live, input_event \\ true) do
    assert_clear_static(live)

    assert_push_event(live, "select", %{
      id: @component_id,
      selection: [],
      input_event: ^input_event
    })
  end

  def assert_clear_static(live) do
    assert live
           |> element(@selectors[:text_input])
           |> render()
           |> Floki.parse_fragment!()
           |> Floki.attribute("readonly") ==
             []

    assert live
           |> element(@selectors[:hidden_input])
           |> render()
           |> Floki.parse_fragment!()
           |> Floki.attribute("value") == []
  end

  def assert_option_removeable(live, n) do
    selector = "#{@selectors[:tags_container]} button[data-idx=#{n - 1}]"

    assert has_element?(live, selector)
  end

  def refute_option_removeable(live, n) do
    selector = "#{@selectors[:tags_container]} button[data-idx=#{n - 1}]"

    refute has_element?(live, selector)
  end

  def navigate(live, n, dir, opts \\ []) do
    key =
      case dir do
        :down -> "ArrowDown"
        :up -> "ArrowUp"
      end

    for _ <- 1..n do
      keydown(live, key, opts)
    end
  end

  def send_update(live, assigns) do
    Phoenix.LiveView.send_update(
      live.pid,
      LiveSelect.Component,
      Keyword.merge(assigns, id: @component_id)
    )
  end

  defp encode_values(values) when is_list(values) do
    for value <- values, do: encode_value(value)
  end

  defp encode_value(value) when is_binary(value), do: value

  defp encode_value(value) when is_number(value) or is_atom(value), do: to_string(value)

  defp encode_value(value), do: Jason.encode!(value)
end
