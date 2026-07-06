import SwiftUI

/// Vintage editor with direct typing: number pad, blank = NV (non-vintage).
struct VintageField: View {
    @Binding var vintage: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text("Vintage")
            Spacer()
            TextField("NV", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .focused($focused)
                .onChange(of: text) {
                    let digits = String(text.filter(\.isNumber).prefix(4))
                    if digits != text { text = digits }
                    vintage = Int(digits) ?? 0
                }
                .onAppear {
                    text = vintage > 0 ? String(vintage) : ""
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }
                    }
                }
        }
    }
}
