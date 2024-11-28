import glob
from pathlib import Path
import argparse
import datetime
from colorama import Style, Fore
import html
import textwrap


def process_test_case(test_name, test_case_dir):
    with open(test_case_dir / "status", "r") as rf:
        status = int(rf.read().strip())
        success = status == 0

    with open(test_case_dir / "duration", "r") as rf:
        duration = int(rf.read().strip())

    result = {
        'name': test_name,
        'filepath': '/testing/end-to-end/tests/' + test_name + ".nix",
        'duration': duration,
        'success': success,
        'status': status,
    }
    if not success:
        with open(test_case_dir / "logs.txt", "r") as rf:
            logs = rf.readlines()
            result['last_logs'] = "".join(logs[-100:])

    return result


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('test_result_dir')
    parser.add_argument('--format',
                        choices=['terminal', 'markdown'],
                        default='terminal')
    return parser.parse_args()


_id = lambda x: x


def format_gen(full_report, bold_f=_id, ok_f=_id, fail_f=_id, log_f=_id):
    header = """## End-to-end test result summary:"""
    test_lines = []
    for t in full_report['tests']:
        if t['success']:
            outcome_str = ok_f("OK")
            maybe_logs = ""
        else:
            outcome_str = fail_f("FAIL")
            maybe_logs = " " + log_f(t['last_logs'])
        duration_str = str(datetime.timedelta(seconds=t['duration']))
        test_str = f"- {bold_f(t['name'])}: {outcome_str} (duration: {duration_str})"
        test_lines.append(test_str + maybe_logs)

    counts = full_report['counts']
    footer = "\n" + bold_f(f"Ran {counts['total']} tests, passed: {counts['passed']}, failed: {counts['failed']}")

    return "\n".join([header] + test_lines + [footer])


def format_markdown(full_report):
    bold_f = lambda s: f"**{s}**"
    ok_f = lambda s: f"{s} :heavy_check_mark:"
    fail_f = lambda s: f"{s} :x:"

    def log_f(logs):
        lines = html.escape(logs).splitlines()
        lines = [l if l.strip() else "<br/>" for l in lines]
        log_str = "\n".join(lines)
        return "\n" + textwrap.indent(f"""\
<details>
<summary>Last logs:</summary>
<pre>
{log_str}
</pre>
</details>""", 4 * ' ')

    return format_gen(full_report, bold_f, ok_f, fail_f, log_f)


def format_terminal(full_report):
    bold_f = lambda s: Style.BRIGHT + s + Style.RESET_ALL
    ok_f = lambda s: bold_f(f"{Fore.GREEN}{s} ✓{Fore.RESET}")
    fail_f = lambda s: f"{Fore.RED}{s} ✗{Fore.RESET}"
    log_f = lambda _: ""
    return format_gen(full_report, bold_f, ok_f, fail_f, log_f)


def print_report(full_report, format):
    if format == "terminal":
        s = format_terminal(full_report)
    elif format == "markdown":
        s = format_markdown(full_report)
    else:
        s = ""
        raise RuntimeError(f"Unknown format: {format}")

    print(s)


def main():
    opts = parse_args()
    test_case_reports = []
    failed = 0
    passed = 0

    glob_pat = opts.test_result_dir + "/**/status"
    for status in glob.glob(glob_pat, recursive=True):
        test_case_dir = Path(status).parent
        test_name = str(test_case_dir.relative_to(opts.test_result_dir))
        result = process_test_case(test_name, test_case_dir)
        test_case_reports.append(result)
        if result['success']:
            passed += 1
        else:
            failed += 1

    full_report = {
        'counts': {
            'total': passed + failed,
            'failed': failed,
            'passed': passed,
        },
        'tests': test_case_reports,
    }
    print_report(full_report, format=opts.format)


if __name__ == "__main__":
    main()
