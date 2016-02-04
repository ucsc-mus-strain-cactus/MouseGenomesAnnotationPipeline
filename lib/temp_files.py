"""
Temporary file operations.
"""
import os
import sys
import random
import tempfile
import string
import socket
import errno
import shutil
from pycbio.sys.fileOps import ensureDir as mkdir_p


__author__ = 'Ian Fiddes'


class TemporaryFilePath(object):
    """
    Generates a path pointing to a temporary file. Replaces TemporaryFile in tempfile, which annoyingly wants to
    return a open handle. This is not useful to me.
    """
    def __init__(self, prefix='tmp', base_dir=None):
        if base_dir is None:
            self.base_dir = tempfile._get_default_tempdir()  # let tempfile do the work
        else:
            self.base_dir = base_dir
            mkdir_p(base_dir)
        self.name = ''.join([prefix, get_random_string()])
        self.path = os.path.join(self.base_dir, self.name)

    def __enter__(self):
        return self.path

    def __exit__(self, type, value, traceback):
        os.remove(self.path)


class TemporaryDirectoryPath(object):
    """
    Generates a path pointing to a temporary directory.
    """
    def __init__(self, prefix='tmp', base_dir=None):
        if base_dir is None:
            self.path = tempfile._get_default_tempdir()  # let tempfile do the work
        else:
            self.path = os.path.join(base_dir, get_random_string())
        mkdir_p(self.path)

    def __enter__(self):
        return self.path

    def __exit__(self, type, value, traceback):
        shutil.rmtree(self.path)


def get_random_string(n=10, chars=string.ascii_uppercase + string.digits):
    """
    Get n random characters from the set chars.
    """
    return ''.join(random.SystemRandom().choice(chars) for _ in range(n))


def get_tmp_ext():
    """
    Get a temporary file extension to be used on shared filesystems.
    """
    return '.'.join(map(str, [socket.gethostname(), os.getppid(), 'tmp']))