//
//  ContentView.swift
//  Shh
//
//  Created by Eom Chanwoo on 10/7/24.
//

import SwiftUI

// MARK: - 장소 선택 뷰
struct SelectModeView: View {
    // MARK: Properties
    @EnvironmentObject var routerManager: RouterManager
    
    let menuList: [String] = ["집", "카페", "도서관"]
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 16) {
            ForEach(menuList, id: \.self) { menu in
                Button {
                    routerManager.push(view: .noiseView)
                } label: {
                    menuButtonStyle(title: menu, textColor: .white, bgColor: .gray)
                }
            }
            
            Button {
                routerManager.push(view: .createModeView)
            } label: {
                menuButtonStyle(title: "+", textColor: .white, bgColor: .gray)
                    .opacity(0.5)
            }
        }
        .navigationTitle("장소 선택")
    }
    
    // MARK: Subviews
    private func menuButtonStyle(title: String, textColor: Color, bgColor: Color) -> some View {
        Text(title)
            .font(.title3)
            .bold()
            .foregroundColor(textColor)
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 100)
                    .fill(bgColor)
                    .frame(width: 300)
            )
    }
}

#Preview {
    SelectModeView()
}
