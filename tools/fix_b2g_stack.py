#!/usr/bin/env python

'''Prettifies stacks retrieved from a B2G device.

This program takes as input a stream or a file containing stack frames
formatted like

    malloc[libmozglue.so +0x42A6] 0x4009c2a6

and converts frames into human-readable versions, such as

    malloc memory/build/replace_malloc.c:152 (libmozglue.so+0x42a6).

The stack frames don't need to be on their own line; fix_b2g_stack will replace
them wherever they appear, and is happy to replace multiple stack frames per
line.

This is an analog to fix-linux-stack.pl and is functionally similar to
$B2G_ROOT/scripts/profile-symbolicate.py.

'''

from __future__ import print_function

import sys
if sys.version_info < (2,7):
    # We need Python 2.7 because we import argparse.
    print('This script requires Python 2.7.')
    sys.exit(1)

import os
import re
import subprocess
import itertools
import argparse
import platform
import textwrap
import threading
import hashlib
import copy
import cPickle as pickle
import fcntl
from os.path import dirname, basename
from collections import defaultdict
from gzip import GzipFile

def first(pred, iter):
    '''Return the first element of iter which matches the predicate pred, or
    return None if no such element exists.

    This function avoids running pred unnecessarily, so is suitable for use
    when pred is expensive.

    '''
    try:
        return itertools.ifilter(pred, iter).next()
    except StopIteration:
        return None

def pump(dst, src):
    '''Pump the file dst into the file src.  When src hits EOF, close dst.

    Returns a thread object, so you can e.g. join() on the result.

    '''
    class Pumper(threading.Thread):
        def run(self):
            while True:
                bytes = src.read(4096)
                if not bytes:
                    break
                dst.write(bytes)
            dst.close()
    p = Pumper()
    p.start()
    return p

class FixB2GStacksOptions(object):
    '''Encapsulates arguments used in fix_b2g_stacks_in_file.

    The args argument to __init__() specifies options passed to
    fix_b2g_stacks_in_file.

    All of the args are optional, but see the caveat on the |product| arg.

    We look for the following properties on |args| and define corresponding
    properties on |self|.  (All default paths are relative to this source
    file's location, not to the current working directory.)

      * toolchain_prefix: The cross-toolchain binary prefix.
        Default: 'arm-linux-androideabi-'.

      * toolchain_dir: The directory in which the cross-toolchain binaries
        live.  Default:
        ../prebuilt/PLATFORM-x86/toolchain/arm-linux-android-eabi-4.4.x/bin

      * gecko_objdir: The gecko object directory.  Default: ../objdir-gecko.

      * gonk_objdir: The gonk object directory.  Default: ../out.

      * product: The device we're targeting.  Default: the one directory
        inside gonk_objdir/target/product.  If gonk_objdir/target/product
        is empty or has multiple sub-directories and the |product| arg was
        not specified, we raise an exception.

      * remove_cache: If true, delete fix_b2g_stack.py's persistent
        addr2line cache when we start running fix_b2g_stacks_in_file.

    In addition, this class defines two additional properties on itself based
    on the parameters received in __init__.

      * lib_search_dirs: [$gecko_objdir, $gonk_objdir/target/product/$product]

      * cross_bin(bin_name): Returns a path to the given cross-toolchain
        program.  For example, cross_bin('nm') returns a path to the
        cross-toolchain's nm binary.

    '''
    def __init__(self, args):
        def get_arg(arg, default=None):
            try:
                if getattr(args, arg):
                    return getattr(args, arg)
            except TypeError:
                pass

            try:
                if arg in args and args[arg]:
                    return args[arg]
            except TypeError:
                pass

            try:
                return default()
            except TypeError:
                pass

            return default

        self.toolchain_prefix = get_arg('toolchain_prefix', 'arm-linux-androideabi-')
        self.toolchain_dir = get_arg('toolchain_dir', self._guess_toolchain_dir)
        self.remove_cache = get_arg('remove_cache', False)

        self.gecko_objdir = get_arg('gecko_objdir',
            os.path.join(dirname(__file__), '../objdir-gecko'))
        self.gonk_objdir = get_arg('gonk_objdir',
            os.path.join(dirname(__file__), '../out'))

        product = get_arg('product')
        if product:
            product_dir = os.path.join(self.gonk_objdir, 'target/product', product)
        else:
            product_dir = self._guess_gonk_product(self.gonk_objdir)

        self.lib_search_dirs = [self.gecko_objdir, product_dir]

    def cross_bin(self, bin_name):
        return os.path.join(self.toolchain_dir, self.toolchain_prefix + bin_name)

    def _guess_toolchain_dir(self):
        return os.path.join(dirname(__file__),
            '../prebuilt/%s-x86/toolchain/arm-linux-androideabi-4.4.x/bin' %
                platform.system().lower())

    def _guess_gonk_product(self, gonk_objdir):
        products_dir = os.path.join(gonk_objdir, 'target/product')
        products = os.listdir(products_dir)
        if not products:
            raise Exception("Couldn't auto-detect a product, because %s is empty." %
                            products_dir)
        if len(products) == 1:
            return os.path.join(products_dir, products[0])

        raise Exception(textwrap.dedent('''
            Couldn't auto-detect a product because %s has multiple entries.

            Please re-run with --product.  Your options are %s.''' %
            (products_dir, products)))

class DefaulterDict(dict):
    '''DefaulterDict is like defaultdict, but pickleable.

    The main API difference between DefaulterDict and defaultdict is that while
    defaultdict takes a function which returns the dict's default element when
    called, DefaulterDict takes an object as its default element and makes a
    deep copy of it before inserting it as a default.

    We created DefaulterDict to work around the pickle quirk/bug described in
    [1].  Essentially, because this code may be run by invoking
    fix_b2g_stack.py directly or by invoking get_about_memory.py, we need to
    define the magic __module__ attribute on this class and on all user-defined
    classes and functions this class references, otherwise unpickling will fail.

    It's the fact that this class can't reference other user-defined functions
    (*) which necessitates the API difference between defaultdict and
    DefaulterDict.

    (*) I suppose defaultdict might work if we somehow defined __module__ on
    the default-function; I didn't try.

    [1] http://stefaanlippens.net/pickleproblem
    '''
    __module__ = os.path.splitext(basename(__file__))[0]

    def __init__(self, default_item):
        super(DefaulterDict, self).__init__()
        self._default_item = default_item

    def __missing__(self, kw):
        item = copy.deepcopy(self._default_item)
        self[kw] = item
        return item

class StackFixerCache():
    '''A cache for StackFixer which occasionally serializes itself to disk.

    This cache stores (lib, offset) --> string mappings, so we can avoid
    calling addr2line.  After every so many puts, we write the cache out to
    disk.

    Please be kind and call flush() on this object when you're done with it.
    That gives us one last chance to write our cache out to disk.

    When the cache is read in from disk, we check that the libraries' sizes,
    mtimes, and ctimes haven't changed.  If they have, we throw out the cached
    mappings.

    In theory you can safely access this cache from multiple processes, because
    we use fcntl locking on the cache file.  (We never block on acquiring a
    lock on the cache file; if we can't immediately access the file, we simply
    give up.) But note that I have not tested that this locking works as
    intended.

    '''
    def __init__(self, options):
        self._initialized = False
        self._lib_lookups = None
        self._lib_metadata = None
        self._put_counter = 0

        # Write the cache file after this many puts.
        self._write_cache_after_puts = 500

    def _ensure_initialized(self):
        if self._initialized:
            return
        cache = self._read_cache_from_disk()
        if cache:
            self._lib_lookups = cache['lookups']
            self._lib_metadata = cache['metadata']
            self._validate_lib_metadata()
        else:
            self._lib_lookups = DefaulterDict(DefaulterDict(None))
            self._lib_metadata = {}
        self._initialized = True

    @staticmethod
    def cache_filename():
        '''Get the filename of our cache.'''
        return os.path.join(dirname(__file__), '.fix_b2g_stack.cache')

    def _read_cache_from_disk(self):
        try:
            with open(StackFixerCache.cache_filename(), 'rb') as cache_file:
                try:
                    fcntl.lockf(cache_file.fileno(), fcntl.LOCK_SH | fcntl.LOCK_NB)
                    return pickle.load(cache_file)
                finally:
                    try:
                        fcntl.lockf(cache_file.fileno(), fcntl.LOCK_UN)
                    except IOError:
                        pass
        except (EOFError, IOError, pickle.PickleError) as e:
            pass
        return None

    def flush(self):
        if self._put_counter:
            self._write_cache_to_disk()

    def _write_cache_to_disk(self):
        try:
            with open(StackFixerCache.cache_filename(), 'wb') as cache_file:
                try:
                    fcntl.lockf(cache_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    pickle.dump({'lookups': self._lib_lookups,
                                 'metadata': self._lib_metadata},
                                cache_file,
                                pickle.HIGHEST_PROTOCOL)
                    self._put_counter = 0
                    return True
                finally:
                    try:
                        fcntl.lockf(cache_file.fileno(), fcntl.LOCK_UN)
                    except IOError:
                        pass
        except IOError, pickle.PickleError:
            pass
        return False

    def _validate_lib_metadata(self):
        for (lib_path, cached_metadata) in self._lib_metadata.items():
            real_metadata = self._get_lib_metadata(lib_path)
            if real_metadata != cached_metadata or not real_metadata:
                self._lib_metadata[lib_path] = real_metadata
                try:
                    del self._lib_lookups[lib_path]
                except KeyError:
                    pass

    def _get_lib_metadata(self, lib_path):
        try:
            st = os.stat(lib_path)
            return (os.path.normpath(os.path.abspath(lib_path)),
                    st.st_size, st.st_mtime, st.st_ctime)
        except:
            return None

    def get(self, lib_path, offset):
        self._ensure_initialized()
        return self._lib_lookups[lib_path][offset]

    def put(self, lib_path, offset, result):
        self._ensure_initialized()
        if lib_path not in self._lib_metadata:
            self._lib_metadata[lib_path] = self._get_lib_metadata(lib_path)
        self._lib_lookups[lib_path][offset] = result

        self._put_counter += 1
        if self._put_counter == self._write_cache_after_puts:
            self._write_cache_to_disk()

            # Reset the put counter even if the cache write above fails; if
            # this write failed, it's likely that our next write will fail too,
            # and we don't want to waste our time writing and failing over and
            # over again.
            self._put_counter = 0

    def get_maybe_set(self, lib_path, offset, result):
        '''Get the addr2line result for (lib_path, offset).

        If (lib_path, offset) is not in our cache, insert |result()| or
        |result|, depending on whether |result| is callable.

        '''
        self._ensure_initialized()
        if not self._lib_lookups[lib_path][offset]:
            if callable(result):
                self.put(lib_path, offset, result())
            else:
                self.put(lib_path, offset, result)
        return self._lib_lookups[lib_path][offset]

class StackFixer(object):
    '''An object used for translating (lib, offset) tuples into function+file
    names, using addr2line and a cache.

    Here and elsewhere we adopt the convention that |lib| is a library's
    basename (e.g. 'libxul.so'), while lib_path is a relative path from
    dirname(__file__) (i.e., this file's directory) to the library.

    Please be kind and call close() once you're done with this object.  That
    gives us a chance to flush the cache to disk, making future invocations
    faster.

    '''

    _addr2line_procs = {}

    def __init__(self, options):
        self._lib_path_cache = defaultdict(list)
        self._cache = StackFixerCache(options)
        self._options = options

    def translate(self, lib, offset, pc=None, fn_guess=None):
        '''Translate the given offset (an integer) into the given library (e.g.
        'libxul.so') into a human-readable string and return that string.

        pc and fn_guess are hints to make the output look nicer; we don't use
        either of these optional parameters to look up lib+offsets.

        '''
        lib_path = self._find_lib(lib)
        return self._cache.get_maybe_set(lib_path, offset,
            lambda: self._addr2line(lib, offset, pc, fn_guess))

    def close(self):
        self._cache.flush()

    def _init_lib_path_cache(self):
        '''Initialize self._lib_path_cache by walking all of the subdirectories
        of self._options.lib_search_dirs and finding all the '*.so', 'b2g', and
        'plugin-container' files therein.

        '''
        for root, _, files in itertools.chain(*[os.walk(dir) for dir in
                                                self._options.lib_search_dirs]):
            for f in files:
                if f.endswith('.so') or f == 'b2g' or f == 'plugin-container':
                    self._lib_path_cache[f].append(os.path.join(root, f))

    def _find_lib(self, lib):
        '''Get a path to the given lib (e.g. 'libxul.so').

        We prefer unstripped versions of the lib, but if all we can find is a
        stripped version, we'll return that.

        If we can't find the lib, we return None.

        '''
        if not self._lib_path_cache:
            self._init_lib_path_cache()

        lib_paths = self._lib_path_cache[lib]
        if not lib_paths:
            return None
        if len(lib_paths) == 1:
            return lib_paths[0]

        lib_path = first(self._lib_has_symbols, lib_paths)
        if not lib_path:
            lib_path = self._lib_path_cache[lib][0]
        self._lib_path_cache[lib] = [lib_path]
        return lib_path

    def _lib_has_symbols(self, lib_path):
        '''Check if the given lib_path has symbols.

        We do this by running nm on the library.  If it's stripped, nm will not
        output anything to stdout.

        '''
        proc = subprocess.Popen(
            [self._options.cross_bin('nm'), lib_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            return not not proc.stdout.readline()
        except IOError:
            return False
        finally:
            proc.kill()

    def _addr2line(self, lib, offset, pc, fn_guess):
        '''Use addr2line to translate the given lib+offset.

        We use pc only for aesthetic purposes; it's not passed to addr2line or
        anything.

        If addr2line can't resolve a lib+offset, you may still have a guess as
        to what function lives there.  (For example, NS_StackWalk is sometimes
        able to resolve function names that addr2line can't.)  fn_guess should
        be this guess, if you have one.

        '''
        def addr_str():
            _pc = ('0x%x ' % pc) if pc != None else ''
            return '(%s%s+0x%x)' % (_pc, lib, offset)
        def fallback_str():
            _fn_guess = fn_guess + ' ' if fn_guess and fn_guess != '???' else ''
            return '%s%s' % (_fn_guess, addr_str())

        if lib not in StackFixer._addr2line_procs:
            lib_path = self._find_lib(lib)
            if not lib_path:
                return "%s (can't find lib)" % fallback_str()
            StackFixer._addr2line_procs[lib] = subprocess.Popen(
                [self._options.cross_bin('addr2line'), '-Cfe', lib_path],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE)

        proc = StackFixer._addr2line_procs[lib]
        try:
            proc.stdin.write('0x%x\n' % offset)
            proc.stdin.flush()

            # addr2line returns two lines for every address we give it.  The
            # first line is of the form "foo()", and the second line is of the
            # form "foo.cpp:123".
            func = proc.stdout.readline().strip()
            file = os.path.normpath(proc.stdout.readline().strip())
            if func == '??' and file == '??:0':
                # addr2line wasn't helpful here.
                return '%s (no addr2line)' % fallback_str()
            return '%s %s %s' % (func, file, addr_str())
        except IOError as e:
            # If our addr2line process dies, don't try to restart it.  Just
            # leave it in a dead state and presumably every time we read/write
            # to/from it, we'll hit this case.
            return '%s (addr2line exception)' % fallback_str()

def fix_b2g_stacks_in_file(infile, outfile, args={}, **kwargs):
    '''Read lines from infile and output those lines to outfile with their
    stack frames rewritten.

    infile and outfile may be a files or file-like objects.  For example, to
    read/write from strings, pass StringIO objects.

    args or kwargs will be passed to FixB2GStacksOptions (you may not specify
    both).  See the docs on FixB2GStacksOptions for the supported argument
    names.

    '''
    if args and kwargs:
        raise Exception("Can't pass args and kwargs to fix_b2g_stacks_in_file.")
    options = FixB2GStacksOptions(args if args else kwargs)

    if options.remove_cache:
        try:
            os.remove(StackFixerCache.cache_filename())
        except:
            pass

    matcher = re.compile(
        r'''(?P<fn>[^ ][^\]]*)              # either '???' or mangled fn signature
            \[
              (?P<lib>\S+)                  # library name
              \s+
              \+(?P<offset>0x[0-9a-fA-F]+)  # offset into lib
            \]
            \s+
            (?P<pc>0x[0-9a-fA-F]+)          # program counter
            ''',
        re.VERBOSE)

    fixer = StackFixer(options)
    def subfn(match):
        return fixer.translate(match.group('lib'),
                               int(match.group('offset'), 16),
                               int(match.group('pc'), 16),
                               match.group('fn'))

    # Filter our output through c++filt.  Pumping on a separate thread is
    # *much* faster than filtering line-by-line.
    #
    # On Mac OS, the native c++filt doesn't filter our output correctly, so we
    # use the cross-compiled one.  (I don't know if the system c++filt works
    # properly on Linux, though I imagine it does.)
    cppfilt = subprocess.Popen([options.cross_bin('c++filt')],
                               stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE)
    try:
        p = pump(outfile, cppfilt.stdout)
        for line in infile:
            cppfilt.stdin.write(matcher.sub(subfn, line))
    finally:
        cppfilt.stdin.close()
    p.join()
    fixer.close()

def add_argparse_arguments(parser):
    '''Add arguments to an argparse parser which make the parser's result
    suitable for passing to fix_b2g_stacks_in_file.

    You might use this in your code as something like:

      parser = argparse.ArgumentParser()
      b2g_stack_group = parser.add_argument_group(...)
      fix_b2g_stack.add_argparse_arguments(b2g_stack_group)

    '''
    parser.add_argument('--toolchain-dir', metavar='DIR',
                        help='Directory containing toolchain binaries')
    parser.add_argument('--toolchain-prefix', metavar='PREFIX',
                        help='Toolchain binary prefix (e.g. "arm-linux-androideabi-")')
    parser.add_argument('--gecko-objdir', metavar='DIR',
                        help='Path to gecko objdir (default: ../objdir-gecko)')
    parser.add_argument('--gonk-objdir', metavar='DIR',
                        help='Path to gonk objdir (default: $B2G_ROOT/out)')
    parser.add_argument('--product', metavar='PRODUCT',
                        help='Product being built (e.g. "otoro").  '
                             'We try to detect this automatically.')
    parser.add_argument('--remove-cache', action='store_true',
                        help="Delete the persistent addr2line cache before running.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('infile', metavar='INFILE', nargs='?',
                        help='File to read from (default: stdin).  gz files are OK.')
    parser.add_argument('--outfile', metavar='FILE',
                        help=textwrap.dedent('''\
                            File to write output to (default: stdout).  If name
                            ends with ".gz", we will gzip the file.'''))
    add_argparse_arguments(parser)
    args = parser.parse_args()

    infile = sys.stdin
    if args.infile:
        if args.infile.endswith('.gz'):
            infile = GzipFile(args.infile, 'r')
        else:
            infile = open(args.infile, 'r')

    outfile = sys.stdout
    if args.outfile:
        if args.outfile.endswith('.gz'):
            outfile = GzipFile(args.outfile, 'w')
        else:
            outfile = open(args.outfile, 'w')

    fix_b2g_stacks_in_file(infile, outfile, args)
