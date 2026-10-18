"""Exercise the installer with real local Git repositories; no network or runners."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "install-workflows.sh"
REPO = "example-org/.github"
FILES = ("cpp-build.yml", "cpp-coverage.yml", "cpp-release.yml")


class InstallWorkflowsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="workflow installer ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "template source"
        self.target = self.root / "business repo"
        self.output = self.target / ".github" / "workflows"
        self.installer = INSTALLER
        self.env = os.environ.copy()
        # Isolate developer Git configuration and redirect both transports to a
        # local fixture. Fetch/render behavior is real, credentials are unused.
        for key in list(self.env):
            if key.startswith("GIT_"):
                del self.env[key]
        self.env.update({
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": str(self.root / "gitconfig"),
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_AUTHOR_NAME": "Installer Test",
            "GIT_AUTHOR_EMAIL": "installer@example.invalid",
            "GIT_COMMITTER_NAME": "Installer Test",
            "GIT_COMMITTER_EMAIL": "installer@example.invalid",
            "TMPDIR": str(self.root),
        })
        self.source.mkdir()
        self.target.mkdir()
        for directory in (self.source, self.target):
            self.git(directory, "init", "--quiet", "--initial-branch=main")
        shutil.copytree(ROOT / "workflow-templates", self.source / "workflow-templates")
        shutil.copytree(ROOT / ".github" / "workflows", self.source / ".github" / "workflows")
        self.commit_source()
        (self.target / "README.md").write_text("Business project\n")
        self.git(self.target, "add", "README.md")
        self.git(self.target, "commit", "--quiet", "-m", "Initial business source")
        self.original_head = self.git(self.target, "rev-parse", "HEAD").stdout.strip()
        for url in (f"git@github.com:{REPO}.git", f"https://github.com/{REPO}.git"):
            self.git(self.target, "config", "--global", "--add",
                     f"url.{self.source}.insteadOf", url)

    def git(self, cwd, *args):
        return subprocess.run(["git", *args], cwd=cwd, env=self.env,
                              text=True, capture_output=True, check=True)

    def commit_source(self):
        self.git(self.source, "add", "--all")
        self.git(self.source, "commit", "--quiet", "-m", "Template fixture")

    def install(self, *args, cwd=None, ok=True):
        result = subprocess.run(
            ["bash", str(self.installer), "--repo", REPO, *args],
            cwd=cwd or self.target, env=self.env, text=True, capture_output=True,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_install_from_subdirectory_preserves_expressions_and_permissions(self):
        subdirectory = self.target / "src"
        subdirectory.mkdir()
        self.install("--branch", "main", cwd=subdirectory)
        self.assertEqual(sorted(path.name for path in self.output.iterdir()), sorted(FILES))
        for name in FILES:
            original = (self.source / "workflow-templates" / name).read_text()
            expected = original.replace("COMPANY_ORG/.github", REPO).replace("[master]", "['main']")
            self.assertEqual((self.output / name).read_text(), expected)
        self.assertEqual(self.git(self.target, "rev-parse", "HEAD").stdout.strip(), self.original_head)
        self.assertEqual(self.git(self.target, "diff", "--cached", "--name-only").stdout, "")
        self.assertFalse((self.target / "actions").exists())

    def test_repeat_install_is_noop_and_preserves_unrelated_files(self):
        self.install()
        before = {name: (self.output / name).stat().st_mtime_ns for name in FILES}
        unrelated = self.output / "existing-ci.yml"
        unrelated.write_text("name: Existing\n")
        result = self.install()
        self.assertEqual(result.stdout.count("Skipped (identical)"), 3)
        self.assertEqual(before, {name: (self.output / name).stat().st_mtime_ns for name in FILES})
        self.assertEqual(unrelated.read_text(), "name: Existing\n")

    def test_standalone_script_needs_no_adjacent_repository_files(self):
        self.installer = self.root / "standalone" / "install-workflows.sh"
        self.installer.parent.mkdir()
        shutil.copy2(INSTALLER, self.installer)
        self.install()
        self.assertEqual(sorted(path.name for path in self.output.iterdir()), sorted(FILES))

    def test_template_repository_can_have_a_different_name(self):
        repository = "example-org/cicd_template"
        self.git(self.target, "config", "--global", "--add",
                 f"url.{self.source}.insteadOf", f"git@github.com:{repository}.git")
        self.install("--repo", repository)
        for name in FILES:
            self.assertIn(f"uses: {repository}/.github/workflows/{name}@main",
                          (self.output / name).read_text())

    def test_conflict_in_last_file_prevents_all_installation(self):
        self.output.mkdir(parents=True)
        existing = self.output / "cpp-release.yml"
        existing.write_text("name: Customized release\n")
        result = self.install(ok=False)
        self.assertIn("File conflict", result.stderr)
        self.assertEqual(existing.read_text(), "name: Customized release\n")
        self.assertFalse((self.output / "cpp-build.yml").exists())
        self.assertFalse((self.output / "cpp-coverage.yml").exists())

    def test_preview_does_not_create_github_directory(self):
        result = self.install("--dry-run", "--branch", "main")
        self.assertIn(f"+    uses: {REPO}/.github/workflows/cpp-release.yml@main", result.stdout)
        self.assertFalse((self.target / ".github").exists())

    def test_preview_shows_conflict_without_overwriting(self):
        self.output.mkdir(parents=True)
        destination = self.output / "cpp-release.yml"
        destination.write_text("name: Customized release\n")
        result = self.install("--dry-run", ok=False)
        self.assertIn("-name: Customized release", result.stdout)
        self.assertEqual(destination.read_text(), "name: Customized release\n")
        self.assertFalse((self.output / "cpp-build.yml").exists())

    def test_https_transport_and_tag_reference(self):
        self.git(self.source, "tag", "releases/v1")
        self.install("--https", "--ref", "releases/v1")
        for name in FILES:
            self.assertIn(f"uses: {REPO}/.github/workflows/{name}@releases/v1",
                          (self.output / name).read_text())

    def test_commit_reference(self):
        sha = self.git(self.source, "rev-parse", "HEAD").stdout.strip()
        self.install("--ref", sha)
        self.assertIn(f"@{sha}", (self.output / "cpp-build.yml").read_text())

    def test_branch_with_yaml_characters_is_quoted(self):
        self.install("--branch", "release/o'hare&prod")
        self.assertIn("branches: ['release/o''hare&prod']", (self.output / "cpp-release.yml").read_text())
        self.assertIn("branches-ignore: ['release/o''hare&prod']", (self.output / "cpp-build.yml").read_text())

    def test_missing_last_template_prevents_partial_installation(self):
        (self.source / "workflow-templates" / "cpp-release.yml").unlink()
        self.commit_source()
        self.install(ok=False)
        self.assertFalse((self.target / ".github").exists())

    def test_missing_public_workflow_prevents_installation(self):
        (self.source / ".github" / "workflows" / "cpp-release.yml").unlink()
        self.commit_source()
        self.install(ok=False)
        self.assertFalse((self.target / ".github").exists())

    def test_unfamiliar_template_layout_prevents_installation(self):
        template = self.source / "workflow-templates" / "cpp-coverage.yml"
        template.write_text(template.read_text().replace("branches-ignore: [master]", "branches-ignore: [master, staging]"))
        self.commit_source()
        result = self.install(ok=False)
        self.assertIn("Unexpected template layout", result.stderr)
        self.assertFalse((self.target / ".github").exists())

    def test_unavailable_ref_prevents_installation(self):
        self.install("--ref", "missing-ref", ok=False)
        self.assertFalse((self.target / ".github").exists())

    def test_symlink_directory_is_rejected(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.target / ".github").symlink_to(outside, target_is_directory=True)
        self.install(ok=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_symlink_workflow_is_rejected_even_if_identical(self):
        self.install()
        destination = self.output / "cpp-release.yml"
        outside = self.root / "release.yml"
        destination.rename(outside)
        original = outside.read_bytes()
        destination.symlink_to(outside)
        self.install(ok=False)
        self.assertEqual(outside.read_bytes(), original)

    def test_outside_git_repository_is_rejected(self):
        self.install(cwd=self.root, ok=False)
        self.assertFalse((self.root / ".github").exists())

    def test_invalid_arguments_do_not_write_files(self):
        for args in (("--branch", "bad branch"), ("--ref", "bad@ref"),
                     ("--repo", "invalid"), ("--unknown",), ("--branch",)):
            with self.subTest(args=args):
                self.install(*args, ok=False)
                self.assertFalse((self.target / ".github").exists())


if __name__ == "__main__":
    unittest.main()
