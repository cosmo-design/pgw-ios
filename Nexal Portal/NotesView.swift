import SwiftUI

struct NotesView: View {
    @State private var notes: [ClientNote] = []
    @State private var isLoading = false
    @State private var error = ""
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newBody = ""
    @State private var newPriority = "normal"

    var pendingNotes: [ClientNote] { notes.filter { !$0.done }.sorted { priorityOrder($0) < priorityOrder($1) } }
    var doneNotes: [ClientNote] { notes.filter { $0.done } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && notes.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !error.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Tap + to add an action item"))
                } else {
                    List {
                        if !pendingNotes.isEmpty {
                            Section("Open (\(pendingNotes.count))") {
                                ForEach(pendingNotes) { note in
                                    NoteRow(note: note, onToggle: { Task { await toggleDone(note) } })
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) { Task { await delete(note) } } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        if !doneNotes.isEmpty {
                            Section("Completed (\(doneNotes.count))") {
                                ForEach(doneNotes) { note in
                                    NoteRow(note: note, onToggle: { Task { await toggleDone(note) } })
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) { Task { await delete(note) } } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notes & Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showAdd) {
                addNoteSheet
            }
        }
    }

    var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Get pest control invoices", text: $newTitle)
                }
                Section("Details (optional)") {
                    TextField("Notes…", text: $newBody, axis: .vertical).lineLimit(3...8)
                }
                Section("Priority") {
                    Picker("Priority", selection: $newPriority) {
                        Text("High").tag("high")
                        Text("Normal").tag("normal")
                        Text("Low").tag("low")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false; newTitle = ""; newBody = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await addNote() } }.disabled(newTitle.isEmpty)
                }
            }
        }
    }

    func load() async {
        isLoading = true
        error = ""
        do { notes = try await APIClient.shared.getNotes() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func toggleDone(_ note: ClientNote) async {
        do {
            try await APIClient.shared.updateNote(note.id, done: !note.done)
            await load()
        } catch {}
    }

    func delete(_ note: ClientNote) async {
        do {
            try await APIClient.shared.deleteNote(note.id)
            notes.removeAll { $0.id == note.id }
        } catch {}
    }

    func addNote() async {
        do {
            _ = try await APIClient.shared.createNote(title: newTitle, body: newBody.isEmpty ? nil : newBody, priority: newPriority)
            newTitle = ""; newBody = ""; newPriority = "normal"
            showAdd = false
            await load()
        } catch {}
    }

    func priorityOrder(_ note: ClientNote) -> Int {
        switch note.priority { case "high": return 0; case "normal": return 1; default: return 2 }
    }
}

// MARK: - Note Row
struct NoteRow: View {
    let note: ClientNote
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { onToggle() } label: {
                Image(systemName: note.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(note.done ? .green : priorityColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.subheadline)
                    .strikethrough(note.done)
                    .foregroundStyle(note.done ? .secondary : .primary)
                if let body = note.body, !body.isEmpty {
                    Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }

            Spacer()

            if note.priority == "high" && !note.done {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    var priorityColor: Color {
        switch note.priority { case "high": return .red; case "low": return .secondary; default: return .blue }
    }
}
