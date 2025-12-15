args@{pkgs, disk, safeProductName, updateUrl, kioskUrl, version, ...}:
with builtins;
with pkgs.lib;
let
    overlayPath = "/tmp/playos-test-disk-overlay.qcow2";
    # fileFilter is recursive, so tests can in theory be in subfolders
    testFiles = fileset.fileFilter (file: file.hasExt "nix") ./tests;
    testPackages = listToAttrs (map
        (file: {
            name = strings.removePrefix ((toString ./tests) + "/") (toString file);
            value = pkgs.callPackage file (args // { inherit overlayPath; });
        })
        (fileset.toList testFiles)
    );
    testCases = driverAttr:
        attrsets.mapAttrs'
            (name: p: nameValuePair
                ((strings.removeSuffix ".nix" name))
                (p."${driverAttr}" + "/bin/nixos-test-driver")
            )
            testPackages;
    testCasesInteractive = testCases "driverInteractive";
    testCasesNormal = testCases "driver";
    runAndSave = pkgs.writeShellScript "run-and-save" ''
        set -euo pipefail
        ansi2txt="${pkgs.colorized-logs}/bin/ansi2txt"
        script="$1"
        outDir="$2"
        status=0
        startTime=$(date +%s)
        ($script 2>&1 | tee >($ansi2txt > $outDir/logs.txt)) || status=$?
        endTime=$(date +%s)
        echo -n "$status" > $outDir/status
        echo -n "$((endTime - startTime))" > $outDir/duration
    '';
    genReport = pkgs.writers.writePython3 "gen-report"
        { libraries = with pkgs.python3Packages; [ colorama ];
          flakeIgnore = [ "E731" "E501" "E741" ];
        }
        (readFile ./gen-report.py);
in
    {
        tests = pkgs.linkFarm "tests" testCasesNormal;
        interactive = pkgs.linkFarm "interactive" testCasesInteractive;
        run = pkgs.runCommand "run-e2e-tests"
            { buildInputs = with pkgs; [ ncurses ]; }
            ''
            set -euo pipefail
            mkdir -p $out

            ${strings.toShellVar "tests" testCasesNormal}
            tput="tput -T ansi"

            isSuccess() {
                local outDir="$1"
                return $(cat $outDir/status)
            }
            print_bold() {
                $tput bold; echo "$1"; $tput sgr0
            }
            text_green() {
                $tput setaf 2; echo -n "$1"; $tput sgr0
            }
            text_red() {
                $tput setaf 1; echo -n "$1"; $tput sgr0
            }

            numFailed=0

            # Run tests
            for testCase in "''${!tests[@]}"; do
                outDir=$out/$testCase
                mkdir -p $outDir
                print_bold "===== Running e2e test $testCase ..."
                ${runAndSave} "''${tests[$testCase]}" "$outDir"
                if isSuccess $outDir; then
                    print_bold "===== Test $testCase $(text_green 'succeeded ✓')"
                else
                    numFailed=$((numFailed+1))
                    print_bold "===== Test $testCase $(text_red 'failed ✗')"
                fi
            done

            ${genReport} $out
            ${genReport} --format markdown $out > $out/test-report.md

            echo -n "$numFailed" > $out/status
        '';
    }
