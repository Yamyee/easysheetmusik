import Foundation
import StoreKit

@MainActor
final class StoreKitPurchaseService {
    static let shared = StoreKitPurchaseService()

    private let entitlementService: AppEntitlementService
    private let proProductID = "com.chordpress.pro.lifetime"

    private(set) var products: [Product] = []

    init(entitlementService: AppEntitlementService? = nil) {
        self.entitlementService = entitlementService ?? .shared
    }

    func loadProducts() async throws {
        products = try await Product.products(for: [proProductID])
    }

    func purchasePro() async throws {
        guard let product = products.first(where: { $0.id == proProductID }) else {
            try await loadProducts()
            guard let product = products.first(where: { $0.id == proProductID }) else { return }
            try await purchase(product)
            return
        }
        try await purchase(product)
    }

    func refreshPurchasedEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == proProductID else { continue }
            entitlementService.markProUnlockedForTesting(true)
            return
        }
    }

    private func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(.verified(let transaction)) = result {
            entitlementService.markProUnlockedForTesting(true)
            await transaction.finish()
        }
    }
}
