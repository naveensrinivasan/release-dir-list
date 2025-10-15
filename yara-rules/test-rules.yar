rule Python_Executable_Check {
    meta:
        description = "Basic check for Python executable patterns in compressed archives"
        author = "POC Test Rule"
        date = "2024-10-15"

    strings:
        // Common Python patterns
        $python_magic = "#!/usr/bin/env python"
        $python3_magic = "#!/usr/bin/env python3"
        $python_interpreter = "python3"
        $python_version = "Python 3.14"

        // Executable patterns
        $elf_header = { 7F 45 4C 46 } // ELF magic bytes
        $shebang = { 23 21 } // #!

        // Suspicious patterns (for POC)
        $suspicious_1 = "rm -rf /"
        $suspicious_2 = "wget http://"

    condition:
        // Basic Python executable check - look for ELF or shebang with Python references
        ($elf_header at 0 or $shebang at 0) and
        ($python_magic or $python3_magic or $python_interpreter or $python_version) and
        not ($suspicious_1 or $suspicious_2)
}

rule Malware_Signature_Test {
    meta:
        description = "Test rule for detecting basic malware signatures"
        author = "POC Test Rule"
        date = "2024-10-15"
        severity = "high"

    strings:
        // Common malware patterns
        $backdoor = "backdoor"
        $trojan = "trojan"
        $virus = "virus"
        $worm = "worm"

        // Suspicious network patterns
        $suspicious_url = /https?:\/\/[a-zA-Z0-9\-\.]+\.(exe|dll|scr|com|pif)/

        // Known bad hashes (placeholder for POC)
        $bad_hash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    condition:
        any of them
}

rule Compressed_Archive_Check {
    meta:
        description = "Check compressed archives for suspicious content"
        author = "POC Test Rule"
        date = "2024-10-15"

    strings:
        // Archive headers
        $tar_header = { 75 73 74 61 72 } // "ustar" in tar
        $xz_header = { FD 37 7A 58 5A 00 } // XZ magic bytes
        $gzip_header = { 1F 8B } // GZIP magic bytes

        // Nested executables
        $nested_exe = "MZ" // DOS executable

        // Suspicious filenames
        $suspicious_file = /(evil|malware|trojan|virus|worm)\.(exe|dll|scr)/

    condition:
        $xz_header at 0 and // XZ archive
        ($nested_exe or $suspicious_file)
}
