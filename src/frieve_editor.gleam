import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event

pub type Tab {
  Browser
  Editor
  Drawing
  Statistics
}

pub type Card {
  Card(
    id: String,
    title: String,
    body: String,
    x: Int,
    y: Int,
    w: Int,
    h: Int,
    labels: List(String),
    color: String,
  )
}

pub type Link {
  Link(from: String, to: String, label: String)
}

pub type Model {
  Model(
    title: String,
    subtitle: String,
    active_tab: Tab,
    search: String,
    label_filter: String,
    link_mode: Bool,
    selected_card_id: String,
    cards: List(Card),
    links: List(Link),
  )
}

pub type Msg {
  SetTab(Tab)
  SearchChanged(String)
  LabelFilterChanged(String)
  SelectCard(String)
  UpdateSelectedTitle(String)
  UpdateSelectedBody(String)
  UpdateSelectedLabels(String)
  NewCard
  DuplicateCard
  DeleteCard
  ToggleLinkMode
  ClearFilters
}

pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) -> Model {
  Model(
    title: "Frieve Editor",
    subtitle: "Lustre-based graph editor scaffold",
    active_tab: Browser,
    search: "",
    label_filter: "",
    link_mode: False,
    selected_card_id: "root",
    cards: [
      Card("root", "Frieve Editor", "A spatial note workspace for cards and links.", 690, 90, 300, 128, ["Core", "Start"], "#f2c66d"),
      Card("browser", "Browser", "Search and jump across the note graph.", 300, 300, 250, 120, ["Navigation", "Search"], "#67d4ff"),
      Card("editor", "Editor", "Edit card content and relationships in place.", 610, 300, 250, 120, ["Editing", "Cards"], "#9dff83"),
      Card("drawing", "Drawing", "Spatial layout for visual thinking.", 920, 300, 250, 120, ["Canvas", "Layout"], "#ff8f7b"),
      Card("statistics", "Statistics", "Inspect graph density and label spread.", 1230, 300, 250, 120, ["Metrics"], "#c98dff"),
      Card("note", "Note Card", "Cards are atomic units of thought.", 360, 610, 230, 108, ["Content"], "#58e1a9"),
      Card("link", "Link Graph", "Links capture reference and flow.", 650, 610, 230, 108, ["Relations"], "#6fa8ff"),
      Card("export", "Export", "Persist the document as JSON or files.", 940, 610, 230, 108, ["Sharing", "Output"], "#ffb35d"),
      Card("focus", "Focus Mode", "Highlight the active branch.", 1230, 610, 230, 108, ["View"], "#7bdaff"),
      Card("labels", "Labels", "Tag cards to group concepts.", 505, 840, 220, 100, ["Tagging"], "#f2c66d"),
      Card("workflow", "Workflow", "Browser, Editor, Drawing, Statistics.", 805, 840, 220, 100, ["Modes"], "#ff8f7b"),
      Card("journal", "Journal", "Record long-form notes on the map.", 1105, 840, 220, 100, ["Notes"], "#9dff83"),
    ],
    links: [
      Link("root", "browser", "navigate"),
      Link("root", "editor", "edit"),
      Link("root", "drawing", "draw"),
      Link("root", "statistics", "inspect"),
      Link("editor", "note", "cards"),
      Link("editor", "link", "relations"),
      Link("drawing", "export", "save"),
      Link("statistics", "focus", "focus"),
      Link("labels", "workflow", "organize"),
      Link("workflow", "journal", "record"),
    ],
  )
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SetTab(tab) -> Model(..model, active_tab: tab)
    SearchChanged(search) -> Model(..model, search: search)
    LabelFilterChanged(label) -> Model(
      ..model,
      label_filter: toggle_filter(model.label_filter, label),
      search: "",
    )
    SelectCard(id) -> select_card(model, id)
    UpdateSelectedTitle(title) -> edit_selected(model, fn(card) { Card(..card, title: title) })
    UpdateSelectedBody(body) -> edit_selected(model, fn(card) { Card(..card, body: body) })
    UpdateSelectedLabels(labels) -> edit_selected(model, fn(card) {
      Card(..card, labels: parse_labels(labels))
    })
    NewCard -> create_card(model)
    DuplicateCard -> duplicate_card(model)
    DeleteCard -> delete_card(model)
    ToggleLinkMode -> Model(..model, link_mode: !model.link_mode)
    ClearFilters -> Model(..model, search: "", label_filter: "")
  }
}

fn select_card(model: Model, id: String) -> Model {
  case model.link_mode {
    True if model.selected_card_id != id -> add_link(model, id)
    _ -> Model(..model, selected_card_id: id, link_mode: False)
  }
}

fn create_card(model: Model) -> Model {
  let base = selected_card(model)
  let id = next_card_id(model.cards)
  let card = Card(
    id,
    "New Card",
    "Write a new thought here.",
    base.x + 38,
    base.y + 38,
    240,
    108,
    ["Draft"],
    "#8be9fd",
  )

  Model(..model, cards: [card, ..model.cards], selected_card_id: id, link_mode: False)
}

fn duplicate_card(model: Model) -> Model {
  let card = selected_card(model)
  let id = next_card_id(model.cards)
  let copy = Card(
    id,
    card.title <> " Copy",
    card.body,
    card.x + 24,
    card.y + 24,
    card.w,
    card.h,
    card.labels,
    card.color,
  )

  Model(..model, cards: [copy, ..model.cards], selected_card_id: id, link_mode: False)
}

fn delete_card(model: Model) -> Model {
  case model.cards {
    [] -> model
    [_] -> model
    _ -> {
      let id = model.selected_card_id
      let cards = list.filter(model.cards, fn(card) { card.id != id })
      let links =
        list.filter(model.links, fn(link) {
          link.from != id && link.to != id
        })
      let selected = first_card(cards).id

      Model(..model, cards: cards, links: links, selected_card_id: selected, link_mode: False)
    }
  }
}

fn add_link(model: Model, target_id: String) -> Model {
  let source_id = model.selected_card_id
  case source_id == target_id || link_exists(model.links, source_id, target_id) {
    True -> Model(..model, link_mode: False)
    False -> Model(
      ..model,
      links: [Link(source_id, target_id, "link"), ..model.links],
      link_mode: False,
    )
  }
}

fn edit_selected(model: Model, change: fn(Card) -> Card) -> Model {
  let id = model.selected_card_id
  let cards = list.map(model.cards, fn(card) {
    case card.id == id {
      True -> change(card)
      False -> card
    }
  })

  Model(..model, cards: cards)
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("shell")], [
    topbar(model),
    html.div([attribute.class("workspace")], [
      browser_panel(model),
      canvas_panel(model),
      inspector_panel(model),
    ]),
    statusbar(model),
  ])
}

fn topbar(model: Model) -> Element(Msg) {
  html.div([attribute.class("topbar")], [
    html.div([attribute.class("brand")], [
      html.h1([], [text(model.title)]),
      html.p([], [text(model.subtitle)]),
    ]),
    html.div([attribute.class("tabs")], [
      tab_button("Browser", Browser, model.active_tab),
      tab_button("Editor", Editor, model.active_tab),
      tab_button("Drawing", Drawing, model.active_tab),
      tab_button("Statistics", Statistics, model.active_tab),
    ]),
    html.div([attribute.class("toolbar")], [
      html.button([attribute.class("primary"), event.on_click(NewCard)], [text("New Card")]),
      html.button([event.on_click(DuplicateCard)], [text("Duplicate")]),
      html.button([attribute.class(link_mode_class(model.link_mode)), event.on_click(ToggleLinkMode)], [text("Link Mode")]),
      html.button([event.on_click(ClearFilters)], [text("Clear Filters")]),
    ]),
  ])
}

fn tab_button(label: String, tab: Tab, active: Tab) -> Element(Msg) {
  let class = case tab == active {
    True -> "tab active"
    False -> "tab"
  }

  html.button([attribute.class(class), event.on_click(SetTab(tab))], [text(label)])
}

fn browser_panel(model: Model) -> Element(Msg) {
  let cards = visible_cards(model)
  let label_buttons =
    labels(model)
    |> list.map(fn(label) {
      let active = string.lowercase(model.label_filter) == string.lowercase(label)
      let class = case active { True -> "chip active" False -> "chip" }
      html.button([attribute.class(class), event.on_click(LabelFilterChanged(label))], [text(label)])
    })
  let outline_items = cards |> list.map(fn(card) { outline_item(model, card) })

  html.div([attribute.class("panel")], [
    panel_header("Browser", int.to_string(list.length(cards)) <> " results"),
    html.div([attribute.class("panel-body")], [
      html.div([attribute.class("section")], [
        html.h3([], [text("Search")]),
        html.input([
          attribute.class("search"),
          attribute.placeholder("Search cards, body text, or labels"),
          attribute.type_("search"),
          attribute.value(model.search),
          event.on_input(SearchChanged),
        ]),
      ]),
      html.div([attribute.class("section")], [
        html.h3([], [text("Labels")]),
        html.div([attribute.class("chip-row")], [
          html.button([
            attribute.class(case model.label_filter == "" { True -> "chip active" False -> "chip" }),
            event.on_click(LabelFilterChanged("")),
          ], [text("All")]),
          ..label_buttons
        ]),
      ]),
      html.div([attribute.class("outline")], outline_items),
    ]),
  ])
}

fn outline_item(model: Model, card: Card) -> Element(Msg) {
  let active = card.id == model.selected_card_id
  let class = case active { True -> "outline-item active" False -> "outline-item" }

  html.button([attribute.class(class), event.on_click(SelectCard(card.id))], [
    html.div([attribute.class("title")], [text(card.title)]),
    html.div([attribute.class("meta")], [
      html.span([], [text(string.join(card.labels, with: " · "))]),
      html.span([], [text(int.to_string(card.w) <> "×" <> int.to_string(card.h))]),
    ]),
  ])
}

fn canvas_panel(model: Model) -> Element(Msg) {
  let nodes =
    model.cards
    |> list.filter(fn(card) { visible_card(model, card) })
    |> list.map(fn(card) { card_node(model, card) })

  html.div([attribute.class("panel canvas-shell")], [
    html.div([attribute.class("canvas-toolbar")], [
      html.div([attribute.class("chip-row")], [
        html.span([attribute.class("chip")], [text(card_count(model) <> " cards")]),
        html.span([attribute.class("chip")], [text(link_count(model) <> " links")]),
        html.span([attribute.class(case model.link_mode { True -> "chip active" False -> "chip" })], [text("Link Mode")]),
      ]),
      html.div([attribute.class("chip-row")], [
        html.button([event.on_click(SelectCard(model.selected_card_id))], [text("Focus")]),
      ]),
    ]),
    html.div([attribute.class("canvas-stage")], nodes),
  ])
}

fn card_node(model: Model, card: Card) -> Element(Msg) {
  let active = card.id == model.selected_card_id
  let class = case active { True -> "node active" False -> "node" }
  let style =
    "left:"
    <> int.to_string(card.x)
    <> "px;top:"
    <> int.to_string(card.y)
    <> "px;width:"
    <> int.to_string(card.w)
    <> "px;min-height:"
    <> int.to_string(card.h)
    <> "px;border-top:3px solid "
    <> card.color
    <> ";"
  let hint =
    case model.link_mode && model.selected_card_id != card.id {
      True -> "Click to link"
      False -> "Click to select"
    }

  html.button(
    [
      attribute.class(class),
      attribute.attribute("style", style),
      attribute.title(hint),
      event.on_click(SelectCard(card.id)),
    ],
    [
      html.div([attribute.class("node-top")], [
        html.div([], [
          html.div([attribute.class("node-title")], [text(card.title)]),
          html.div([attribute.class("help")], [text(card.id)]),
        ]),
        html.span([attribute.class("chip")], [text(hint)]),
      ]),
      html.div([attribute.class("node-body")], [text(card.body)]),
      html.div([attribute.class("tag-row")], tag_spans(card.labels)),
    ],
  )
}

fn inspector_panel(model: Model) -> Element(Msg) {
  let card = selected_card(model)

  html.div([attribute.class("panel inspector-panel")], [
    panel_header(tab_name(model.active_tab), tab_help(model.active_tab)),
  html.div([attribute.class("panel-body")], [
      case model.active_tab {
        Browser -> browser_help()
        Editor -> editor_panel(card)
        Drawing -> drawing_panel(model, card)
        Statistics -> statistics_panel(model)
      },
      project_help(),
    ]),
  ])
}

fn browser_help() -> Element(Msg) {
  html.div([attribute.class("section")], [
    html.h3([], [text("Browser")]),
    html.div([attribute.class("help")], [
      text("Use the search box and label chips to navigate. "),
      text("The filters apply to the card outline and the canvas."),
    ]),
  ])
}

fn editor_panel(card: Card) -> Element(Msg) {
  html.div([], [
    html.div([attribute.class("section")], [
      html.h3([], [text("Selected Card")]),
      html.div([attribute.class("help")], [text(card.id)]),
    ]),
    html.div([attribute.class("field")], [
      html.label([], [text("Title")]),
      html.input([
        attribute.value(card.title),
        event.on_input(UpdateSelectedTitle),
      ]),
    ]),
    html.div([attribute.class("field")], [
      html.label([], [text("Body")]),
      html.textarea([
        attribute.value(card.body),
        event.on_input(UpdateSelectedBody),
      ], []),
    ]),
    html.div([attribute.class("field")], [
      html.label([], [text("Labels")]),
      html.input([
        attribute.value(string.join(card.labels, with: ", ")),
        attribute.placeholder("Comma separated"),
        event.on_input(UpdateSelectedLabels),
      ]),
    ]),
    html.div([attribute.class("chip-row")], [
      html.button([attribute.class("primary"), event.on_click(NewCard)], [text("New")]),
      html.button([event.on_click(DuplicateCard)], [text("Duplicate")]),
      html.button([event.on_click(DeleteCard)], [text("Delete")]),
    ]),
  ])
}

fn drawing_panel(model: Model, card: Card) -> Element(Msg) {
  html.div([attribute.class("section")], [
    html.h3([], [text("Drawing")]),
    html.div([attribute.class("stat-grid")], [
      stat("Selected", card.title),
      stat("Canvas", int.to_string(card_count(model))),
      stat("Links", int.to_string(link_count(model))),
      stat("Mode", tab_name(model.active_tab)),
    ]),
  ])
}

fn statistics_panel(model: Model) -> Element(Msg) {
  html.div([attribute.class("section")], [
    html.h3([], [text("Statistics")]),
    html.div([attribute.class("stat-grid")], [
      stat("Cards", int.to_string(list.length(model.cards))),
      stat("Links", int.to_string(list.length(model.links))),
      stat("Labels", int.to_string(list.length(labels(model)))),
      stat("Filter", case model.search == "" { True -> "none" False -> "active" }),
    ]),
    html.div([attribute.class("section")], [
      html.h3([], [text("Links")]),
      html.div([attribute.class("link-list")], link_items(model.links)),
    ]),
  ])
}

fn stat(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("stat")], [
    html.strong([], [text(value)]),
    html.span([], [text(label)]),
  ])
}

fn project_help() -> Element(Msg) {
  html.div([attribute.class("section")], [
    html.h3([], [text("Project")]),
    html.div([attribute.class("help")], [
      text("This is a Gleam/Lustre scaffold. "),
      text("Lustre’s dev tools use a top-level assets directory and can generate the browser HTML entrypoint during development and build."),
    ]),
  ])
}

fn statusbar(model: Model) -> Element(Msg) {
  let card = selected_card(model)

  html.div([attribute.class("statusbar")], [
    html.div([], [
      text("Selected: "),
      html.code([], [text(card.title)]),
      case model.link_mode {
        True -> text(" | link mode active")
        False -> text("")
      },
    ]),
    html.div([], [
      html.code([], [text(tab_name(model.active_tab))]),
      html.code([], [text(if model.search == "" { "no search" } else { "search: " <> model.search })]),
      html.code([], [text(if model.label_filter == "" { "all labels" } else { "label: " <> model.label_filter })]),
    ]),
  ])
}

fn panel_header(title: String, subtitle: String) -> Element(Msg) {
  html.div([attribute.class("panel-header")], [
    html.h2([], [text(title)]),
    html.span([attribute.class("help")], [text(subtitle)]),
  ])
}

fn tab_name(tab: Tab) -> String {
  case tab {
    Browser -> "Browser"
    Editor -> "Editor"
    Drawing -> "Drawing"
    Statistics -> "Statistics"
  }
}

fn tab_help(tab: Tab) -> String {
  case tab {
    Browser -> "Filter and navigate"
    Editor -> "Edit the selected card"
    Drawing -> "Spatial arrangement"
    Statistics -> "Project overview"
  }
}

fn selected_card(model: Model) -> Card {
  case find_card(model.cards, model.selected_card_id) {
    Some(card) -> card
    None -> first_card(model.cards)
  }
}

fn find_card(cards: List(Card), id: String) -> Option(Card) {
  case cards {
    [] -> None
    [card, ..rest] -> {
      case card.id == id {
        True -> Some(card)
        False -> find_card(rest, id)
      }
    }
  }
}

fn first_card(cards: List(Card)) -> Card {
  case cards {
    [card, .._] -> card
    [] -> Card("empty", "Empty", "No cards yet.", 50, 50, 220, 100, ["Empty"], "#8be9fd")
  }
}

fn next_card_id(cards: List(Card)) -> String {
  "card-" <> int.to_string(list.length(cards) + 1)
}

fn link_exists(links: List(Link), from: String, to: String) -> Bool {
  case links {
    [] -> False
    [Link(source, target, _), ..rest] ->
      case source == from && target == to {
        True -> True
        False -> link_exists(rest, from, to)
      }
  }
}

fn card_count(model: Model) -> String {
  int.to_string(list.length(model.cards))
}

fn link_count(model: Model) -> String {
  int.to_string(list.length(model.links))
}

fn visible_cards(model: Model) -> List(Card) {
  list.filter(model.cards, fn(card) {
    visible_card(model, card)
  })
}

fn visible_card(model: Model, card: Card) -> Bool {
  let search = string.lowercase(model.search)
  let label_filter = string.lowercase(model.label_filter)
  let haystack =
    string.lowercase(
      card.title <> " " <> card.body <> " " <> string.join(card.labels, with: " "),
    )
  let search_hit =
    case string.is_empty(search) {
      True -> True
      False -> string.contains(does: haystack, contain: search)
    }
  let label_hit =
    case string.is_empty(label_filter) {
      True -> True
      False -> list.any(card.labels, fn(label) { string.lowercase(label) == label_filter })
    }

  search_hit && label_hit
}

fn labels(model: Model) -> List(String) {
  unique_labels(model.cards, [])
}

fn unique_labels(cards: List(Card), acc: List(String)) -> List(String) {
  case cards {
    [] -> list.reverse(acc)
    [card, ..rest] -> unique_labels(rest, merge_labels(card.labels, acc))
  }
}

fn merge_labels(labels: List(String), acc: List(String)) -> List(String) {
  case labels {
    [] -> acc
    [label, ..rest] -> {
      case label_exists(acc, label) {
        True -> merge_labels(rest, acc)
        False -> merge_labels(rest, [label, ..acc])
      }
    }
  }
}

fn label_exists(labels: List(String), label: String) -> Bool {
  list.any(labels, fn(existing) { string.lowercase(existing) == string.lowercase(label) })
}

fn toggle_filter(current: String, next: String) -> String {
  case string.lowercase(current) == string.lowercase(next) {
    True -> ""
    False -> next
  }
}

fn parse_labels(input: String) -> List(String) {
  input
  |> string.split(on: ",")
  |> list.map(string.trim)
  |> list.filter(fn(label) { label != "" })
}

fn link_mode_class(active: Bool) -> String {
  case active {
    True -> "primary"
    False -> ""
  }
}

fn tag_spans(labels: List(String)) -> List(Element(Msg)) {
  labels
  |> list.map(fn(label) { html.span([attribute.class("tag")], [text(label)]) })
}

fn link_items(links: List(Link)) -> List(Element(Msg)) {
  links
  |> list.map(fn(link) {
    html.div([attribute.class("link-item")], [
      text(link.from <> " → " <> link.to <> " · " <> link.label),
    ])
  })
}
