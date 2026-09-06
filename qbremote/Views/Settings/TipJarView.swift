import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showTipJarPopup") private var showTipJarPopup: Bool = true
    @Environment(\.purchase) private var purchase
    
    @State private var products: [Product] = []
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.pink)
                        .padding(.top, 40)
                    
                    Text("Support Development")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("If you find this app useful, please consider leaving a tip. It helps keep the app maintained and ad-free.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        if products.isEmpty {
                            ProgressView()
                                .padding(.top)
                        } else {
                            ForEach(products.sorted(by: { $0.price < $1.price })) { product in
                                Button {
                                    Task {
                                        await purchaseProduct(product)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .background(Color.blue)
                                            .clipShape(Capsule())
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                                .disabled(isPurchasing)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer(minLength: 40)
                    
                    Text("Leave a tip or uncheck the tip jar in settings to disable this popup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                do {
                    products = try await Product.products(for: TipProductID.all)
                } catch {
                    print("Failed to load products: \(error)")
                }
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await purchase(product)
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    showTipJarPopup = false
                    await transaction.finish()
                    dismiss()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }
}

#Preview {
    TipJarView()
}
