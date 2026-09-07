import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "scripts" / "merge-env.py"


class MergeEnvTests(unittest.TestCase):
    def test_merges_rotated_duplicate_and_multiline_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "existing").write_text(
                'PROVISIONING_TOKEN_SECRET="old secret"\n'
                "APNS_KEY_ID=rotated-key\n"
                'APNS_AUTH_KEY_CONTENT="-----BEGIN PRIVATE KEY-----\nold-line\n-----END PRIVATE KEY-----"\n'
                "OTHER_SECRET='keep \"quoted\" and \\\\ slash'" + "\n"
                "LITERAL_BACKSLASH_N=old\\nvalue\n"
            )
            (root / "generated").write_text(
                'APNS_KEY_ID="new-key"\n'
                'APNS_AUTH_KEY_CONTENT="-----BEGIN PRIVATE KEY-----\nnew \"quoted\" line\\tail\n-----END PRIVATE KEY-----"\n'
            )
            output = root / "output"
            subprocess.run(["python3", str(SCRIPT), str(root / "existing"), str(root / "generated"), str(output)], check=True)
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
            text = output.read_text()
            self.assertEqual(text.count("APNS_KEY_ID="), 1)
            self.assertEqual(self.get(output, "APNS_KEY_ID"), "new-key")
            self.assertEqual(
                self.get(output, "APNS_AUTH_KEY_CONTENT"),
                "-----BEGIN PRIVATE KEY-----\nnew \"quoted\" line\\tail\n-----END PRIVATE KEY-----",
            )
            self.assertEqual(self.get(output, "PROVISIONING_TOKEN_SECRET"), "old secret")
            self.assertEqual(self.get(output, "OTHER_SECRET"), r'keep "quoted" and \\ slash')
            self.assertEqual(self.get(output, "LITERAL_BACKSLASH_N"), r'old\nvalue')

    def test_preserves_literal_backslash_and_terminal_backslash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = root / "existing"
            existing.write_text('LITERAL="old\\nvalue"\n' + 'TERMINAL="abc\\\\"\n')
            generated = root / "generated"
            generated.write_text("")
            output = root / "output"
            subprocess.run(["python3", str(SCRIPT), str(existing), str(generated), str(output)], check=True)
            self.assertEqual(self.get(output, "LITERAL"), r"old\nvalue")
            self.assertEqual(self.get(output, "TERMINAL"), "abc\\")

    def test_missing_local_values_preserve_remote_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = root / "existing"
            existing.write_text("APNS_KEY_ID=remote-key\nAPNS_TEAM_ID=remote-team\n")
            generated = root / "generated"
            generated.write_text("PUBLIC_BASE_URL=https://example.test\n")
            output = root / "output"
            subprocess.run(["python3", str(SCRIPT), str(existing), str(generated), str(output)], check=True)
            self.assertEqual(self.get(output, "APNS_KEY_ID"), "remote-key")
            self.assertEqual(self.get(output, "APNS_TEAM_ID"), "remote-team")

    def test_systemd_continuation_and_escaped_terminal_quote(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = root / "existing"
            existing.write_text('CONT="one\\\ntwo"\nESCAPED="literal\\"\n"\n')
            generated = root / "generated"
            generated.write_text("")
            output = root / "output"
            subprocess.run(["python3", str(SCRIPT), str(existing), str(generated), str(output)], check=True)
            self.assertEqual(self.get(output, "CONT"), "onetwo")
            self.assertEqual(self.get(output, "ESCAPED"), 'literal"\n')

    @staticmethod
    def get(path, key):
        return subprocess.check_output(["python3", str(SCRIPT), "--get", key, str(path)], text=True)


if __name__ == "__main__":
    unittest.main()
