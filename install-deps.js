
const fs = require("fs").promises;
const path = require("path");
const { exec } = require("child_process");
const { promisify } = require("util");

const execPromise = promisify(exec);

// Mapping of dependency manifest files to their installation commands
const PROJECT_CONFIG = {
    "package.json": "npm install",
    "requirements.txt": "pip install -r requirements.txt",
    "pyproject.toml": "pip install .",
    "Gemfile": "bundle install",
    "go.mod": "go mod download",
};

// Parse command-line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const isVerbose = args.includes("-v") || args.includes("--verbose");
const rootDir = args.find(arg => !arg.startsWith("--")) || ".";

async function installDependencies(dir) {
    if (isVerbose) {
        console.log(`Scanning directory: ${dir}`);
    }

    try {
        const entries = await fs.readdir(dir, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);

            if (entry.isDirectory()) {
                // Skip common dependency directories
                if (entry.name === "node_modules" || entry.name === ".venv" || entry.name === ".git") {
                    continue;
                }
                await installDependencies(fullPath);
            } else {
                const command = PROJECT_CONFIG[entry.name];
                if (command) {
                    console.log(`[INFO] Detected '${entry.name}' in '${dir}'`);

                    if (isDryRun) {
                        console.log(`[WARNING] DRY RUN: Would run '${command}' in '${dir}'`);
                        continue;
                    }

                    try {
                        console.log(`[INFO] Running '${command}' in '${dir}'`);
                        const { stdout, stderr } = await execPromise(command, { cwd: dir });
                        if (isVerbose && stdout) console.log(`[DEBUG] stdout: ${stdout}`);
                        if (stderr) console.error(`[ERROR] stderr: ${stderr}`);
                        console.log(`[INFO] Successfully installed dependencies for '${dir}'`);
                    } catch (error) {
                        console.error(`[ERROR] Failed to install dependencies in '${dir}'`);
                        console.error(`[ERROR] Command: ${error.cmd}`);
                        console.error(`[ERROR] Exit Code: ${error.code}`);
                        console.error(`[ERROR] Stderr: ${error.stderr}`);
                    }
                }
            }
        }
    } catch (error) {
        console.error(`[ERROR] Failed to read directory '${dir}': ${error.message}`);
    }
}

async function main() {
    console.log(`[INFO] Starting dependency scan in '${path.resolve(rootDir)}'`);
    if (isDryRun) {
        console.warn("[WARNING] Dry run mode is enabled. No packages will be installed.");
    }
    await installDependencies(rootDir);
}

main().catch(error => console.error(`[FATAL] An unexpected error occurred: ${error.message}`));
