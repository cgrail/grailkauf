import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                switch model.mode {
                case .list: ListModeView()
                case .shop: ShopModeView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $model.mode) {
                        Text("List").tag(Mode.list)
                        Text("Shop").tag(Mode.shop)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        // Time alone changes the picture: a trip ends four hours after its last tick.
        .onChange(of: scenePhase) { if scenePhase == .active { model.store.refresh() } }
        // The Live Activity links here.
        .onOpenURL { _ in model.mode = .shop }
        .confirmationDialog(
            "Join shared list?", isPresented: .constant(model.invite != nil), titleVisibility: .visible,
            presenting: model.invite
        ) { invitation in
            Button("Join") {
                model.join(invitation)
                model.invite = nil
            }
            Button("Cancel", role: .cancel) { model.invite = nil }
        } message: { _ in
            Text("Your own list with \(model.store.state.todo.count) items will be replaced by the shared one.")
        }
        .alert("Something went wrong", isPresented: .constant(model.store.problem != nil)) {
            Button("OK") { model.store.problem = nil }
        } message: {
            Text(model.store.problem ?? "")
        }
    }
}
