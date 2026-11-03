import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProtocolRegistrationTests(unittest.TestCase):
    def test_windows_installer_registers_both_url_protocol_aliases(self):
        script = (ROOT / "acessa" / "Instalar-AcessaRemoto.ps1").read_text(encoding="utf-8")

        self.assertIn('Register-UrlProtocol -Scheme "acessaremoto"', script)
        self.assertIn('Register-UrlProtocol -Scheme "rustdesk"', script)
        self.assertIn('"URL Protocol"', script)
        self.assertIn('AcessaRemoto.exe', script)

    def test_windows_repair_script_fixes_existing_install_without_password_change(self):
        repair_path = ROOT / "acessa" / "Corrigir-Abertura-Painel.ps1"
        self.assertTrue(repair_path.exists(), "script de reparo ainda não existe")
        repair = repair_path.read_text(encoding="utf-8")

        self.assertIn('Join-Path $env:ProgramFiles "AcessaRemoto\\AcessaRemoto.exe"', repair)
        self.assertIn('Register-UrlProtocol -Scheme "acessaremoto"', repair)
        self.assertIn('Register-UrlProtocol -Scheme "rustdesk"', repair)
        self.assertNotIn("--password", repair)

    def test_linux_desktop_handler_accepts_both_url_protocol_aliases(self):
        desktop = (ROOT / "res" / "rustdesk-link.desktop").read_text(encoding="utf-8")

        self.assertIn("Name=Acessa Remoto", desktop)
        self.assertIn("MimeType=x-scheme-handler/acessaremoto;x-scheme-handler/rustdesk;", desktop)
        self.assertIn("Exec=rustdesk %u", desktop)

    def test_linux_main_desktop_uses_acessa_remoto_brand(self):
        desktop = (ROOT / "res" / "rustdesk.desktop").read_text(encoding="utf-8")

        self.assertIn("Name=Acessa Remoto", desktop)
        self.assertIn("GenericName=Acesso remoto", desktop)

    def test_linux_deb_uses_acessa_package_identity_and_refreshes_desktop_handlers(self):
        build_script = (ROOT / "build.py").read_text(encoding="utf-8")
        postinst = (ROOT / "res" / "DEBIAN" / "postinst").read_text(encoding="utf-8")

        self.assertIn("Package: acessaremoto", build_script)
        self.assertIn("Conflicts: rustdesk", build_script)
        self.assertIn("Replaces: rustdesk", build_script)
        self.assertIn("Provides: rustdesk", build_script)
        self.assertIn("update-desktop-database", postinst)


if __name__ == "__main__":
    unittest.main()
