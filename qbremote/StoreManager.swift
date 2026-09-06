import StoreKit
import SwiftUI

enum TipProductID {
    static let small = "com.OneRadStudio.qbremote.tip.small"
    static let medium = "com.OneRadStudio.qbremote.tip.medium"
    static let large = "com.OneRadStudio.qbremote.tip.large"
    static let all: [String] = [small, medium, large]
}

@Observable
@MainActor
class StoreManager {
    static let shared = StoreManager()
    
    // Using AppStorage within a singleton requires accessing the underlying UserDefaults directly
    // since @AppStorage requires a View. We can expose a method to update the setting.
    func disableTipJarPopup() {
        UserDefaults.standard.set(false, forKey: "showTipJarPopup")
    }
    
    func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                
                // If it's a tip, disable future popups
                if TipProductID.all.contains(transaction.productID) {
                    await MainActor.run {
                        self.disableTipJarPopup()
                    }
                }
                
                // Consumables are finished immediately after delivery (we deliver by updating the user setting above)
                await transaction.finish()
            }
        }
    }
}
