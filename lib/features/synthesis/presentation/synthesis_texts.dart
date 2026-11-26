/// The one wording for how many thoughts are waiting for Synthesis, with correct singular and plural.
/// Shared by the Synthesis banner, the Pipeline HUD and Settings.
String describeThoughtsReadyForSynthesis(int count) =>
    '$count ${count == 1 ? 'thought' : 'thoughts'} ready for Synthesis';
