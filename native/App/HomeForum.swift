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
  @State private var pinned: [ThreadSummary] = []
  @State private var page = 1
  @State private var digest = false
  @State private var sort = 0
  @State private var loading = false
  @State private var error: String?
  @State private var action = false
  @State private var signed = false
  @State private var request = UUID()
  private var visiblePinned: [ThreadSummary] {
    pinned.filter { item in
      !(settings.flag("blockVideo") && item.video != nil) && !app.library.blocked(user: item.author, forum: name, thread: item.id, text: item.title, extraText: item.excerpt)
    }
  }
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if let forum = result.forum { forumHeader(forum) }
          if !visiblePinned.isEmpty {
            VStack(spacing: 0) {
              ForEach(Array(visiblePinned.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, 38) }
                NavigationLink(value: Route.thread(item.id, "", 1, false)) {
                  HStack(spacing: 10) {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(settings.accent)
                    Text(item.title).font(.subheadline).foregroundStyle(Color(uiColor: .label)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color(uiColor: .tertiaryLabel))
                  }.padding(12).contentShape(Rectangle())
                }.buttonStyle(.plain)
              }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
          }
          ForEach(result.items.filter { !$0.pinned }) { ThreadCard(thread: $0, standalone: true) }
          LoadState(loading: loading, error: error, empty: result.items.isEmpty) { request = UUID() }
        }.padding(12).id("top")
      }.background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              NavigationLink(value: Route.search(name)) { Label(tr("searchInForum"), systemImage: "magnifyingglass") }
              NavigationLink(value: Route.info(result.forum?.id ?? "", name)) { Label(tr("forumInfo"), systemImage: "info.circle") }
              Picker(tr("sort"), selection: $sort) { Text(tr("latestReply")).tag(0); Text(tr("latestPost")).tag(1) }
              Toggle(tr("digest"), isOn: $digest)
              Button(tr("pin"), systemImage: "pin") { if let forum = result.forum { app.updateLibrary { $0.togglePin(forum) } } }
              Button(tr("backToTop"), systemImage: "arrow.up") { withAnimation { proxy.scrollTo("top", anchor: .top) } }
            } label: { Image(systemName: "ellipsis") }
          }
          Pagination(page: page, more: result.hasMore, loading: loading, previous: { page -= 1; request = UUID() }, refresh: { request = UUID() }, next: { page += 1; request = UUID() })
        }.task(id: request) { await load(); if !Task.isCancelled { proxy.scrollTo("top", anchor: .top) } }.refreshable { await load() }
        .onChange(of: sort) { _, value in settings.set("forumSort." + name, String(value)); page = 1; request = UUID() }
        .onChange(of: digest) { _, _ in page = 1; request = UUID() }
        .onAppear { sort = Int(settings.text("forumSort." + name)) ?? (settings.text("defaultSortType") == "post" ? 1 : 0) }
    }
  }
  private func forumHeader(_ forum: Forum) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        AsyncImage(url: safeURL(forum.avatar)) { image in image.resizable().scaledToFill() } placeholder: {
          Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(settings.accent)
        }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 4) {
          Text(forum.name.isEmpty ? name : forum.name).font(.headline).foregroundStyle(Color(uiColor: .label))
          if !settings.flag("hideForumIntroAndStat") {
            Text([forum.members.map { "\(tr("members")) \($0.formatted())" }, "\(tr("threads")) \(forum.threads.formatted())"].compactMap { $0 }.joined(separator: " · "))
              .font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel)).fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 0)
      }
      if !settings.flag("hideForumIntroAndStat") && !forum.intro.isEmpty {
        Text(forum.intro).font(.subheadline).foregroundStyle(Color(uiColor: .secondaryLabel))
      }
      HStack {
        Button(tr(forum.following ? "unfollow" : "follow")) {
          perform { try await app.api.follow(forum, enabled: !forum.following); request = UUID() }
        }.buttonStyle(.glass).disabled(action)
        Spacer(minLength: 12)
        Button(tr((signed || forum.signed) ? "checkedIn" : "checkIn"), systemImage: (signed || forum.signed) ? "checkmark.circle.fill" : "checkmark.circle") {
          perform { try await app.sign(forum); signed = true; result.forum?.signed = true }
        }.buttonStyle(.glassProminent).disabled(signed || forum.signed || action)
      }.font(.subheadline)
    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
  }
  private func perform(_ body: @escaping () async throws -> Void) { app.requireLogin { Task { @MainActor in action = true; defer { action = false }; do { try await body() } catch { app.error = error.localizedDescription } } } }
  private func load() async {
    let expected = request; loading = true; error = nil
    do { var data = try await app.api.forum(name, page: page, sort: sort, digest: digest); guard !Task.isCancelled, request == expected else { return }
      var seen = Set<String>()
      data.items = data.items.filter { seen.insert($0.id).inserted }
      var retained = page == 1 ? [] : pinned
      let incoming = Set(data.items.map(\.id))
      retained.removeAll { incoming.contains($0.id) }
      retained.append(contentsOf: data.items.filter(\.pinned))
      pinned = retained; result = data
      if let forum = data.forum { signed = signed || forum.signed; app.updateLibrary { $0.visit(forum) } }
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    if expected == request { loading = false }
  }
}
