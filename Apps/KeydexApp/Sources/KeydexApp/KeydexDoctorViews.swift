import KeydexCore
import SwiftUI

struct DoctorPanel: View {
  let issues: [DoctorIssue]
  let isEmptyMode: Bool
  @State private var isHovered = false

  private var issueRows: [DoctorIssueRow] {
    issues.map(DoctorIssueRow.init)
  }

  private var previewRows: [DoctorIssueRow] {
    Array(issueRows.prefix(1))
  }

  private var primaryIssue: DoctorIssueRow? {
    previewRows.first
  }

  private var remainingIssueCount: Int {
    max(issueRows.count - previewRows.count, 0)
  }

  private var accessibilityHint: String {
    if issues.isEmpty {
      return "No repair issues are currently listed."
    }

    return "Showing \(previewRows.count) of \(issueRows.count) repair issues."
  }

  private var feedbackTrigger: String {
    "\(issueRows.count)|\(primaryIssue?.id ?? "clear")"
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      Label {
        Text("Doctor")
          .font(.headline)
      } icon: {
        Image(systemName: issues.isEmpty ? "checkmark.seal" : "stethoscope")
          .font(.body.weight(.semibold))
          .frame(width: 30, height: 30)
          .background(KeydexGlassTone.railControlFill, in: Circle())
          .symbolEffect(.bounce, value: feedbackTrigger)
      }
      .foregroundStyle(issues.isEmpty ? .green : .primary)

      Divider()
        .frame(height: 24)

      if let primaryIssue {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 7) {
            Text(primaryIssue.severityLabel)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(primaryIssue.severityTint)
            Text(primaryIssue.credentialLabel)
              .font(.subheadline)
              .fontDesign(.monospaced)
              .lineLimit(1)
          }
          .contentTransition(.opacity)

          Text(primaryIssue.issue.action)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .contentTransition(.opacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(primaryIssue.accessibilityLabel)
      } else {
        VStack(alignment: .leading, spacing: 3) {
          Text(isEmptyMode ? "Ready for sources" : "No issues found")
            .font(.subheadline)
          Text(isEmptyMode ? "Scan sources or add metadata." : "Inventory is healthy.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 12)

      if issues.isEmpty {
        Label("Clear", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.medium))
          .foregroundStyle(.green)
      } else {
        Text("\(issueRows.count) issues")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .contentTransition(.numericText())

        if remainingIssueCount > 0 {
          Text("+\(remainingIssueCount)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KeydexGlassTone.railControlFill, in: Capsule())
            .contentTransition(.numericText())
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 8)
    .frame(
      maxWidth: KeydexRailLayout.maxWidth,
      minHeight: KeydexRailLayout.railHeight,
      alignment: .center
    )
    .keydexFloatingGlassPanel(stroke: KeydexGlassTone.railFloatingStroke)
    .scaleEffect(isHovered ? 1.012 : 1.0)
    .onHover { hovering in
      isHovered = hovering
    }
    .animation(KeydexMotion.controlHover, value: isHovered)
    .animation(KeydexMotion.railStateChange, value: feedbackTrigger)
    .sensoryFeedback(issues.isEmpty ? .success : .warning, trigger: feedbackTrigger)
    .accessibilityIdentifier("keydex.doctor.panel")
    .accessibilityLabel("Credential repair queue")
    .accessibilityHint(accessibilityHint)
  }
}
