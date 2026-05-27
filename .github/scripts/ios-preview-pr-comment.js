// Upserts the iOS Preview PR comment (TestFlight or simulator-only).
// Invoked from ios-preview.yml via actions/github-script.
//
// Env: PR_NUMBER, PREVIEW_MODE (testflight | simulator), BUILD_NUMBER (testflight only)

async function upsertPreviewComment({ github, context, body }) {
  const pr = Number(process.env.PR_NUMBER);
  const marker = "<!-- ios-preview-comment -->";
  const fullBody = `${marker}\n${body}`;

  const { data: comments } = await github.rest.issues.listComments({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: pr,
  });
  const existing = comments.find((c) => c.body?.includes(marker));

  if (existing) {
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: existing.id,
      body: fullBody,
    });
  } else {
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: pr,
      body: fullBody,
    });
  }
}

module.exports = async function iosPreviewPrComment({ github, context }) {
  const mode = process.env.PREVIEW_MODE;
  const build = process.env.BUILD_NUMBER;
  const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;

  if (mode === "simulator") {
    await upsertPreviewComment({
      github,
      context,
      body: [
        "### iOS Preview (unit tests only)",
        "",
        "PR has label `no-deploy` — ran `MusicWallTests` on the simulator and skipped TestFlight upload.",
        "",
        `[View workflow run](${runUrl})`,
      ].join("\n"),
    });
    return;
  }

  await upsertPreviewComment({
    github,
    context,
    body: [
      "### iOS Preview (TestFlight internal)",
      "",
      "_Marketing version may be auto-bumped above the live App Store version for upload — see Fastlane logs._",
      "",
      `Build number: **${build}**`,
      "",
      "Install from TestFlight when Apple finishes processing (usually 10–20 minutes).",
      "",
      `[View workflow run](${runUrl})`,
    ].join("\n"),
  });
};
