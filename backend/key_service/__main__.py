import argparse
import json
import sys

from .store import Store


def main():
    parser = argparse.ArgumentParser(prog="key_service")
    parser.add_argument("--data", default="var")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("init")
    register = commands.add_parser("register")
    register.add_argument("application")
    register.add_argument("script")
    register.add_argument("--name", default="Kinoue")
    issue = commands.add_parser("issue")
    issue.add_argument("application")
    issue.add_argument("--days", type=int, default=30)
    for name in ("revoke", "reset-device"):
        command = commands.add_parser(name)
        command.add_argument("license_id")
    args = parser.parse_args()
    try:
        if args.command == "init":
            Store.initialize(args.data)
        store = Store(args.data)
        if args.command == "register":
            store.register(args.application, args.name, args.script)
        elif args.command == "issue":
            print(json.dumps(store.issue(args.application, args.days)))
        elif args.command == "revoke" and not store.revoke(args.license_id):
            raise ValueError("License not found")
        elif args.command == "reset-device" and not store.reset_device(args.license_id):
            raise ValueError("License not found")
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
