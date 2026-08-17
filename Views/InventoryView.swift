//
//  InventoryView.swift
//  HomeChef AI
//
//  Vista principal del inventario. Muestra todos los InventoryItem
//  guardados usando @Query, con un diseño de tarjetas estilizadas
//  (sombra suave, esquinas redondeadas, badge de categoría por color).
//

import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query(sort: \InventoryItem.dateAdded, order: .reverse)
    private var items: [InventoryItem]

    @Environment(\.modelContext) private var modelContext

    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Inventario vacío",
                        systemImage: "tray",
                        description: Text("Agrega tu primer producto con el botón +")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            InventoryCard(item: item)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Inventario")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddInventoryItemView()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

/// Tarjeta estilizada para un producto del inventario: nombre, cantidad
/// y un badge de color derivado de la categoría.
private struct InventoryCard: View {
    let item: InventoryItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                CategoryBadge(category: item.category)
            }

            Spacer()

            Text(formattedQuantity)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var formattedQuantity: String {
        item.quantity.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// Badge tipo "pill" con el nombre de la categoría, coloreado de forma
/// estable según CategoryColor.
private struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category.uppercased())
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.bold)
            .tracking(0.4)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(category.categoryColor.opacity(0.16))
            )
            .foregroundStyle(category.categoryColor)
    }
}

#Preview {
    InventoryView()
        .modelContainer(for: [InventoryItem.self, Recipe.self], inMemory: true)
}
