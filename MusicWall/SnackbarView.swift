//
//  SnackbarView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/23/25.
//

import SwiftUI

struct SnackbarView: View {
    var message: String
    var icon: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    var textColor: Color = .primary
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(textColor)
            }
            
            Text(message)
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer(minLength: 10)
            
            if let actionLabel = actionLabel, let action = action {
                Button(actionLabel) {
                    action()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
            }
        }
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding(.horizontal, 16)
    }
}

extension View {
    func snackbar(
        isPresented: Binding<Bool>,
        message: String,
        icon: String? = nil,
        duration: TimeInterval = 3,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                VStack {
                    Spacer()
                    SnackbarView(
                        message: message,
                        icon: icon,
                        actionLabel: actionLabel,
                        action: action
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: isPresented.wrappedValue)
            }
        }
    }
}

#Preview {
    @Previewable @State var showSnackbar = false
    @Previewable @State var counter = 0
    
    VStack(spacing: 20) {
        Text("Counter: \(counter)")
            .font(.title)
        
        Button("Increment") {
            counter += 1
            withAnimation { showSnackbar = true }
        }
    }
    .snackbar(
        isPresented: $showSnackbar,
        message: "A large number of very longwinded and overzealous items were added!",
        icon: "checkmark.circle.fill",
        duration: 3,
        actionLabel: "Undo",
        action: {
            counter -= 1
        },
    )
}
