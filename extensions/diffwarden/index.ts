import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(extensionDir, "..", "..");
const skillPath = join(repoRoot, "skills", "diffwarden", "SKILL.md");

const completionCandidates = [
	"review",
	"loop",
	"status",
	"comment",
	"help",
	"workspace",
	"local",
	"staged",
	"worktree",
	"current",
	"--mvp",
	"--security",
	"--orchestrate",
	"--verbose",
	"--commit",
	"--push",
	"--as-code",
	"--as-plan",
	"--web",
	"--research",
	"--reply",
	"--resolve",
	"--delegate",
	"--dry-run",
	"--max",
	"--review-model",
	"--fix-code-model",
	"--fix-text-model",
	"--go",
	"--lang",
	"go",
];

function completeArgs(prefix: string) {
	const leading = prefix.match(/^\s*/)?.[0] ?? "";
	const body = prefix.slice(leading.length);
	const tokens = body.length > 0 ? body.split(/\s+/) : [];
	const current = body.endsWith(" ") ? "" : (tokens.pop() ?? "");
	const base = leading + (body.endsWith(" ") ? body : tokens.length > 0 ? `${tokens.join(" ")} ` : "");
	const matches = completionCandidates.filter((candidate) => candidate.startsWith(current));

	return matches.length > 0
		? matches.slice(0, 20).map((candidate) => ({ value: `${base}${candidate}`, label: candidate }))
		: null;
}

function commandDescription(name: string) {
	return `${name} <subcommand> [target] [flags] — run Diffwarden via /skill:diffwarden`;
}

export default function diffwardenExtension(pi: ExtensionAPI) {
	pi.on("resources_discover", () => ({
		skillPaths: [skillPath],
	}));

	const invoke = (args: string, ctx: ExtensionCommandContext) => {
		const normalizedArgs = args.trim() || "help";
		const prompt = `/skill:diffwarden ${normalizedArgs}`;

		if (ctx.hasUI) {
			ctx.ui.notify(`Diffwarden: ${normalizedArgs}`, "info");
		}

		if (ctx.isIdle()) {
			pi.sendUserMessage(prompt);
		} else {
			pi.sendUserMessage(prompt, { deliverAs: "followUp" });
		}
	};

	for (const name of ["dw", "diffwarden"]) {
		pi.registerCommand(name, {
			description: commandDescription(name),
			getArgumentCompletions: completeArgs,
			handler: async (args, ctx) => invoke(args, ctx),
		});
	}
}
