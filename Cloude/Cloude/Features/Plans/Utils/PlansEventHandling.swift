import Foundation
import CloudeShared

extension App {
    func handlePlans(stages: [String: [PlanItem]]) {
        plansStore.handle(stages: stages)
    }

    func handlePlanDeleted(stage: String, filename: String) {
        plansStore.handleDeleted(stage: stage, filename: filename)
    }
}
