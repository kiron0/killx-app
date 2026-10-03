import SwiftUI

struct PortListView: View {
    @ObservedObject var vm: AppListViewModel

    @ViewBuilder
    var body: some View {
        if vm.listNeedsScrolling {
            ScrollView(.vertical, showsIndicators: true) {
                rows
            }
        } else {
            rows
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(vm.filteredPorts) { port in
                PortRowView(port: port, vm: vm)
            }
        }
        .padding(.vertical, 2)
    }
}
