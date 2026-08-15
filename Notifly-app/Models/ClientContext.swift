import Foundation

/// A plain snapshot of the parts of a client's profile that note generation is
/// allowed to see.
///
/// `Client` and `Goal` are SwiftData models tied to the main actor's context,
/// so they can't be handed to `NoteGenerationService`'s async passes directly.
/// Copying out the few fields the prompts actually use keeps the generation
/// layer off the persistence layer, and makes what reaches the model explicit —
/// notably that only goal titles and details are ever sent, never a client's
/// note history.
struct ClientContext: Sendable {
    var displayName: String
    var goals: [GoalContext]

    /// False when there is nothing worth putting in front of the model, so the
    /// reference block is omitted rather than sent as an empty heading.
    var hasProfileContent: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty || !goals.isEmpty
    }
}

struct GoalContext: Sendable {
    var title: String
    var details: String
}

extension ClientContext {
    /// Archived goals are deliberately excluded: the goal-anchor and per-goal
    /// passes ask whether each goal was worked on today, which only makes sense
    /// for goals still being worked toward. `activeGoals` also fixes the order,
    /// which the anchor pass depends on to pair its results back to goals.
    init(client: Client) {
        displayName = client.displayName
        goals = client.activeGoals.map { GoalContext(goal: $0) }
    }
}

extension GoalContext {
    init(goal: Goal) {
        title = goal.title
        details = goal.details
    }
}
