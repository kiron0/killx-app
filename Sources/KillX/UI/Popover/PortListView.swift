import SwiftUI

struct PortListView: View {
    @ObservedObject var vm: AppListViewModel

    private var groupedPorts: [(String, [PortInfo])] {
        let mode = ConfigStore.shared.config.grouping
        guard mode != .none else { return [("", vm.filteredPorts)] }
        let groups = Dictionary(grouping: vm.filteredPorts) { port -> String in
            switch mode {
            case .none: return ""
            case .project: return port.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Other"
            case .docker: return port.docker?.name ?? "Local processes"
            case .process: return port.processGroup ?? port.displayAppName
            }
        }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    @ViewBuilder
    var body: some View {
        if vm.listNeedsScrolling {
            ScrollView(.vertical, showsIndicators: true) {
                rows
            }
        } else {
            rows
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var rows: some View {
        LazyVStack(spacing: 2) {
            ForEach(groupedPorts, id: \.0) { group, ports in
                if !group.isEmpty {
                    Text(group)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.top, 3)
                }
                ForEach(ports) { port in
                    PortRowView(port: port, vm: vm)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
