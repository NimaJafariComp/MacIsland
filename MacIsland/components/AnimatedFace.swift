//
//  AnimatedFace.swift
//
// Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import SwiftUI

enum IdleFaceMotionPolicy {
    static func shouldAnimate(isVisible: Bool, reduceMotion: Bool) -> Bool {
        isVisible && IslandMotion.allowsNonessentialMotion(reduceMotion: reduceMotion)
    }
}

struct MinimalFaceFeatures: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false
    @State private var blinkTask: Task<Void, Never>?
    @State var height:CGFloat = 20;
    @State var width:CGFloat = 30;
    
    var body: some View {
        VStack(spacing: 4) { // Adjusted spacing to fit within 30x30
            // Eyes
            HStack(spacing: 4) { // Adjusted spacing to fit within 30x30
                Eye(isBlinking: $isBlinking)
                Eye(isBlinking: $isBlinking)
            }
            
            // Nose and mouth combined
            VStack(spacing: 2) { // Adjusted spacing to fit within 30x30
                // Nose
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.islandPrimaryText)
                    .frame(width: 3, height: 4)
                
                // Mouth (happy)
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: height / 2))
                        path.addQuadCurve(to: CGPoint(x: width, y: height / 2), control: CGPoint(x: width / 2, y: height))
                    }
                    .stroke(Color.islandPrimaryText, lineWidth: 2)
                }
                .frame(width: 14, height: 10)
            }
        }
        .frame(width: self.width, height: self.height) // Maximum size of face
        .onAppear {
            updateBlinking()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateBlinking()
        }
        .onDisappear {
            stopBlinking()
        }
    }
    
    private func updateBlinking() {
        guard IdleFaceMotionPolicy.shouldAnimate(isVisible: true, reduceMotion: reduceMotion) else {
            stopBlinking()
            return
        }

        startBlinking()
    }

    private func startBlinking() {
        blinkTask?.cancel()
        blinkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(IslandMotion.content) { isBlinking = true }
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                withAnimation(IslandMotion.content) { isBlinking = false }
            }
        }
    }

    private func stopBlinking() {
        blinkTask?.cancel()
        blinkTask = nil

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            isBlinking = false
        }
    }
}

struct Eye: View {
    @Binding var isBlinking: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.islandPrimaryText)
            .frame(width: 4, height: isBlinking ? 1 : 4)
            .frame(maxWidth: 15, maxHeight: 15) // Adjusted max size
            .animation(IslandMotion.content, value: isBlinking)
    }
}

struct MinimalFaceFeatures_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.islandHardwareSurface
            MinimalFaceFeatures()
        }
        .previewLayout(.fixed(width: 60, height: 60)) // Adjusted preview size for better visibility
    }
}
