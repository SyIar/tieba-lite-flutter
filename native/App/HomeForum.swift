import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var app: AppState
  @EnvironmentObject private var settings: Preferences
  @State private var loading = false
  @State private var error: String?
  @State private var checkIn = false
  @State private var open = false
  @State private var query = ""
  @State private var target: Route?
  var body: some View {
    List {
      if !app.library.pins.isEmpty { Section(tr("pinnedForums")) { forums(app.library.pins) } }
      if settings.flag("homePageShowHistoryForum") && !app.library.recentForums.isEmpty { Section(tr("recentForums")) { forums(app.library.recentForums) } }
      Section(tr("followedForums")) {
        if app.session == nil { Button(tr("signIn")) { app.login = true } }
        else { forums(app.followed.filter { forum in settings.flag("showTopForumInNormalList") || !app.library.pins.contains(where: { $0.name == forum.name }) }) }
        LoadState(loading: loading, error: error, empty: app.session != nil && app.followed.isEmpty) { Task { await load() } }
      }
    }.navigationTitle(tr("appTitle"))
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          NavigationLink(value: Route.search("")) { Image(systemName: "magnifyingglass") }
          Menu {
            Button(tr("openForum"), systemImage: "plus") { open = true }
            Button(tr(settings.flag("listSingle") ? "gridView" : "listView"), systemImage: "square.grid.2x2") { settings.set("listSingle", !settings.flag("listSingle")) }
            Button(tr("signAll"), systemImage: "checkmark.circle") { app.requireLogin { checkIn = true } }.disabled(app.signing)
          } label: { Image(systemName: "ellipsis") }
        }
      }.task { await load(); await automaticCheckIn() }.refreshable { await load() }
      .onChange(of: app.library.recentForums.map(\.name)) { _, _ in }
      .confirmationDialog(tr("signAllConfirm"), isPresented: $checkIn, titleVisibility: .visible) { Button(tr("confirm")) { Task { await app.signAll() } } }
      .alert(tr("openForum"), isPresented: $open) { TextField(tr("forumName"), text: $query); Button(tr("open")) { if let url = URL(string: query), let route = Route.link(url) { target = route } else if !query.trimmingCharacters(in: .whitespaces).isEmpty { target = .forum(query.trimmingCharacters(in: .whitespaces)) } }; Button(tr("cancel"), role: .cancel) {} }
      .navigationDestination(item: $target) { Destination(route: $0) }
  }
  @ViewBuilder private func forums(_ values: [Forum]) -> some View {
    let visible = values.filter { !app.library.blocked(forum: $0.name) }
    if settings.flag("listSingle") { ForEach(visible, id: \.name) { ForumRow(forum: $0) } }
    else { LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 14) { ForEach(visible, id: \.name) { forum in
      NavigationLink(value: Route.forum(forum.name)) {
        VStack(spacing: 7) {
          AsyncImage(url: safeURL(forum.avatar)) { $0.resizable().scaledToFill() } placeholder: { Image(systemName: "bubble.left.and.bubble.right.fill").font(.title2) }.frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 14))
          Text(forum.name).font(.subheadline).lineLimit(1)
          if forum.following { Text(tr(forum.signed ? "checkedIn" : "notCheckedIn")).font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 7)
      }.buttonStyle(.plain).contextMenu { Button(tr("pin")) { app.updateLibrary { $0.togglePin(forum) } } }
    } } }
  }
  private func load() async { loading = true; error = nil; defer { loading = false }; do { try await app.refreshForums() } catch { self.error = error.localizedDescription } }
  private func automaticCheckIn() async {
    guard settings.flag("autoSign"), app.session != nil, settings.text("signDay") != DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) else { return }
    let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
    if formatter.string(from: Date()) >= settings.text("autoSignTime") { await app.signAll() }
  }
}

struct ForumView: View {
  let name: String
  @EnvironmentObject private var app: AppState
  @EnvironmentObject private var settings: Preferences
  @State private var result = PageResult<ThreadSummary>()
  @State private var page = 1
  @State private var digest = false
  @State private var sort = 0
  @State private var loading = false
  @State private var error: String?
  @State private var action = false
  @State private var signed = false
  @State private var request = UUID()
  var body: some View {
    ScrollViewReader { proxy in
      List {
        Color.clear.frame(height: 0).listRowInsets(EdgeInsets()).id("top")
        if let forum = result.forum {
          Section {
            if !settings.flag("hideForumIntroAndStat") {
              if !forum.intro.isEmpty { Text(forum.intro).font(.subheadline).foregroundStyle(.secondary) }
              HStack { if let count = forum.members { Text("\(tr("members")) \(count.formatted())") }; Text("\(tr("threads")) \(forum.threads.formatted())") }.font(.caption).foregroundStyle(.secondary)
            }
            HStack {
              Button(tr(forum.following ? "unfollow" : "follow")) { perform { try await app.api.follow(forum, enabled: !forum.following); request = UUID() } }.buttonStyle(.glass)
              Spacer()
              Button(tr((signed || forum.signed) ? "checkedIn" : "checkIn"), systemImage: (signed || forum.signed) ? "checkmark.circle.fill" : "checkmark.circle") {
                perform { try await app.sign(forum); signed = true; result.forum?.signed = true }
              }.buttonStyle(.glassProminent).disabled(signed || forum.signed || action)
            }
          }
        }
        let pinned = result.items.filter(\.pinned)
        if !pinned.isEmpty { Section { ForEach(pinned) { item in
          if !app.library.blocked(user: item.author, thread: item.id, text: item.title) { NavigationLink(value: Route.thread(item.id, "", 1, false)) { Label(item.title, systemImage: "pin.fill").font(.subheadline).lineLimit(1) } }
        } } }
        Section { ForEach(result.items.filter { !$0.pinned }) { ThreadCard(thread: $0) }; LoadState(loading: loading, error: error, empty: result.items.isEmpty) { request = UUID() } }
      }.navigationTitle(name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              NavigationLink(value: Route.search(name)) { Label(tr("searchInForum"), systemImage: "magnifyingglass") }
              NavigationLink(value: Route.info(result.forum?.id ?? "", name)) { Label(tr("forumInfo"), systemImage: "info.circle") }
              Picker(tr("sort"), selection: $sort) { Text(tr("latestReply")).tag(0); Text(tr("latestPost")).tag(1) }
              Toggle(tr("digest"), isOn: $digest)
              Button(tr("pin"), systemImage: "pin") { if let forum = result.forum { app.updateLibrary { $0.togglePin(forum) } } }
              Button(tr("backToTop"), systemImage: "arrow.up") { withAnimation { proxy.scrollTo("top") } }
            } label: { Image(systemName: "ellipsis") }
          }
          Pagination(page: page, more: result.hasMore, loading: loading, previous: { page -= 1; request = UUID() }, refresh: { request = UUID() }, next: { page += 1; request = UUID() })
        }.task(id: request) { await load(); proxy.scrollTo("top") }.refreshable { await load() }
        .onChange(of: sort) { _, value in settings.set("forumSort." + name, String(value)); page = 1; request = UUID() }
        .onChange(of: digest) { _, _ in page = 1; request = UUID() }
        .onAppear { sort = Int(settings.text("forumSort." + name)) ?? (settings.text("defaultSortType") == "post" ? 1 : 0) }
    }
  }
  private func perform(_ body: @escaping () async throws -> Void) { app.requireLogin { Task { @MainActor in action = true; defer { action = false }; do { try await body() } catch { app.error = error.localizedDescription } } } }
  private func load() async {
    let expected = request; loading = true; error = nil
    do { let data = try await app.api.forum(name, page: page, sort: sort, digest: digest); guard !Task.isCancelled, request == expected else { return }; result = data
      if let forum = data.forum { signed = signed || forum.signed; app.updateLibrary { $0.visit(forum) } }
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    if expected == request { loading = false }
  }
}
