"""
Main set of classes for comparativeAnnotator pipeline. Broken down into the categories:
0. input files
1. genome files
2. chaining files
3. transMap files
4. comparativeAnnotator files
5. metrics
"""
import luigi
import sys
import os
import itertools
import subprocess
from pycbio.sys.procOps import runProc, callProc
from pycbio.sys.fileOps import ensureDir
from lib.ucsc_chain_net import chainNetStartup
from lib.jobtree_luigi import make_jobtree_dir
from lib.parsing import HashableNamespace


########################################################################################################################
########################################################################################################################
## Abstract classes and helper functions
########################################################################################################################
########################################################################################################################


class AbstractAtomicFileTask(luigi.Task):
    """
    Abstract Task for single files.
    """
    cfg = luigi.Parameter()
    target_file = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.target_file)

    def run_cmd(self, cmd):
        """
        Run a external command that will produce the output file for this task to stdout. Capture this to the file.
        """
        out_h = self.output().open('w')  # luigi localTargets guarantee atomicity if used as a handle 
        runProc(cmd, stdout=out_h)
        out_h.close()

    def atomic_install(self, target, force_copy=False):
        """
        Atomically install a given target to this task's output. If we cross filesystem boundaries, we need to copy
        before renaming. Set force_copy to skip this checking and just copy the file.
        """
        output = self.output()
        output.makedirs()
        source_dir = os.path.dirname(os.path.abspath(output.path))
        target_dir = os.path.dirname(os.path.abspath(target.path))
        # if we are moving across filesystem barriers, then we have to copy. Otherwise, we can just move.
        if force_copy is True or os.stat(source_dir).st_dev != os.stat(target_dir).st_dev:
            target.copy(output.path)
        else:
            target.move(output.path)


class AbstractAtomicManyFileTask(luigi.Task):
    """
    Abstract Task for many files. Used if a program outputs multiple files or cannot write to stdout.
    """
    cfg = luigi.Parameter()
    target_files = luigi.Parameter()

    def output(self):
        return (luigi.LocalTarget(x) for x in self.target_files)

    def get_tmp(self):
        return luigi.LocalTarget(is_tmp=True)

    def run_cmd(self, cmd, tmp_files):
        """
        Run a external command that will produce the output file for this task to many files.
        These files will be atomically installed using functionality in luigi.localTarget
        Assumes that tmp_files are in the same order as in target_files.
        """
        callProc(cmd)
        for tmp_f, f in zip(*(tmp_files, self.output())):
            f.makedirs()
            source_dir = os.path.dirname(os.path.abspath(tmp_f.path))
            target_dir = os.path.dirname(os.path.abspath(f.path))
            if os.stat(source_dir).st_dev != os.stat(target_dir).st_dev:
                tmp_f.copy(f.path)
            else:
                tmp_f.move(f.path)
