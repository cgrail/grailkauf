import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []
    @State private var menuOpen = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.mode {
                case .list: ListModeView()
                case .shop: ShopModeView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !model.selecting { modeAndMenu }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .trip(let date): TripView(date: date)
                case .settings: SettingsView()
                }
            }
        }
        .overlay { menu }
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
            Text("The shared list replaces your own list with \(model.store.state.todo.count) items.")
        }
        .alert("Something went wrong", isPresented: .constant(model.store.problem != nil)) {
            Button("OK") { model.store.problem = nil }
        } message: {
            Text(model.store.problem ?? "")
        }
    }

    /// Slides in from the left. A tap next to it closes it.
    private var menu: some View {
        // An explicit stack: the stack of an overlay centers its views, and a centered menu does not slide out fully.
        ZStack(alignment: .leading) {
            if menuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeMenu)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                MenuView { route in
                    closeMenu()
                    path.append(route)
                }
                .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.85, 360) }
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, closeMenu)
                .transition(.move(edge: .leading))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func closeMenu() { withAnimation { menuOpen = false } }

    @ToolbarContentBuilder private var modeAndMenu: some ToolbarContent {
        @Bindable var model = model
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $model.mode) {
                Text("List").tag(Mode.list)
                Text("Shop").tag(Mode.shop)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        ToolbarItem(placement: .topBarLeading) {
            Button("Menu", systemImage: "line.3.horizontal") { withAnimation { menuOpen = true } }
        }
    }
}
