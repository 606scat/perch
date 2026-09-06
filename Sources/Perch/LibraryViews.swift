import AppKit
import SwiftUI
import QuickLookUI
import PerchCore

struct NotesView: View {
    @EnvironmentObject var store: AppStore
    private var title: String { store.data.noteDraftTitle ?? "" }
    private var detail: String { store.data.noteDraftDetail ?? "" }
    @State private var deleting: Note?
    @State private var taskDraft: TaskDraft?
    @FocusState private var titleFocused: Bool
    private var selection: Note? { store.data.notes.first { $0.id == store.selectedNoteID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Notes").font(.system(size: 12, weight: .semibold))
                Spacer()
                if store.demo { Text("Preview").font(.system(size: 9)).foregroundStyle(Palette.secondary) }
                if selection != nil { Button("Done") { store.selectedNoteID = nil }.buttonStyle(.plain).foregroundStyle(store.accentColor) }
            }
            if let note = selection {
                TextEditor(text: Binding(get: { store.data.notes.first { $0.id == note.id }?.text ?? "" }, set: { store.updateNote(note.id, text: $0) }))
                    .font(.system(size: 12)).lineSpacing(4).scrollContentBackground(.hidden)
                    .padding(7).background(Palette.field, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Note text")
                HStack {
                    Text("Saved automatically").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    Spacer()
                    iconButton("Turn note into a task", symbol: "checklist") { taskDraft = TaskDraft(title: note.title) }
                        .disabled(!store.reminders.selectedListExists || !store.reminders.authorized)
                    iconButton("Delete note", symbol: "trash") { deleting = note }
                }
            } else {
                HStack(alignment: .top, spacing: 7) {
                    VStack(spacing: 6) {
                        TextField("", text: Binding(get: { title }, set: { store.data.noteDraftTitle = $0 })).textFieldStyle(.plain).focused($titleFocused)
                            .accessibilityLabel("New note")
                            .overlay(alignment: .leading) { if title.isEmpty { Text("New note").foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true) } }
                            .onSubmit { save() }.padding(.horizontal, 8).frame(height: 25)
                            .background(Palette.field, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(titleFocused ? store.accentColor : Palette.rule.opacity(0.13), lineWidth: 1))
                        TextField("", text: Binding(get: { detail }, set: { store.data.noteDraftDetail = $0 })).textFieldStyle(.plain)
                            .accessibilityLabel("Description (optional)")
                            .overlay(alignment: .leading) { if detail.isEmpty { Text("Description (optional)").foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true) } }
                            .onSubmit { save() }.padding(.horizontal, 8).frame(height: 25)
                            .background(Palette.field, in: RoundedRectangle(cornerRadius: 8))
                    }.font(.system(size: 11))
                    Button(action: save) { Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.onAccent)
                        .frame(width: 25, height: 25).background(store.accentColor, in: Circle()) }
                        .buttonStyle(.plain).help("Save note").accessibilityLabel("Save note")
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !store.data.notes.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.data.notes) { note in
                                Button { store.selectedNoteID = note.id; store.activatePanel?() } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: "text.alignleft").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                        Text(note.title).font(.system(size: 11)).lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Palette.secondary)
                                    }.padding(.vertical, 9).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(.top, 3)
                }
            }
        }.padding(14)
        .alert("Delete this note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete note", role: .destructive) { if let note = deleting { store.deleteNote(note) }; deleting = nil }
        } message: { Text("You can undo this for 10 seconds.") }
        .sheet(item: $taskDraft) { TaskComposer(draft: $0).environmentObject(store).environmentObject(store.reminders) }
    }
    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        store.addNote(cleaned + (detail.isEmpty ? "" : "\n\n" + detail))
        store.selectedNoteID = nil; store.data.noteDraftTitle = nil; store.data.noteDraftDetail = nil
        store.sounds.play(.drop, preferences: store.data.preferences)
    }
}

struct SnippetsView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var editing: Snippet?
    @State private var deleting: Snippet?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: "Snippets", detail: "Your useful words, always within reach.", action: "New") { editing = Snippet(title: "", text: "") }
            if store.data.snippets.isEmpty {
                EmptyState(symbol: "text.quote", title: "Write it once. Keep it handy.", detail: "Pin a reply, link, or command. Click a snippet to copy it instantly. Commands are copied as text, never run.")
            } else {
                TextField("Find a snippet", text: $search).textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.data.snippets.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search) }) { snippet in
                            HStack(alignment: .top, spacing: 10) {
                                Button { store.copy(snippet) } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(snippet.title).font(.system(size: 14, weight: .medium))
                                        Text(snippet.text).font(.system(size: 12)).foregroundStyle(Palette.secondary).lineLimit(3).multilineTextAlignment(.leading)
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Copy \(snippet.title)")
                                VStack(spacing: 8) {
                                    iconButton("Copy snippet", symbol: "doc.on.doc") { store.copy(snippet) }
                                    Menu {
                                        Button("Edit") { editing = snippet }
                                        Button("Delete", role: .destructive) { deleting = snippet }
                                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                                }
                            }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
        }.padding(14)
        .sheet(item: $editing) { SnippetEditor(snippet: $0).environmentObject(store) }
        .alert("Delete this snippet?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete snippet", role: .destructive) { if let item = deleting { store.removeSnippet(item) }; deleting = nil }
        } message: { Text("You can undo this for 10 seconds.") }
    }
}

struct SnippetEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State var snippet: Snippet
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pin a snippet").font(.title2.bold())
            TextField("Name", text: $snippet.title).textFieldStyle(.roundedBorder)
            TextEditor(text: $snippet.text).font(.body).frame(height: 160).accessibilityLabel("Snippet content")
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Save snippet") {
                snippet.title = snippet.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if let i = store.data.snippets.firstIndex(where: { $0.id == snippet.id }) { store.data.snippets[i] = snippet }
                else { store.data.snippets.insert(snippet, at: 0) }
                store.showToast("Snippet saved"); dismiss()
            }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction)
                .disabled(snippet.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || snippet.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 400)
            .tint(store.accentColor).accentColor(store.accentColor)
    }
}

@MainActor final class TrayPreview: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = TrayPreview()
    var url: URL?
    func show(_ url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self; panel.reloadData(); panel.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { url as NSURL? }
}

struct TrayView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: "File tray", detail: "A stop along the way. Originals stay put.", action: "Add") { store.chooseFiles() }
            if store.data.tray.isEmpty {
                VStack(spacing: 14) {
                    WidgetGlyph(widget: .tray).frame(width: 40, height: 40).foregroundStyle(store.accentColor)
                    Text(store.receivingFiles ? "Release to add files" : "Drop something here").font(.system(size: 15, weight: .medium))
                    Text("Keep files here, then drag them into another app.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    Button("Choose files…") { store.chooseFiles() }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity).padding(.vertical, 25)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder((store.receivingFiles ? store.accentColor : Palette.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                Text("You can also drop files onto the Perch dock.").font(.caption).foregroundStyle(Palette.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.data.tray) { item in
                            let url = store.resolve(item)
                            let exists = FileManager.default.fileExists(atPath: url.path)
                            HStack(spacing: 12) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(url.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                    Text(exists ? "Drag to another app" : "Original is unavailable").font(.caption).foregroundStyle(exists ? Palette.secondary : Palette.warning)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                iconButton("Quick Look", symbol: "eye") { TrayPreview.shared.show(url) }.disabled(!exists)
                                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.plain).help("Share file").disabled(!exists)
                                iconButton("Remove from tray", symbol: "xmark") { store.removeTray(item) }
                            }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .onDrag { exists ? NSItemProvider(object: url as NSURL) : NSItemProvider() }
                            .contextMenu {
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.disabled(!exists)
                                Button("Remove from tray") { store.removeTray(item) }
                            }
                        }
                    }
                }
                Text("\(store.data.tray.count) \(store.data.tray.count == 1 ? "item" : "items") · removing an item never deletes its original.")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        }.padding(14)
        .background(store.receivingFiles ? store.accentColor.opacity(0.10) : .clear)
        .animation(.easeOut(duration: 0.15), value: store.receivingFiles)
    }
}

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: ProjectLink?
    @State private var deleting: ProjectLink?
    var groups: [String] { Array(Set(store.data.links.map(\.project))).sorted() }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: "Projects", detail: "Everything you need to pick things up.", action: "Add") { editing = .init(title: "", destination: "", project: "") }
            if store.data.links.isEmpty {
                EmptyState(symbol: "square.stack.3d.up", title: "Give each project a home.", detail: "Keep its websites, apps, and folders together. Open one shortcut, or the whole workspace.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(groups, id: \.self) { project in
                            let links = store.data.links.filter { $0.project == project }
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(project).font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Spacer()
                                    Button("Open all (\(links.count))") { links.forEach { store.open($0) } }.font(.caption).buttonStyle(.plain).foregroundStyle(store.accentColor)
                                }.padding(.bottom, 4)
                                ForEach(links) { link in
                                    HStack {
                                        Button { store.open(link) } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: link.safeURL?.isFileURL == true ? "folder" : "link").foregroundStyle(store.accentColor).frame(width: 24)
                                                Text(link.title).lineLimit(1)
                                                Spacer()
                                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Palette.secondary)
                                            }.contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                        Menu {
                                            Button("Edit shortcut") { editing = link }
                                            Button("Remove shortcut", role: .destructive) { deleting = link }
                                        } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                                    }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
        }.padding(14)
        .sheet(item: $editing) { ProjectEditor(link: $0).environmentObject(store) }
        .alert("Remove this shortcut?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Remove", role: .destructive) {
                if let link = deleting {
                    store.data.links.removeAll { $0.id == link.id }
                    store.offerUndo("Shortcut removed") { store.data.links.append(link) }
                }
                deleting = nil
            }
        } message: { Text("The app, folder, or website will stay where it is.") }
    }
}

struct ProjectEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State var link: ProjectLink
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project shortcut").font(.title2.bold())
            TextField("Project name", text: $link.project).textFieldStyle(.roundedBorder)
            TextField("Shortcut name", text: $link.title).textFieldStyle(.roundedBorder)
            TextField("https://…", text: $link.destination).textFieldStyle(.roundedBorder).onChange(of: link.destination) { _, _ in link.bookmark = nil }
            Button("Choose an app, file, or folder…") {
                let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.treatsFilePackagesAsDirectories = false
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    link.destination = url.absoluteString
                    if link.title.isEmpty { link.title = url.deletingPathExtension().lastPathComponent }
                    // Destination binding invalidates the previous bookmark. The URL remains usable if this write is cleared.
                    link.bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                }
            }
            Text("Website links use https:// or http://. Commands belong in Snippets.").font(.caption).foregroundStyle(Palette.secondary)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save shortcut") {
                    link.title = link.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    link.project = link.project.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let i = store.data.links.firstIndex(where: { $0.id == link.id }) { store.data.links[i] = link }
                    else { store.data.links.append(link) }
                    dismiss()
                }.buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent).keyboardShortcut(.defaultAction)
                    .disabled(link.safeURL == nil || link.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || link.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 400)
            .tint(store.accentColor).accentColor(store.accentColor)
    }
}
