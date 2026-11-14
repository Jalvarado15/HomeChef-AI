//
//  UserProfileView.swift
//  HomeChef AI
//
//  Pantalla de perfil culinario. Cada cambio (toggle, alta o baja de un
//  elemento) se guarda de inmediato en SwiftData a través del ViewModel.
//  Incluye su propio NavigationStack para poder presentarse como sheet o
//  como pestaña.
//

import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]

    @State private var viewModel = UserProfileViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    profileForm(for: profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Perfil culinario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.ensureProfileExists(context: modelContext)
            }
        }
    }

    // MARK: - Formulario

    private func profileForm(for profile: UserProfile) -> some View {
        Form {
            Section {
                ForEach(DietaryRestriction.allCases) { restriction in
                    Toggle(restriction.rawValue, isOn: restrictionBinding(restriction, in: profile))
                }
            } header: {
                Text("Restricciones dietéticas")
            } footer: {
                Text("Las recetas se adaptarán a todas las que actives.")
            }

            listSection(
                kind: .forbidden,
                profile: profile,
                title: "Alergias e ingredientes prohibidos",
                placeholder: "Ej. maní, mariscos",
                footer: "No se usarán en las recetas. Aun así, revisa siempre los ingredientes antes de cocinar."
            )

            listSection(
                kind: .favorite,
                profile: profile,
                title: "Ingredientes favoritos",
                placeholder: "Ej. albahaca, queso",
                footer: "Se incluirán cuando encajen de forma natural en la receta."
            )

            listSection(
                kind: .staple,
                profile: profile,
                title: "Despensa básica",
                placeholder: "Ej. sal, aceite, pimienta",
                footer: "Lo que siempre tienes en casa: se puede usar aunque no esté en tu inventario.\n\nTu perfil se guarda en este dispositivo. Al generar una receta, estas preferencias se envían a Gemini (Google) junto con tu inventario."
            )
        }
    }

    private func listSection(
        kind: ProfileListKind,
        profile: UserProfile,
        title: String,
        placeholder: String,
        footer: String
    ) -> some View {
        Section {
            ForEach(profile[keyPath: kind.keyPath], id: \.self) { item in
                Text(item)
            }
            .onDelete { offsets in
                viewModel.remove(at: offsets, from: kind, in: profile, context: modelContext)
            }

            HStack {
                TextField(placeholder, text: draftBinding(for: kind))
                    .submitLabel(.done)
                    .onSubmit {
                        viewModel.addDraft(for: kind, to: profile, context: modelContext)
                    }

                Button {
                    viewModel.addDraft(for: kind, to: profile, context: modelContext)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canAddDraft(for: kind))
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    // MARK: - Bindings

    private func restrictionBinding(_ restriction: DietaryRestriction, in profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { viewModel.isSelected(restriction, in: profile) },
            set: { viewModel.setRestriction(restriction, isOn: $0, in: profile, context: modelContext) }
        )
    }

    private func draftBinding(for kind: ProfileListKind) -> Binding<String> {
        Binding(
            get: { viewModel.drafts[kind] ?? "" },
            set: { viewModel.drafts[kind] = $0 }
        )
    }
}

#Preview {
    UserProfileView()
        .modelContainer(for: [InventoryItem.self, Recipe.self, UserProfile.self], inMemory: true)
}
