//
//  UserProfileView.swift
//  HomeChef AI
//
//  Pantalla de perfil culinario. Muestra y edita el perfil ACTIVO del
//  ViewModel (la misma instancia que éste carga y guarda). Cada cambio
//  (toggle, alta o baja) se guarda de inmediato; al cerrar la pantalla
//  también se agrega lo que haya quedado escrito sin confirmar.
//  Incluye su propio NavigationStack para poder presentarse como sheet o
//  como pestaña.
//

import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = UserProfileViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.profile != nil {
                    profileForm
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
            .onDisappear {
                viewModel.commitPendingDrafts(context: modelContext)
            }
        }
    }

    // MARK: - Formulario

    private var profileForm: some View {
        Form {
            Section {
                ForEach(DietaryRestriction.allCases) { restriction in
                    Toggle(restriction.rawValue, isOn: restrictionBinding(restriction))
                }
            } header: {
                Text("Restricciones dietéticas")
            } footer: {
                Text("Las recetas se adaptarán a todas las que actives.")
            }

            listSection(
                kind: .forbidden,
                title: "Alergias e ingredientes prohibidos",
                placeholder: "Ej. maní, mariscos",
                footer: "No se usarán en las recetas. Aun así, revisa siempre los ingredientes antes de cocinar."
            )

            listSection(
                kind: .favorite,
                title: "Ingredientes favoritos",
                placeholder: "Ej. albahaca, queso",
                footer: "Se incluirán cuando encajen de forma natural en la receta."
            )

            listSection(
                kind: .staple,
                title: "Despensa básica",
                placeholder: "Ej. sal, aceite, pimienta",
                footer: "Lo que siempre tienes en casa: se puede usar aunque no esté en tu inventario, y no aparece en tu inventario ni se descuenta al cocinar. Toca un básico para marcarlo como agotado; los agotados no se envían a la IA.\n\nTu perfil se guarda en este dispositivo. Al generar una receta, estas preferencias se envían a Gemini (Google) junto con tu inventario."
            )
        }
    }

    private func listSection(
        kind: ProfileListKind,
        title: String,
        placeholder: String,
        footer: String
    ) -> some View {
        Section {
            ForEach(viewModel.items(for: kind), id: \.self) { item in
                row(for: item, kind: kind)
            }
            .onDelete { offsets in
                viewModel.remove(at: offsets, from: kind, context: modelContext)
            }

            HStack {
                TextField(placeholder, text: draftBinding(for: kind))
                    .submitLabel(.done)
                    .onSubmit {
                        viewModel.addDraft(for: kind, context: modelContext)
                    }

                Button {
                    viewModel.addDraft(for: kind, context: modelContext)
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

    // MARK: - Filas

    /// Fila de un elemento. En la despensa básica es un botón que alterna
    /// entre disponible y agotado (texto tachado y badge naranja).
    @ViewBuilder
    private func row(for item: String, kind: ProfileListKind) -> some View {
        if kind == .staple {
            let isOut = viewModel.isOutOfStock(item)

            Button {
                viewModel.toggleOutOfStock(item, context: modelContext)
            } label: {
                HStack {
                    Text(item)
                        .strikethrough(isOut)
                        .foregroundStyle(isOut ? .secondary : .primary)

                    Spacer()

                    if isOut {
                        Text("AGOTADO")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.bold)
                            .tracking(0.4)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.16)))
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(item)
        }
    }

    // MARK: - Bindings

    private func restrictionBinding(_ restriction: DietaryRestriction) -> Binding<Bool> {
        Binding(
            get: { viewModel.isSelected(restriction) },
            set: { viewModel.setRestriction(restriction, isOn: $0, context: modelContext) }
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
