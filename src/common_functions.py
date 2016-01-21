import os
import sys
import random
import tempfile
import string


class TemporaryFilePath(object):
    """
    Generates a path pointing to a temporary file. Replaces TemporaryFile in tempfile, which annoyingly wants to
    return a open handle. This is not useful to me.
    """
    def __init__(self, prefix='tmp', path=None):
        if path is None:
            self.path = tempfile._get_default_tempdir()  # let tempfile do the work
        else:
            self.path = path
        self.name = ''.join([prefix, get_random_chars()])
        self.file_path = os.path.join(self.path, self.name)

    def __enter__(self):
        return self.file_path

    def __exit__(self, type, value, traceback):
        try:
            os.remove(self.file_path)
        except OSError:
            pass


def get_random_chars(n=10, chars=string.ascii_uppercase + string.digits):
    """
    Get n random characters from the set chars.
    """
    return ''.join(random.SystemRandom().choice(chars) for _ in range(n))
