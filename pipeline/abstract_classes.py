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
import os
import pandas as pd
from pycbio.sys.procOps import runProc
from pycbio.sys.fileOps import ensureDir, rmTree
from pycbio.sys.sqliteOps import get_query_ids, open_database


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
        runProc(cmd)
        for tmp_f, f in zip(*(tmp_files, self.output())):
            f.makedirs()
            source_dir = os.path.dirname(os.path.abspath(tmp_f.path))
            target_dir = os.path.dirname(os.path.abspath(f.path))
            if os.stat(source_dir).st_dev != os.stat(target_dir).st_dev:
                tmp_f.copy(f.path)
            else:
                tmp_f.move(f.path)


class AbstractJobTreeTask(luigi.Task):
    """
    Used for tasks that interface with jobTree.
    """
    cfg = luigi.Parameter()

    def make_jobtree_dir(self, jobtree_path):
        """
        jobTree wants the parent directory for a given jobTree to exist, but not the directory itself.
        """
        try:
            rmTree(jobtree_path)
        except OSError:
            pass
        ensureDir(os.path.dirname(jobtree_path))


class RowsSqlTarget(luigi.Target):
    """
    This target checks that the provided column contains all of the values in row_vals.
    Generally used to ensure that every primary key we expect to see exists.
    Adapted from https://gist.github.com/a-campbell/75a2feaebbcecbe99ba1
    """
    def __init__(self, db_path, table, key_col, row_vals):
        self.db_path = db_path
        self.table = table
        self.key_col = key_col
        self.row_vals = row_vals

    def exists(self):
        query = 'SELECT {} FROM {}'.format(self.key_col, self.table)
        con, cur = open_database(self.db_path)
        data = get_query_ids(cur, query)
        return len(set(data) & set(self.row_vals)) == len(self.row_vals)


class VerifyTablesTask(luigi.Task):
    """
    An abstract task for verifying that SQL tables contains all rows expected.
    Expects a table map in the form {table: [column, values]} as well as a db_path.
    """
    def output(self):
        r = []
        for table, (column, row_vals) in self.table_map.iteritems():
            r.append(RowsSqlTarget(self.db_path, table, column, row_vals))
        return r
