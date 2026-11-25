import SwiftUI
import PencilKit

/// Full-screen PencilKit canvas. Fine strokes with the Pencil, the eraser only rubs out what you pass over.
struct SketchEditor: View {
    @Binding var data: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            CanvasRepresentable(drawing: $drawing)
                .background(Theme.card)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            data = drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .onAppear {
            if let data, let d = try? PKDrawing(data: data) { drawing = d }
        }
    }
}

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = UIDevice.current.userInterfaceIdiom == .pad ? .default : .anyInput
        canvas.tool = PKInkingTool(.pen, color: UIColor(hex: 0x2357D9), width: 3)
        canvas.alwaysBounceVertical = true
        canvas.contentSize = CGSize(width: 2000, height: 3000)
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasRepresentable
        let picker = PKToolPicker()
        init(_ parent: CanvasRepresentable) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

/// Inline preview of a sketch inside a note.
struct SketchPreview: View {
    var data: Data
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty {
            let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
            let image = renderImage(drawing, bounds: bounds)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 280)
        }
    }

    private func renderImage(_ drawing: PKDrawing, bounds: CGRect) -> UIImage {
        var image = UIImage()
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        traits.performAsCurrent {
            image = drawing.image(from: bounds, scale: UIScreen.main.scale)
        }
        return image
    }
}
