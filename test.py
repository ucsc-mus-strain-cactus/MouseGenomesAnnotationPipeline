import argparse

parent_parser = argparse.ArgumentParser()
subparsers = parent_parser.add_subparsers(title="Modes", description="Execution Modes", dest="mode")
tm_parser = subparsers.add_parser('transMap')
ref_parser = subparsers.add_parser('reference')
aug_parser = subparsers.add_parser('augustus')

print parent_parser.parse_args()