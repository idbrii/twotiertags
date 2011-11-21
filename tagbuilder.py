#! /usr/bin/env python

import os
import os.path as path
import subprocess

class BIN:
    cscope = 'cscope'
    ctags = 'ctags'
    cut = 'cut'
    find = 'find'
    pycscope = 'pycscope'
    sort = 'sort'

class Builder(object):
    """
    A tag builder object that allows you to create a two-level tag files for
    your project. While it's easy to do this with two recursive tag builds,
    that means that the upper level tags will duplicate the lower level ones.
    Instead, we exclude the "working set" from the "other set" so we have two
    mutually-exclusive sets of tags.
    """
    def __init__(self):
        super(Builder, self).__init__()

        self._working_set = []
        self._other_set = []

    def __str__(self):
        return '%s -> %s\n%s -> %s' % (self._root, ','.join(self._other_set), self._working_root, ','.join(self._working_set))

    def set_root(self, absolute_root):
        p = path.expanduser(absolute_root)
        self._root = path.abspath(p)

    def set_working_root(self, relative_root):
        self._working_root = path.join(self._root, relative_root)

    def add_other_set(self, relative_dir):
        self._add_path_to_set(relative_dir, self._other_set)

    def add_working_set(self, relative_dir):
        self._add_path_to_set(relative_dir, self._working_set)

    def _add_path_to_set(self, relative_dir, destination):
        p = path.normpath(relative_dir)
        destination.append(p)

    def build_cpp(self):
        find_args = r'-type f ( -iname *.cpp -o -iname *.h ) -printf %f\t%p\t1\n'.split(' ')
        self._build_indexes(find_args)

        tags_args = '--c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files'.split(' ')
        self._build_tag_database(tags_args, self._working_root)
        self._build_tag_database(tags_args, self._root)

        cscope_args = '-b -q -k'.split(' ')
        #self._build_cscope_database(cscope_args, self._working_root)
        self._build_cscope_database(BIN.cscope, cscope_args, self._root)

    def build_python(self):
        find_args = r'-type f ( -iname *.py ) -printf %f\t%p\t1\n'.split(' ')
        self._build_indexes(find_args)

        tags_args = '-L cscope.files'.split(' ')
        self._build_tag_database(tags_args, self._working_root)
        self._build_tag_database(tags_args, self._root)

        cscope_args = '-i cscope.files'.split(' ')
        #self._build_cscope_database(BIN.pycscope, cscope_args, self._working_root)
        self._build_cscope_database(BIN.pycscope, cscope_args, self._root)

    def _build_tag_database(self, tags_args, root):
        args = [BIN.ctags]
        args += tags_args
        subprocess.call(args,
                        cwd=root)

    def _build_cscope_database(self, cscope, cscope_args, root):
        # Build cscope database
        #	-b              Build the database only.
        #	-k              Kernel Mode - don't use /usr/include for #include files.
        #	-q              Build an inverted index for quick symbol seaching.
        # May want to consider these flags
        #	-m "lang"       Use lang for multi-lingual cscope.
        #	-R              Recurse directories for files.
        args = [cscope]
        args += cscope_args
        subprocess.call(args,
                        cwd=root)

    def _build_indexes(self, find_args):
        self._build_indexes_impl(find_args, self._root, self._other_set)
        self._build_indexes_impl(find_args, self._working_root, self._working_set)
        # TODO: top-level cscope should have all files in its fileindex

        # We only want the lookupfile database for the top-level
        # TODO: separate the construction and only build them as needed
        lookup = self._open_lookupfile_for_path(self._working_root)
        lookup_file = path.abspath(lookup.name)
        lookup.close()
        os.remove(lookup_file)

    def _build_indexes_impl(self, find_args, root, directory_set):
        '''
        Using the input find args (specific to each filetype), builds file
        lists for the current set.

        Builds a file listing in the format used by lookup file.
        Sorts and properly creates the lookup file index.
        Strips extra stuff, sorts, and builds the cscope filelist.
        '''
        temp_tags = path.join(root, 'temp.tags')
        temp_tags = path.abspath(temp_tags)

        self._build_temp_list(find_args, root, directory_set, temp_tags)
        self._build_lookup_index(root, temp_tags)
        self._build_file_index(root, temp_tags)

        os.remove(temp_tags)

    def _build_temp_list(self, find_args, root, directory_set, output_fname):
        '''
        Using the input find args (specific to each filetype), builds the basic
        file list. This file should be removed when we're done: it's not used
        by any tools.

        Builds a file listing in the format used by lookup file.
        '''
        # build basic file list
        args = [BIN.find]
        args += directory_set
        args += find_args
        subprocess.call(args,
                        stdout=open(output_fname, 'w'),
                        close_fds=True,
                        cwd=root)

    def _build_lookup_index(self, root, intermediate_fname):
        '''
        Using the input intermediate file (the file list), builds the
        lookupfile index.

        intermediate_fname: a file list in the format used by lookup file.
        output: Sorts and properly creates the lookup file index.
        '''
        # build lookup file index
        lookup_file = self._open_lookupfile_for_path(root)
        lookup_file.write('!_TAG_FILE_SORTED	2	/2=foldcase/\n')
        lookup_file.flush()

        args = [BIN.sort, '-f']
        subprocess.call(args,
                        stdin=open(intermediate_fname, 'r'),
                        stdout=lookup_file,
                        close_fds=True,
                        cwd=root)

    def _build_file_index(self, root, intermediate_fname):
        '''
        Using the input intermediate file (the file list), builds the
        file index.

        intermediate_fname: a file list in the tag format (used by lookup
        file).
        output: Strips extra stuff, sorts, and builds the cscope filelist.
        '''
        # build file index
        filelist_file = self._open_filelist_for_path(root)
        args = [BIN.cut, '-f2']
        subprocess.call(args,
                        stdin=open(intermediate_fname, 'r'),
                        stdout=filelist_file,
                        close_fds=True,
                        cwd=root)


    def _open_lookupfile_for_path(self, root):
        return self._open_file_for_path('filenametags', root)

    def _open_filelist_for_path(self, root):
        return self._open_file_for_path('cscope.files', root)

    def _open_file_for_path(self, filename, pathname):
        fname = path.join(pathname, filename)
        fname = path.abspath(fname)
        return open(fname, 'w')


