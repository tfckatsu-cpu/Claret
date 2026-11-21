# How Claret uses AI

The developer describes the expected behavior and tests the result in FAF. The assistant traces the relevant code, proposes or implements a focused change, and checks it against the local tests and available logs. The [knowledge base](KnowledgeBase/README.md) gives a new chat enough context to work without replaying the project history.

## Start a task

1. State the symptom or desired behavior, the affected mod, and the game scenario. Include the build identifier when available.
2. Read the knowledge base’s entry point and the one or two relevant topic pages. Verify version-sensitive facts against the installed game or current code.
3. Inspect the real entry point and keep the edit within the requested behavior. Preserve saved data and binding IDs.
4. Run focused tests, then verify rendering, input, or command behavior in FAF. Keep the observed result and open questions separate in the report.

## Examples from the project

| Task | Local result | In-game evidence |
|---|---|---|
| Diagnose startup freezes | A model of MAUI reproduced a circular layout dependency in starting-position markers. The patch initialized their geometry before rendering. | The startup log still showed 48 layout warnings after the patch. The source of the remaining warnings and the cause of the freezes were unresolved. |
| Improve engineer markers under load | A 600-engineer fixture checked that the optimized overlay bounded position queries and stopped querying fully faded markers. | The user confirmed the build generally. The project had no frame-time measurements to quantify the improvement. |
| Show readable build-key labels | Tests verified that a construction tile displayed one physical key and used its color to convey the modifier. Full chords remained available in the label data. | The tests covered label generation and integration with the mock key-label hook. Visual confirmation required FAF. |

Use short, redacted extracts when sharing evidence. A build stamp, a test name, and the relevant warning are usually enough to document a result.
