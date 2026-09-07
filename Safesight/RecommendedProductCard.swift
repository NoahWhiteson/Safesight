//
//  RecommendedProductCard.swift
//  Safesight
//

import SwiftUI
import UIKit

struct RecommendedProductCard: View {
    let product: ScanProductDTO

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        Button {
            Haptics.light()
            if let raw = product.productURL, let url = URL(string: raw) {
                UIApplication.shared.open(url)
            } else if let asin = product.asin,
                      let url = URL(string: "https://www.amazon.com/dp/\(asin)") {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.96))
                        .frame(height: 120)

                    if let urlString = product.imageURL,
                       !AmazonCatalog.isUnusableImageURL(urlString),
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(10)
                            case .failure:
                                placeholderIcon
                            default:
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                    } else if let name = product.imageName,
                              !name.hasPrefix("Hazard"),
                              UIImage(named: name) != nil {
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .padding(.horizontal, 10)
                    } else {
                        placeholderIcon
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(product.reason)
                        .font(.system(size: 13))
                        .foregroundStyle(mute)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(product.priceLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(blue)
                    Spacer(minLength: 0)
                    Text("Amazon")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mute)
                }
            }
            .padding(16)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderIcon: some View {
        Image(systemName: product.icon)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(blue)
    }
}

