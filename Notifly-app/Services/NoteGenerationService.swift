import Foundation
import FoundationModels

/// Errors raised during note generation, with messages suitable for
/// showing directly to a clinician in the UI.
enum NoteGenerationError: LocalizedError {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case emptyTranscript
    case transcriptTooLong
    case contentFlagged
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, which is required to generate notes on-device."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings > Apple Intelligence & Siri, then try again."
        case .modelNotReady:
            return "The on-device model is still downloading. Please try again in a few minutes."
        case .emptyTranscript:
            return "The transcript is empty, so there is nothing to convert into a note."
        case .transcriptTooLong:
            return "This transcript is too long for the on-device model. Try recording shorter segments and generating a note for each."
        case .contentFlagged:
            return "The on-device model declined to process this transcript. Review the transcript and try again."
        case .generationFailed(let detail):
            return "Note generation failed: \(detail)"
        }
    }
}

struct NoteGenerationService {

    /// Mid-range on purpose: near-greedy decoding makes the model copy the
    /// transcript verbatim, high temperature makes it embellish past the
    /// evidence.
    private static let temperature = 0.5

    /// Ceilings, not targets — a backstop against a runaway field.
    private enum TokenBudget {
        static let factual = 800
        static let interpretive = 400
        static let goalListing = 1200
        static let goalDetail = 600
        static let sessionGate = 120
        static let goalAnchors = 400
        /// Kept small on purpose — most sessions leave nothing over once the
        /// documented goals are covered, and a generous budget was inviting
        /// the model to pad this field with restated goal content.
        static let leftoverObservations = 300
    }

    // MARK: - Public API
    //
    // Notes are built from several small passes. Apple's guidance for the
    // on-device model is to break a complex task into simple ones and to keep
    // every prompt short: input tokens must all be processed before the first
    // output token appears, so instruction bulk is latency on every note.
    //
    // For goal-focused notes: when the client has documented goals, those
    // goals are the fixed source of truth — one pass checks each documented
    // goal against the transcript, and a separate pass captures anything
    // discussed that isn't about any of them (`sessionObservations`), rather
    // than letting the model invent or rename goals. Without a client
    // profile, goals are discovered freehand from the transcript instead.
    // Every per-goal pass sees the whole transcript and is told which single
    // goal to write up and which to ignore.
    //
    // `clientContext` is reference material and lives in the prompt, not in
    // `Instructions` — Instructions are the model's high-authority channel, and
    // goal text there once caused a goal's target ("for 5 mins") to be written
    // up as a measured result.

    static func generateSOAP(
        transcript: String,
        tone: NoteTone = .standard,
        clientContext: ClientContext? = nil
    ) async throws -> SOAPNote {
        let trimmed = try validate(transcript)

        let factual = try await generate(
            SOAPFactualPart.self,
            source: trimmed,
            request: "Extract the facts from this dictation.",
            reference: clientReference(clientContext),
            instructions: factualInstructions(tone: tone, sectionSplit: Self.soapSectionSplit),
            maximumResponseTokens: TokenBudget.factual
        )

        guard factual.hasSufficientContent else {
            return SOAPNote(
                hasSufficientContent: false,
                insufficientContentReason: factual.insufficientContentReason ?? "",
                subjective: "", objective: "", assessment: "", plan: "",
                goalsAddressed: "", timeSpent: "", interventionsUsed: ""
            )
        }

        let interpretive = try await generate(
            SOAPInterpretivePart.self,
            source: trimmed,
            request: "Extract the clinician's conclusions and plan from this dictation.",
            reference: clientReference(clientContext),
            instructions: interpretiveInstructions(tone: tone),
            maximumResponseTokens: TokenBudget.interpretive
        )

        return SOAPNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            subjective: corrected(factual.subjective),
            objective: corrected(factual.objective),
            assessment: corrected(interpretive.assessment),
            plan: corrected(interpretive.plan),
            goalsAddressed: corrected(factual.goalsAddressed),
            timeSpent: factual.timeSpent,
            interventionsUsed: corrected(factual.interventionsUsed)
        )
    }

    static func generateDAP(
        transcript: String,
        tone: NoteTone = .standard,
        clientContext: ClientContext? = nil
    ) async throws -> DAPNote {
        let trimmed = try validate(transcript)

        let factual = try await generate(
            DAPFactualPart.self,
            source: trimmed,
            request: "Extract the facts from this dictation.",
            reference: clientReference(clientContext),
            instructions: factualInstructions(tone: tone, sectionSplit: Self.dapSectionSplit),
            maximumResponseTokens: TokenBudget.factual
        )

        guard factual.hasSufficientContent else {
            return DAPNote(
                hasSufficientContent: false,
                insufficientContentReason: factual.insufficientContentReason ?? "",
                data: "", assessment: "", plan: "",
                goalsAddressed: "", timeSpent: "", interventionsUsed: ""
            )
        }

        let interpretive = try await generate(
            DAPInterpretivePart.self,
            source: trimmed,
            request: "Extract the clinician's conclusions and plan from this dictation.",
            reference: clientReference(clientContext),
            instructions: interpretiveInstructions(tone: tone),
            maximumResponseTokens: TokenBudget.interpretive
        )

        return DAPNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            data: corrected(factual.data),
            assessment: corrected(interpretive.assessment),
            plan: corrected(interpretive.plan),
            goalsAddressed: corrected(factual.goalsAddressed),
            timeSpent: factual.timeSpent,
            interventionsUsed: corrected(factual.interventionsUsed)
        )
    }

    static func generateGoalFocused(
        transcript: String,
        tone: NoteTone = .standard,
        clientContext: ClientContext? = nil
    ) async throws -> GoalFocusedNote {
        let trimmed = try validate(transcript)

        if let clientContext, !clientContext.goals.isEmpty {
            return try await generateGoalFocusedFromProfile(trimmed, tone: tone, clientContext: clientContext)
        }

        return try await generateGoalFocusedFreeform(trimmed, tone: tone, clientContext: clientContext)
    }

    /// The client's documented goals are the ground truth for what goals
    /// exist — the model reports whether each known goal was addressed
    /// today, it never names or invents one. Anything discussed that isn't
    /// one of those goals lands in `sessionObservations` instead of becoming
    /// a fabricated goal card.
    private static func generateGoalFocusedFromProfile(
        _ transcript: String,
        tone: NoteTone,
        clientContext: ClientContext
    ) async throws -> GoalFocusedNote {
        let gate = try await generate(
            SessionGate.self,
            source: transcript,
            request: "Judge whether this is a real therapy session with clinical content.",
            reference: nil,
            instructions: sessionGateInstructions(),
            maximumResponseTokens: TokenBudget.sessionGate
        )

        guard gate.hasSufficientContent else {
            return GoalFocusedNote(
                hasSufficientContent: false,
                insufficientContentReason: gate.insufficientContentReason ?? "",
                sessionObservations: "",
                goals: []
            )
        }

        let slices = try await resolveGoalSlices(transcript, clientContext: clientContext)

        var goals: [GeneratedGoal] = []
        for (index, goal) in clientContext.goals.enumerated() {
            let writeUp = try await generate(
                GoalWriteUp.self,
                source: slices[index] ?? transcript,
                request: "Was the goal \"\(goal.title)\" addressed in today's session? If so, write it up.",
                reference: singleGoalReference(clientContext, goal: goal),
                instructions: goalWriteUpInstructions(tone: tone),
                maximumResponseTokens: TokenBudget.goalDetail
            )

            let activities = corrected(writeUp.activities)
            var observations = corrected(writeUp.observations)
            let nextSteps = corrected(writeUp.nextSteps)

            // Empty across the board means this documented goal wasn't
            // addressed today — omit the card rather than show the
            // clinician a goal with nothing in it.
            guard !activities.isEmpty || !observations.isEmpty || !nextSteps.isEmpty else {
                continue
            }

            if isGoalEcho(observations, goal: goal.title) {
                observations = ""
            }

            goals.append(GeneratedGoal(
                goal: goal.title.trimmingCharacters(in: .whitespacesAndNewlines),
                activities: activities,
                observations: observations,
                nextSteps: nextSteps
            ))
        }

        // Run only once every documented goal has its own write-up, and
        // grounded on that actual text — giving the model something concrete
        // to diff against caught far more repeats in testing than telling it
        // to avoid the (abstract) goal list ever did.
        let leftover = try await generate(
            LeftoverObservations.self,
            source: transcript,
            request: "Summarise anything in today's session the goal write-ups below don't already cover.",
            reference: coveredGoalsReference(goals),
            instructions: leftoverObservationsInstructions(tone: tone),
            maximumResponseTokens: TokenBudget.leftoverObservations
        )

        let additionalObservations = stripDuplicateContent(corrected(leftover.text), goals: goals)

        return GoalFocusedNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            sessionObservations: additionalObservations,
            goals: goals
        )
    }

    /// Narrows the transcript passed to each documented goal's write-up pass,
    /// when a reliable starting point can be found for it. Not a hard
    /// partition — a goal without a resolvable anchor, or one whose anchor
    /// collides with another goal's, is simply absent from the result and its
    /// write-up pass falls back to the full transcript, the same protection
    /// (the "write up only this goal" instruction) every goal had before this
    /// existed.
    private static func resolveGoalSlices(
        _ transcript: String,
        clientContext: ClientContext
    ) async throws -> [Int: String] {
        let anchorSet = try await generate(
            GoalAnchorSet.self,
            source: transcript,
            request: "Find where each documented goal's discussion begins, if it was addressed today.",
            reference: clientReference(clientContext),
            instructions: goalAnchorInstructions(),
            maximumResponseTokens: TokenBudget.goalAnchors
        )

        // A mismatched count means the positional correspondence to
        // `clientContext.goals` can't be trusted — skip slicing entirely
        // rather than risk pairing an anchor with the wrong goal.
        guard anchorSet.anchors.count == clientContext.goals.count else { return [:] }

        return sliceByAnchors(transcript, anchors: anchorSet.anchors.map(\.sectionStart))
    }

    /// Resolves each anchor to a position in the transcript, drops any pair
    /// that landed suspiciously close together (a sign of an ambiguous
    /// match), and cuts each remaining anchor's slice from its position to
    /// the next one.
    private static func sliceByAnchors(_ transcript: String, anchors: [String]) -> [Int: String] {
        struct Anchor { let goalIndex: Int; let position: Int }

        let normalised = normaliseWithMap(transcript)

        var resolved: [Anchor] = []
        for (goalIndex, anchor) in anchors.enumerated() {
            guard !anchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let position = locateOffset(anchor, in: normalised.text) else { continue }
            resolved.append(Anchor(goalIndex: goalIndex, position: position))
        }

        let collisionDistance = 20
        let clean = resolved
            .filter { candidate in
                resolved.allSatisfy { other in
                    other.goalIndex == candidate.goalIndex || abs(other.position - candidate.position) >= collisionDistance
                }
            }
            .sorted { $0.position < $1.position }

        var slices: [Int: String] = [:]
        for (i, anchor) in clean.enumerated() {
            guard anchor.position < normalised.map.count else { continue }
            let start = normalised.map[anchor.position]
            let end = i + 1 < clean.count && clean[i + 1].position < normalised.map.count
                ? normalised.map[clean[i + 1].position]
                : transcript.endIndex
            let slice = transcript[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            if !slice.isEmpty {
                slices[anchor.goalIndex] = slice
            }
        }
        return slices
    }

    /// No client profile to anchor on, so goals are discovered freehand from
    /// the transcript instead of checked off a known list.
    private static func generateGoalFocusedFreeform(
        _ transcript: String,
        tone: NoteTone,
        clientContext: ClientContext?
    ) async throws -> GoalFocusedNote {
        let listing = try await generate(
            GoalListing.self,
            source: transcript,
            request: "Split this dictation into the goals the clinician worked on.",
            reference: clientReference(clientContext),
            instructions: goalListingInstructions(),
            maximumResponseTokens: TokenBudget.goalListing
        )

        guard listing.hasSufficientContent else {
            return GoalFocusedNote(
                hasSufficientContent: false,
                insufficientContentReason: listing.insufficientContentReason ?? "",
                sessionObservations: "",
                goals: []
            )
        }

        var goals: [GeneratedGoal] = []
        for stub in listing.goals {
            let detail = try await generate(
                GoalDetail.self,
                source: transcript,
                request: "Write up only this goal: \"\(stub.goal)\". The transcript covers other goals too — ignore everything not about this one.",
                reference: nameOnlyReference(clientContext),
                instructions: goalDetailInstructions(tone: tone),
                maximumResponseTokens: TokenBudget.goalDetail
            )

            var observations = corrected(detail.observations)
            if isGoalEcho(observations, goal: stub.goal) {
                observations = ""
            }

            goals.append(GeneratedGoal(
                goal: corrected(stub.goal),
                activities: corrected(stub.activities),
                observations: observations,
                nextSteps: corrected(detail.nextSteps)
            ))
        }

        return GoalFocusedNote(
            hasSufficientContent: true,
            insufficientContentReason: "",
            sessionObservations: "",
            goals: goals
        )
    }

    // MARK: - Deterministic post-processing
    //
    // Fixes that prompting has repeatedly failed to deliver. String work is
    // free and cannot regress, so it lives here rather than in the prompts.

    /// Speech-recognition errors this dictation domain hits constantly.
    /// "pier" survived four prompt revisions; code does not forget.
    private static let speechCorrections: [(pattern: String, replacement: String)] = [
        ("\\bpier\\b", "peer"),
        ("\\bPier\\b", "Peer"),
        ("\\bpiers\\b", "peers"),
        ("\\bPiers\\b", "peers"),
        ("was said back", "was sent back"),
    ]

    private static func corrected(_ text: String) -> String {
        var result = text
        for correction in speechCorrections {
            result = result.replacingOccurrences(
                of: correction.pattern,
                with: correction.replacement,
                options: .regularExpression
            )
        }
        return result
    }

    /// True when the observations are just the goal statement read back — the
    /// model's habit when its extract held nothing observational.
    private static func isGoalEcho(_ observations: String, goal: String) -> Bool {
        let observed = normalise(observations)
        let goalText = normalise(goal)
        guard !observed.isEmpty, !goalText.isEmpty else { return false }
        return observed == goalText || goalText.contains(observed)
    }

    /// Backstop for the leftover-observations pass: drops any sentence that
    /// heavily overlaps a goal's own generated text, and collapses exact
    /// repeats — a cheap net under the "already written up" instruction for
    /// when the model restates a goal anyway, or loops on one sentence.
    private static func stripDuplicateContent(_ text: String, goals: [GeneratedGoal]) -> String {
        let goalWordSets: [Set<String>] = goals.map { goal in
            let combined = [goal.activities, goal.observations, goal.nextSteps].joined(separator: " ")
            return Set(normalise(combined).split(separator: " ").map(String.init))
        }

        var seenSentences = Set<String>()
        var kept: [String] = []

        for rawSentence in text.split(separator: ".") {
            let sentence = rawSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }

            let normalisedSentence = normalise(sentence)
            guard seenSentences.insert(normalisedSentence).inserted else { continue }

            let words = normalisedSentence.split(separator: " ").map(String.init)
            let sentenceWords = Set(words)
            let overlapsAGoal = words.count >= 4 && goalWordSets.contains { goalWords in
                Double(sentenceWords.intersection(goalWords).count) / Double(sentenceWords.count) >= 0.6
            }

            if !overlapsAGoal {
                kept.append(sentence)
            }
        }

        guard !kept.isEmpty else { return "" }
        return kept.joined(separator: ". ") + "."
    }

    // MARK: - Transcript normalisation

    /// Lowercased, punctuation-free version of the text. The model reproduces
    /// wording far more reliably than punctuation, so goal-echo comparison
    /// happens on the normalised form.
    private static func normalise(_ text: String) -> String {
        var output = ""
        var lastWasSpace = true

        for character in text {
            if character.isLetter || character.isNumber {
                output += String(character).lowercased()
                lastWasSpace = false
            } else if !lastWasSpace {
                output.append(" ")
                lastWasSpace = true
            }
        }

        return output
    }

    /// Same normalisation as above, but keeping a map from each normalised
    /// character back to its index in the original — needed to turn a match
    /// found in the normalised text back into a cut point in the real
    /// transcript for slicing.
    private static func normaliseWithMap(_ text: String) -> (text: String, map: [String.Index]) {
        var output = ""
        var map: [String.Index] = []
        var lastWasSpace = true
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character.isLetter || character.isNumber {
                for scalar in String(character).lowercased() {
                    output.append(scalar)
                    map.append(index)
                }
                lastWasSpace = false
            } else if !lastWasSpace {
                output.append(" ")
                map.append(index)
                lastWasSpace = true
            }
            index = text.index(after: index)
        }

        return (output, map)
    }

    /// Finds an anchor phrase's offset in already-normalised text, sliding the
    /// window along the anchor as well as shortening it. A dropped or altered
    /// leading word ("the 3rd goal" dictated, "the third goal" reported back)
    /// then still resolves on a later run of words, at the cost of a few
    /// words of signpost text off the front of the slice rather than losing
    /// the whole section.
    private static func locateOffset(_ anchor: String, in normalisedText: String) -> Int? {
        let words = normalise(anchor).split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }

        for start in 0...(words.count - 3) {
            let longest = min(words.count - start, 6)
            guard longest >= 3 else { continue }
            for length in stride(from: longest, through: 3, by: -1) {
                let phrase = words[start..<(start + length)].joined(separator: " ")
                guard let range = normalisedText.range(of: phrase) else { continue }
                return normalisedText.distance(from: normalisedText.startIndex, to: range.lowerBound)
            }
        }
        return nil
    }

    // MARK: - Core generation

    private static func validate(_ transcript: String) throws -> String {
        try ensureModelAvailable()
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NoteGenerationError.emptyTranscript }
        return trimmed
    }

    /// `source` is the text the pass may draw on — the whole dictation.
    private static func generate<Output: Generable>(
        _ type: Output.Type,
        source: String,
        request: String,
        reference: String?,
        instructions: Instructions,
        maximumResponseTokens: Int
    ) async throws -> Output {
        let session = LanguageModelSession(instructions: instructions)

        var prompt = request
        if let reference {
            prompt += "\n\n\(reference)"
        }
        prompt += "\n\nTRANSCRIPT (the only source):\n\(source)"

        let options = GenerationOptions(
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )

        do {
            let response = try await session.respond(to: prompt, generating: Output.self, options: options)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw map(error)
        }
    }

    /// Verify the on-device foundation model can actually run before we
    /// build a session, so the UI can show an actionable message.
    private static func ensureModelAvailable() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                throw NoteGenerationError.deviceNotEligible
            case .appleIntelligenceNotEnabled:
                throw NoteGenerationError.appleIntelligenceNotEnabled
            case .modelNotReady:
                throw NoteGenerationError.modelNotReady
            @unknown default:
                throw NoteGenerationError.generationFailed("The on-device model is unavailable.")
            }
        }
    }

    private static func map(_ error: LanguageModelSession.GenerationError) -> NoteGenerationError {
        switch error {
        case .exceededContextWindowSize:
            return .transcriptTooLong
        case .guardrailViolation:
            return .contentFlagged
        case .assetsUnavailable:
            return .modelNotReady
        default:
            return .generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Reference material (prompt side)

    private static func clientReference(_ context: ClientContext?) -> String? {
        guard let context, context.hasProfileContent else { return nil }

        var block = "CLIENT (background only, not evidence)"

        let name = context.displayName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            block += "\nName: \(name) — use this spelling."
        }

        if !context.goals.isEmpty {
            let list = context.goals.enumerated().map { index, goal -> String in
                let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let details = goal.details.trimmingCharacters(in: .whitespacesAndNewlines)
                return details.isEmpty ? "\(index + 1). \(title)" : "\(index + 1). \(title) — \(details)"
            }.joined(separator: "\n")

            block += """


                Goals on file:
                \(list)

                These were set at an earlier date. They are NOT a record of today. \
                Use this wording where the dictation covers one of them. Any number in \
                the wording is a target, never a result — DO NOT report one as measured \
                today. DO NOT list a goal from this file unless the dictation shows it \
                was worked on today.
                """
        }

        return block
    }

    private static func nameOnlyReference(_ context: ClientContext?) -> String? {
        guard let context else { return nil }
        let name = context.displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return "CLIENT NAME: \(name) — use this spelling."
    }

    /// Reference for a single documented goal's write-up pass — only that
    /// goal's own title and details, not the client's full goal list, so a
    /// neighbouring goal's wording cannot leak into this one.
    private static func singleGoalReference(_ context: ClientContext, goal: GoalContext) -> String {
        var block = "CLIENT (background only, not evidence)"

        let name = context.displayName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            block += "\nName: \(name) — use this spelling."
        }

        let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = goal.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalLine = details.isEmpty ? title : "\(title) — \(details)"

        block += """


            The one documented goal you are writing up:
            \(goalLine)

            This was set at an earlier date. It is NOT a record of today. Any number in \
            the wording is a target, never a result — DO NOT report one as measured today.
            """

        return block
    }

    /// What the per-goal passes actually produced, for the leftover-content
    /// pass to diff against. Concrete generated text, not the abstract goal
    /// list — the model needs something to compare against, not just a rule
    /// to remember.
    private static func coveredGoalsReference(_ goals: [GeneratedGoal]) -> String {
        guard !goals.isEmpty else {
            return "ALREADY WRITTEN UP: none of the client's documented goals were addressed today."
        }

        let entries = goals.map { goal -> String in
            var lines = ["Goal: \(goal.goal)"]
            if !goal.activities.isEmpty { lines.append("Activities: \(goal.activities)") }
            if !goal.observations.isEmpty { lines.append("Observations: \(goal.observations)") }
            if !goal.nextSteps.isEmpty { lines.append("Next steps: \(goal.nextSteps)") }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")

        return """
            ALREADY WRITTEN UP (do not repeat or rephrase any of this):
            \(entries)
            """
    }

    // MARK: - Instructions
    //
    // Short commands, not essays. Field-level rules live in the `@Guide`
    // descriptions and are deliberately not repeated here.

    private static let assistantPreamble = """
        You turn an allied health clinician's dictated session summary into a \
        structured draft note. The clinician reviews and signs it.
        """

    private static let coreRules = """
        DO NOT write anything the clinician did not say.
        DO NOT invent numbers, durations or prompt levels.
        DO NOT say what the client felt, understood or intended.
        DO NOT say a goal was met unless the clinician said so.
        Leave a field empty rather than guessing.
        Fix obvious speech errors: "pier" and "Piers" mean "peer" and "peers".
        Cut filler and the clinician's asides such as "so that was good to see".
        """

    private static let soapSectionSplit = "Subjective is what people reported; Objective is what was done and seen."

    private static let dapSectionSplit = "Data holds everything factual, reported and observed alike."

    private static func factualInstructions(tone: NoteTone, sectionSplit: String) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            Extract the facts. Conclusions and plans are handled separately — leave them out.
            \(sectionSplit)

            \(coreRules)

            Style: \(tone.promptText)
            """)
    }

    private static func interpretiveInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            Extract only the clinician's own conclusions and plan. The facts are handled separately.

            \(coreRules)

            Style: \(tone.promptText)
            """)
    }

    /// Only used when the client has no documented goals to anchor on.
    private static func goalListingInstructions() -> Instructions {
        Instructions("""
            \(assistantPreamble)

            List the goals the clinician worked on during this session. For each one, \
            give the goal and the activities.

            The clinician signposts each goal — "his goal of...", "the next goal is...", \
            "the third goal we focussed on". Use those signposts to find the goals.

            A goal is something worked on TODAY. What the clinician plans for next time \
            is not a goal.

            \(coreRules)
            """)
    }

    /// Only used when the client has no documented goals to anchor on.
    private static func goalDetailInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            The transcript below covers the whole session, likely several goals. Write up \
            ONLY the one goal named in the request. Do not let another goal's activities, \
            observations or plan appear in your answer — if the transcript covers other \
            goals, ignore that part of it entirely.

            \(coreRules)

            Style: \(tone.promptText)
            """)
    }

    private static func sessionGateInstructions() -> Instructions {
        Instructions("""
            \(assistantPreamble)

            Judge whether this transcript is a real therapy session with clinical \
            content, or a test recording, small talk, or chatter about the app.
            """)
    }

    private static func goalAnchorInstructions() -> Instructions {
        Instructions("""
            \(assistantPreamble)

            The CLIENT block below lists the client's documented goals, in order. For \
            each one, find where its discussion begins in today's transcript, if it was \
            addressed today. Give one entry per goal, in the same order as the list, \
            including an empty entry for a goal that was not addressed.

            The clinician often signposts a goal — "his goal of...", "the next goal is...", \
            "the third goal we focussed on" — but not always; some sessions move straight \
            into a goal's activities without naming it first. If you cannot find a clear \
            starting point for a goal you believe was addressed, leave its entry empty \
            rather than guessing.
            """)
    }

    private static func goalWriteUpInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            The transcript below may cover this goal alone, or the whole session — the \
            CLIENT block names ONE specific documented goal, and it is the only one you \
            write up regardless of how much of the session the transcript covers. If the \
            transcript does not show this specific goal being worked on today, leave \
            activities, observations and next steps all empty. Do not describe another \
            goal's activities here, and do not invent activity for a goal that was not \
            addressed today.

            If the transcript describes more than one relevant moment for this goal, \
            include all of them in observations, not just the clearest one. If the \
            clinician proposed a specific phrase or technique to try next time, keep it \
            in next steps rather than just the gist.

            \(coreRules)

            Style: \(tone.promptText)
            """)
    }

    private static func leftoverObservationsInstructions(tone: NoteTone) -> Instructions {
        Instructions("""
            \(assistantPreamble)

            The reference below shows what has already been written up from today's \
            session, goal by goal. Your only job is to report anything else in the \
            transcript that ISN'T already covered there — do not restate, rephrase or \
            summarise any of it again, even briefly. Leave your answer empty if there is \
            nothing left to add.

            A stated plan for next time is not something that happened today — do not \
            report it as an observation here or anywhere.

            \(coreRules)

            Style: \(tone.promptText)
            """)
    }
}
