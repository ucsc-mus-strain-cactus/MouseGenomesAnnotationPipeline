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
import argparse
import os
from jobTree.src.jobTreeStatus import parseJobFiles
from jobTree.src.master import getJobFileDirName
from pycbio.sys.procOps import runProc
from pycbio.sys.fileOps import ensureDir, rmTree, iterRows, atomicInstall
from pycbio.sys.sqliteOps import open_database, execute_query

########################################################################################################################
########################################################################################################################
## Abstract Tasks
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

    def atomic_install(self, target):
        """
        Atomically install a given target to this task's output.
        """
        output = self.output()
        output.makedirs()
        if isinstance(target, luigi.LocalTarget):
            atomicInstall(target.path, output.path)
        elif isinstance(target, str):
            atomicInstall(target, output.path)
        else:
            raise NotImplementedError


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
        These files will be atomically installed.
        """
        runProc(cmd)
        for tmp_f, f in zip(*(tmp_files, self.output())):
            f.makedirs()
            if isinstance(tmp_f, luigi.LocalTarget):
                atomicInstall(tmp_f.path, f.path)
            elif isinstance(tmp_f, str):
                atomicInstall(tmp_f, f.path)
            else:
                raise NotImplementedError


class AbstractJobTreeTask(luigi.Task):
    """
    Used for tasks that interface with jobTree.
    """
    cfg = luigi.Parameter()

    def jobtree_is_finished(self, jobtree_path):
        """
        See if this jobTree has finished before. Code extracted from the jobTree repo.
        """
        childJobFileToParentJob, childCounts, updatedJobFiles, shellJobs = {}, {}, set(), set()
        parseJobFiles(getJobFileDirName(jobtree_path), updatedJobFiles, childJobFileToParentJob, childCounts, shellJobs)
        return len(updatedJobFiles) == 0

    def restart_jobtree(self, args, entry_fn):
        """
        Restart an existing jobTree.
        """
        entry_fn(args)

    def make_jobtree_dir(self, jobtree_path):
        """
        jobTree wants the parent directory for a given jobTree to exist, but not the directory itself.
        """
        try:
            rmTree(jobtree_path)
        except OSError:
            pass
        ensureDir(os.path.dirname(jobtree_path))

    def start_jobtree(self, args, entry_fn, norestart=False):
        """
        Start a jobTree. Based on the flag norestart, will decide if we should attempt a restart.
        TODO: this hack re-creates the namespace to avoid import issues.
        """
        tmp_cfg = argparse.Namespace()
        tmp_cfg.__dict__.update(vars(args))
        ensureDir(os.path.dirname(args.jobTree))
        jobtree_path = args.jobTree
        if norestart is True or not os.path.exists(jobtree_path) or self.jobtree_is_finished(jobtree_path):
            self.make_jobtree_dir(jobtree_path)
            entry_fn(tmp_cfg)
        else:  # try restarting the tree
            try:
                entry_fn(args)
            except RuntimeError:  # try starting over
                self.make_jobtree_dir(jobtree_path)
                entry_fn(tmp_cfg)


########################################################################################################################
########################################################################################################################
## Custom Targets
########################################################################################################################
########################################################################################################################


class RowsSqlTarget(luigi.Target):
    """
    Checks that the table at db has num_rows rows.
    """
    def __init__(self, db, table, input_file):
        self.db = db
        self.table = table
        self.input_file = input_file

    def find_num_rows(self):
        return len(list(iterRows(open(self.input_file))))

    def exists(self):
        # input files may not have been created yet
        if not os.path.exists(self.input_file):
            return False
        # input files may exist but be empty, resulting in the table not being produced. This is expected.
        if os.path.getsize(self.input_file) == 0:
            return True
        # database may have not been created yet
        if not os.path.exists(self.db):
            return False
        con, cur = open_database(self.db)
        # check if table exists
        query = 'SELECT name FROM sqlite_master WHERE type="table" AND name="{}"'.format(self.table)
        if len(execute_query(cur, query).fetchall()) != 1:
            return False
        num_rows_in_file = self.find_num_rows()
        query = 'SELECT COUNT(*) FROM "{}"'.format(self.table)
        num_rows_in_table = execute_query(cur, query).fetchone()[0]
        return num_rows_in_table == num_rows_in_file
