#!/usr/bin/env python
# -*- coding:utf-8 -*-
#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Repo launcher.

This is a standalone tool that people may copy to anywhere in their system.
It is used to get an initial repo client checkout, and after that it runs the
copy of repo in the checkout.
"""

from __future__ import print_function

import datetime
import os
import platform
import shlex
import subprocess
import sys


# Keep basic logic in sync with repo_trace.py.
class Trace(object):
  """Trace helper logic."""

  REPO_TRACE = 'REPO_TRACE'

  def __init__(self):
    self.set(os.environ.get(self.REPO_TRACE) == '1')

  def set(self, value):
    self.enabled = bool(value)

  def print(self, *args, **kwargs):
    if self.enabled:
      print(*args, **kwargs)


trace = Trace()


def exec_command(cmd):
  """Execute |cmd| or return None on failure."""
  trace.print(':', ' '.join(cmd))
  try:
    if platform.system() == 'Windows':
      ret = subprocess.call(cmd)
      sys.exit(ret)
    else:
      os.execvp(cmd[0], cmd)
  except Exception:
    pass


def check_python_version():
  """Make sure the active Python version is recent enough."""
  def reexec(prog):
    exec_command([prog] + sys.argv)

  MIN_PYTHON_VERSION = (3, 6)

  ver = sys.version_info
  major = ver.major
  minor = ver.minor

  # Abort on very old Python 2 versions.
  if (major, minor) < (2, 7):
    print('repo: error: Your Python version is too old. '
          'Please use Python {}.{} or newer instead.'.format(
              *MIN_PYTHON_VERSION), file=sys.stderr)
    sys.exit(1)

  # Try to re-exec the version specific Python 3 if needed.
  if (major, minor) < MIN_PYTHON_VERSION:
    # Python makes releases ~once a year, so try our min version +10 to help
    # bridge the gap.  This is the fallback anyways so perf isn't critical.
    min_major, min_minor = MIN_PYTHON_VERSION
    for inc in range(0, 10):
      reexec('python{}.{}'.format(min_major, min_minor + inc))

    # Try the generic Python 3 wrapper, but only if it's new enough.  We don't
    # want to go from (still supported) Python 2.7 to (unsupported) Python 3.5.
    try:
      proc = subprocess.Popen(
          ['python3', '-c', 'import sys; '
           'print(sys.version_info.major, sys.version_info.minor)'],
          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      (output, _) = proc.communicate()
      python3_ver = tuple(int(x) for x in output.decode('utf-8').split())
    except (OSError, subprocess.CalledProcessError):
      python3_ver = None

    # The python3 version looks like it's new enough, so give it a try.
    if python3_ver and python3_ver >= MIN_PYTHON_VERSION:
      reexec('python3')

    # We're still here, so diagnose things for the user.
    if major < 3:
      print('repo: warning: Python 2 is no longer supported; '
            'Please upgrade to Python {}.{}+.'.format(*MIN_PYTHON_VERSION),
            file=sys.stderr)
    else:
      print('repo: error: Python 3 version is too old; '
            'Please use Python {}.{} or newer.'.format(*MIN_PYTHON_VERSION),
            file=sys.stderr)
      sys.exit(1)


if __name__ == '__main__':
  check_python_version()


# repo default configuration
#
REPO_URL = os.environ.get('REPO_URL', None)
if not REPO_URL:
  REPO_URL = 'https://gerrit.googlesource.com/git-repo'
REPO_REV = os.environ.get('REPO_REV')
if not REPO_REV:
  REPO_REV = 'stable'

# increment this whenever we make important changes to this script
VERSION = (2, 8)

# increment this if the MAINTAINER_KEYS block is modified
KEYRING_VERSION = (2, 3)

# Each individual key entry is created by using:
# gpg --armor --export keyid
MAINTAINER_KEYS = """

     Repo Maintainer <repo@android.kernel.org>
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
cZ7aFsJF4PtcDrfdejyAxbtsSHI=
=82Tj
-----END PGP PUBLIC KEY BLOCK-----
"""

GIT = 'git'                      # our git command
# NB: The version of git that the repo launcher requires may be much older than
# the version of git that the main repo source tree requires.  Keeping this at
# an older version also makes it easier for users to upgrade/rollback as needed.
#
# git-1.7 is in (EOL) Ubuntu Precise.
MIN_GIT_VERSION = (1, 7, 2)      # minimum supported git version
repodir = '.repo'                # name of repo's private directory
S_repo = 'repo'                  # special repo repository
S_manifests = 'manifests'        # special manifest repository
REPO_MAIN = S_repo + '/main.py'  # main script
GITC_CONFIG_FILE = '/gitc/.config'
GITC_FS_ROOT_DIR = '/gitc/manifest-rw/'


import collections
import errno
import optparse
import re
import shutil
import stat

if sys.version_info[0] == 3:
  import urllib.request
  import urllib.error
else:
  import imp
  import urllib2
  urllib = imp.new_module('urllib')
  urllib.request = urllib2
  urllib.error = urllib2


home_dot_repo = os.path.expanduser('~/.repoconfig')
gpg_dir = os.path.join(home_dot_repo, 'gnupg')


def GetParser(gitc_init=False):
  """Setup the CLI parser."""
  if gitc_init:
    usage = 'repo gitc-init -u url -c client [options]'
  else:
    usage = 'repo init -u url [options]'

  parser = optparse.OptionParser(usage=usage)

  # Logging.
  group = parser.add_option_group('Logging options')
  group.add_option('-v', '--verbose',
                   dest='output_mode', action='store_true',
                   help='show all output')
  group.add_option('-q', '--quiet',
                   dest='output_mode', action='store_false',
                   help='only show errors')

  # Manifest.
  group = parser.add_option_group('Manifest options')
  group.add_option('-u', '--manifest-url',
                   help='manifest repository location', metavar='URL')
  group.add_option('-b', '--manifest-branch',
                   help='manifest branch or revision', metavar='REVISION')
  group.add_option('-m', '--manifest-name',
                   help='initial manifest file', metavar='NAME.xml')
  cbr_opts = ['--current-branch']
  # The gitc-init subcommand allocates -c itself, but a lot of init users
  # want -c, so try to satisfy both as best we can.
  if not gitc_init:
    cbr_opts += ['-c']
  group.add_option(*cbr_opts,
                   dest='current_branch_only', action='store_true',
                   help='fetch only current manifest branch from server')
  group.add_option('--mirror', action='store_true',
                   help='create a replica of the remote repositories '
                        'rather than a client working directory')
  group.add_option('--reference',
                   help='location of mirror directory', metavar='DIR')
  group.add_option('--dissociate', action='store_true',
                   help='dissociate from reference mirrors after clone')
  group.add_option('--depth', type='int', default=None,
                   help='create a shallow clone with given depth; '
                        'see git clone')
  group.add_option('--partial-clone', action='store_true',
                   help='perform partial clone (https://git-scm.com/'
                        'docs/gitrepository-layout#_code_partialclone_code)')
  group.add_option('--clone-filter', action='store', default='blob:none',
                   help='filter for use with --partial-clone '
                        '[default: %default]')
  group.add_option('--worktree', action='store_true',
                   help=optparse.SUPPRESS_HELP)
  group.add_option('--archive', action='store_true',
                   help='checkout an archive instead of a git repository for '
                        'each project. See git archive.')
  group.add_option('--submodules', action='store_true',
                   help='sync any submodules associated with the manifest repo')
  group.add_option('-g', '--groups', default='default',
                   help='restrict manifest projects to ones with specified '
                        'group(s) [default|all|G1,G2,G3|G4,-G5,-G6]',
                   metavar='GROUP')
  group.add_option('-p', '--platform', default='auto',
                   help='restrict manifest projects to ones with a specified '
                        'platform group [auto|all|none|linux|darwin|...]',
                   metavar='PLATFORM')
  group.add_option('--clone-bundle', action='store_true',
                   help='enable use of /clone.bundle on HTTP/HTTPS (default if not --partial-clone)')
  group.add_option('--no-clone-bundle',
                   dest='clone_bundle', action='store_false',
                   help='disable use of /clone.bundle on HTTP/HTTPS (default if --partial-clone)')
  group.add_option('--no-tags',
                   dest='tags', default=True, action='store_false',
                   help="don't fetch tags in the manifest")

  # Tool.
  group = parser.add_option_group('repo Version options')
  group.add_option('--repo-url', metavar='URL',
                   help='repo repository location ($REPO_URL)')
  group.add_option('--repo-rev', metavar='REV',
                   help='repo branch or revision ($REPO_REV)')
  group.add_option('--repo-branch', dest='repo_rev',
                   help=optparse.SUPPRESS_HELP)
  group.add_option('--no-repo-verify',
                   dest='repo_verify', default=True, action='store_false',
                   help='do not verify repo source code')

  # Other.
  group = parser.add_option_group('Other options')
  group.add_option('--config-name',
                   action='store_true', default=False,
                   help='Always prompt for name/e-mail')

  # gitc-init specific settings.
  if gitc_init:
    group = parser.add_option_group('GITC options')
    group.add_option('-f', '--manifest-file',
                     help='Optional manifest file to use for this GITC client.')
    group.add_option('-c', '--gitc-client',
                     help='Name of the gitc_client instance to create or modify.')

  return parser


# This is a poor replacement for subprocess.run until we require Python 3.6+.
RunResult = collections.namedtuple(
    'RunResult', ('returncode', 'stdout', 'stderr'))


class RunError(Exception):
  """Error when running a command failed."""


def run_command(cmd, **kwargs):
  """Run |cmd| and return its output."""
  check = kwargs.pop('check', False)
  if kwargs.pop('capture_output', False):
    kwargs.setdefault('stdout', subprocess.PIPE)
    kwargs.setdefault('stderr', subprocess.PIPE)
  cmd_input = kwargs.pop('input', None)

  def decode(output):
    """Decode |output| to text."""
    if output is None:
      return output
    try:
      return output.decode('utf-8')
    except UnicodeError:
      print('repo: warning: Invalid UTF-8 output:\ncmd: %r\n%r' % (cmd, output),
            file=sys.stderr)
      # TODO(vapier): Once we require Python 3, use 'backslashreplace'.
      return output.decode('utf-8', 'replace')

  # Run & package the results.
  proc = subprocess.Popen(cmd, **kwargs)
  (stdout, stderr) = proc.communicate(input=cmd_input)
  dbg = ': ' + ' '.join(cmd)
  if cmd_input is not None:
    dbg += ' 0<|'
  if stdout == subprocess.PIPE:
    dbg += ' 1>|'
  if stderr == subprocess.PIPE:
    dbg += ' 2>|'
  elif stderr == subprocess.STDOUT:
    dbg += ' 2>&1'
  trace.print(dbg)
  ret = RunResult(proc.returncode, decode(stdout), decode(stderr))

  # If things failed, print useful debugging output.
  if check and ret.returncode:
    print('repo: error: "%s" failed with exit status %s' %
          (cmd[0], ret.returncode), file=sys.stderr)
    print('  cwd: %s\n  cmd: %r' %
          (kwargs.get('cwd', os.getcwd()), cmd), file=sys.stderr)

    def _print_output(name, output):
      if output:
        print('  %s:\n  >> %s' % (name, '\n  >> '.join(output.splitlines())),
              file=sys.stderr)

    _print_output('stdout', ret.stdout)
    _print_output('stderr', ret.stderr)
    raise RunError(ret)

  return ret


_gitc_manifest_dir = None


def get_gitc_manifest_dir():
  global _gitc_manifest_dir
  if _gitc_manifest_dir is None:
    _gitc_manifest_dir = ''
    try:
      with open(GITC_CONFIG_FILE, 'r') as gitc_config:
        for line in gitc_config:
          match = re.match('gitc_dir=(?P<gitc_manifest_dir>.*)', line)
          if match:
            _gitc_manifest_dir = match.group('gitc_manifest_dir')
    except IOError:
      pass
  return _gitc_manifest_dir


def gitc_parse_clientdir(gitc_fs_path):
  """Parse a path in the GITC FS and return its client name.

  @param gitc_fs_path: A subdirectory path within the GITC_FS_ROOT_DIR.

  @returns: The GITC client name
  """
  if gitc_fs_path == GITC_FS_ROOT_DIR:
    return None
  if not gitc_fs_path.startswith(GITC_FS_ROOT_DIR):
    manifest_dir = get_gitc_manifest_dir()
    if manifest_dir == '':
      return None
    if manifest_dir[-1] != '/':
      manifest_dir += '/'
    if gitc_fs_path == manifest_dir:
      return None
    if not gitc_fs_path.startswith(manifest_dir):
      return None
    return gitc_fs_path.split(manifest_dir)[1].split('/')[0]
  return gitc_fs_path.split(GITC_FS_ROOT_DIR)[1].split('/')[0]


class CloneFailure(Exception):

  """Indicate the remote clone of repo itself failed.
  """


def check_repo_verify(repo_verify, quiet=False):
  """Check the --repo-verify state."""
  if not repo_verify:
    print('repo: warning: verification of repo code has been disabled;\n'
          'repo will not be able to verify the integrity of itself.\n',
          file=sys.stderr)
    return False

  if NeedSetupGnuPG():
    return SetupGnuPG(quiet)

  return True


def check_repo_rev(dst, rev, repo_verify=True, quiet=False):
  """Check that |rev| is valid."""
  do_verify = check_repo_verify(repo_verify, quiet=quiet)
  remote_ref, local_rev = resolve_repo_rev(dst, rev)
  if not quiet and not remote_ref.startswith('refs/heads/'):
    print('warning: repo is not tracking a remote branch, so it will not '
          'receive updates', file=sys.stderr)
  if do_verify:
    rev = verify_rev(dst, remote_ref, local_rev, quiet)
  else:
    rev = local_rev
  return (remote_ref, rev)


def _Init(args, gitc_init=False):
  """Installs repo by cloning it over the network.
  """
  parser = GetParser(gitc_init=gitc_init)
  opt, args = parser.parse_args(args)
  if args:
    parser.print_usage()
    sys.exit(1)
  opt.quiet = opt.output_mode is False
  opt.verbose = opt.output_mode is True

  if opt.clone_bundle is None:
    opt.clone_bundle = False if opt.partial_clone else True

  url = opt.repo_url or REPO_URL
  rev = opt.repo_rev or REPO_REV

  try:
    if gitc_init:
      gitc_manifest_dir = get_gitc_manifest_dir()
      if not gitc_manifest_dir:
        print('fatal: GITC filesystem is not available. Exiting...',
              file=sys.stderr)
        sys.exit(1)
      gitc_client = opt.gitc_client
      if not gitc_client:
        gitc_client = gitc_parse_clientdir(os.getcwd())
      if not gitc_client:
        print('fatal: GITC client (-c) is required.', file=sys.stderr)
        sys.exit(1)
      client_dir = os.path.join(gitc_manifest_dir, gitc_client)
      if not os.path.exists(client_dir):
        os.makedirs(client_dir)
      os.chdir(client_dir)
      if os.path.exists(repodir):
        # This GITC Client has already initialized repo so continue.
        return

    os.mkdir(repodir)
  except OSError as e:
    if e.errno != errno.EEXIST:
      print('fatal: cannot make %s directory: %s'
            % (repodir, e.strerror), file=sys.stderr)
      # Don't raise CloneFailure; that would delete the
      # name. Instead exit immediately.
      #
      sys.exit(1)

  _CheckGitVersion()
  try:
    if not opt.quiet:
      print('Downloading Repo source from', url)
    dst = os.path.abspath(os.path.join(repodir, S_repo))
    _Clone(url, dst, opt.clone_bundle, opt.quiet, opt.verbose)

    remote_ref, rev = check_repo_rev(dst, rev, opt.repo_verify, quiet=opt.quiet)
    _Checkout(dst, remote_ref, rev, opt.quiet)

    if not os.path.isfile(os.path.join(dst, 'repo')):
      print("warning: '%s' does not look like a git-repo repository, is "
            "REPO_URL set correctly?" % url, file=sys.stderr)

  except CloneFailure:
    if opt.quiet:
      print('fatal: repo init failed; run without --quiet to see why',
            file=sys.stderr)
    raise


def run_git(*args, **kwargs):
  """Run git and return execution details."""
  kwargs.setdefault('capture_output', True)
  kwargs.setdefault('check', True)
  try:
    return run_command([GIT] + list(args), **kwargs)
  except OSError as e:
    print(file=sys.stderr)
    print('repo: error: "%s" is not available' % GIT, file=sys.stderr)
    print('repo: error: %s' % e, file=sys.stderr)
    print(file=sys.stderr)
    print('Please make sure %s is installed and in your path.' % GIT,
          file=sys.stderr)
    sys.exit(1)
  except RunError:
    raise CloneFailure()


# The git version info broken down into components for easy analysis.
# Similar to Python's sys.version_info.
GitVersion = collections.namedtuple(
    'GitVersion', ('major', 'minor', 'micro', 'full'))


def ParseGitVersion(ver_str=None):
  if ver_str is None:
    # Load the version ourselves.
    ver_str = run_git('--version').stdout

  if not ver_str.startswith('git version '):
    return None

  full_version = ver_str[len('git version '):].strip()
  num_ver_str = full_version.split('-')[0]
  to_tuple = []
  for num_str in num_ver_str.split('.')[:3]:
    if num_str.isdigit():
      to_tuple.append(int(num_str))
    else:
      to_tuple.append(0)
  to_tuple.append(full_version)
  return GitVersion(*to_tuple)


def _CheckGitVersion():
  ver_act = ParseGitVersion()
  if ver_act is None:
    print('fatal: unable to detect git version', file=sys.stderr)
    raise CloneFailure()

  if ver_act < MIN_GIT_VERSION:
    need = '.'.join(map(str, MIN_GIT_VERSION))
    print('fatal: git %s or later required; found %s' % (need, ver_act.full),
          file=sys.stderr)
    raise CloneFailure()


def SetGitTrace2ParentSid(env=None):
  """Set up GIT_TRACE2_PARENT_SID for git tracing."""
  # We roughly follow the format git itself uses in trace2/tr2_sid.c.
  # (1) Be unique (2) be valid filename (3) be fixed length.
  #
  # Since we always export this variable, we try to avoid more expensive calls.
  # e.g. We don't attempt hostname lookups or hashing the results.
  if env is None:
    env = os.environ

  KEY = 'GIT_TRACE2_PARENT_SID'

  now = datetime.datetime.utcnow()
  value = 'repo-%s-P%08x' % (now.strftime('%Y%m%dT%H%M%SZ'), os.getpid())

  # If it's already set, then append ourselves.
  if KEY in env:
    value = env[KEY] + '/' + value

  _setenv(KEY, value, env=env)


def _setenv(key, value, env=None):
  """Set |key| in the OS environment |env| to |value|."""
  if env is None:
    env = os.environ
  # Environment handling across systems is messy.
  try:
    env[key] = value
  except UnicodeEncodeError:
    env[key] = value.encode()


def NeedSetupGnuPG():
  if not os.path.isdir(home_dot_repo):
    return True

  kv = os.path.join(home_dot_repo, 'keyring-version')
  if not os.path.exists(kv):
    return True

  kv = open(kv).read()
  if not kv:
    return True

  kv = tuple(map(int, kv.split('.')))
  if kv < KEYRING_VERSION:
    return True
  return False


def SetupGnuPG(quiet):
  try:
    os.mkdir(home_dot_repo)
  except OSError as e:
    if e.errno != errno.EEXIST:
      print('fatal: cannot make %s directory: %s'
            % (home_dot_repo, e.strerror), file=sys.stderr)
      sys.exit(1)

  try:
    os.mkdir(gpg_dir, stat.S_IRWXU)
  except OSError as e:
    if e.errno != errno.EEXIST:
      print('fatal: cannot make %s directory: %s' % (gpg_dir, e.strerror),
            file=sys.stderr)
      sys.exit(1)

  if not quiet:
    print('repo: Updating release signing keys to keyset ver %s' %
          ('.'.join(str(x) for x in KEYRING_VERSION),))
  # NB: We use --homedir (and cwd below) because some environments (Windows) do
  # not correctly handle full native paths.  We avoid the issue by changing to
  # the right dir with cwd=gpg_dir before executing gpg, and then telling gpg to
  # use the cwd (.) as its homedir which leaves the path resolution logic to it.
  cmd = ['gpg', '--homedir', '.', '--import']
  try:
    # gpg can be pretty chatty.  Always capture the output and if something goes
    # wrong, the builtin check failure will dump stdout & stderr for debugging.
    run_command(cmd, stdin=subprocess.PIPE, capture_output=True,
                cwd=gpg_dir, check=True,
                input=MAINTAINER_KEYS.encode('utf-8'))
  except OSError:
    if not quiet:
      print('warning: gpg (GnuPG) is not available.', file=sys.stderr)
      print('warning: Installing it is strongly encouraged.', file=sys.stderr)
      print(file=sys.stderr)
    return False

  with open(os.path.join(home_dot_repo, 'keyring-version'), 'w') as fd:
    fd.write('.'.join(map(str, KEYRING_VERSION)) + '\n')
  return True


def _SetConfig(cwd, name, value):
  """Set a git configuration option to the specified value.
  """
  run_git('config', name, value, cwd=cwd)


def _GetRepoConfig(name):
  """Read a repo configuration option."""
  config = os.path.join(home_dot_repo, 'config')
  if not os.path.exists(config):
    return None

  cmd = ['config', '--file', config, '--get', name]
  ret = run_git(*cmd, check=False)
  if ret.returncode == 0:
    return ret.stdout
  elif ret.returncode == 1:
    return None
  else:
    print('repo: error: git %s failed:\n%s' % (' '.join(cmd), ret.stderr),
          file=sys.stderr)
    raise RunError()


def _InitHttp():
  handlers = []

  mgr = urllib.request.HTTPPasswordMgrWithDefaultRealm()
  try:
    import netrc
    n = netrc.netrc()
    for host in n.hosts:
      p = n.hosts[host]
      mgr.add_password(p[1], 'http://%s/' % host, p[0], p[2])
      mgr.add_password(p[1], 'https://%s/' % host, p[0], p[2])
  except Exception:
    pass
  handlers.append(urllib.request.HTTPBasicAuthHandler(mgr))
  handlers.append(urllib.request.HTTPDigestAuthHandler(mgr))

  if 'http_proxy' in os.environ:
    url = os.environ['http_proxy']
    handlers.append(urllib.request.ProxyHandler({'http': url, 'https': url}))
  if 'REPO_CURL_VERBOSE' in os.environ:
    handlers.append(urllib.request.HTTPHandler(debuglevel=1))
    handlers.append(urllib.request.HTTPSHandler(debuglevel=1))
  urllib.request.install_opener(urllib.request.build_opener(*handlers))


def _Fetch(url, cwd, src, quiet, verbose):
  cmd = ['fetch']
  if not verbose:
    cmd.append('--quiet')
  err = None
  if not quiet and sys.stdout.isatty():
    cmd.append('--progress')
  elif not verbose:
    err = subprocess.PIPE
  cmd.append(src)
  cmd.append('+refs/heads/*:refs/remotes/origin/*')
  cmd.append('+refs/tags/*:refs/tags/*')
  run_git(*cmd, stderr=err, capture_output=False, cwd=cwd)


def _DownloadBundle(url, cwd, quiet, verbose):
  if not url.endswith('/'):
    url += '/'
  url += 'clone.bundle'

  ret = run_git('config', '--get-regexp', 'url.*.insteadof', cwd=cwd,
                check=False)
  for line in ret.stdout.splitlines():
    m = re.compile(r'^url\.(.*)\.insteadof (.*)$').match(line)
    if m:
      new_url = m.group(1)
      old_url = m.group(2)
      if url.startswith(old_url):
        url = new_url + url[len(old_url):]
        break

  if not url.startswith('http:') and not url.startswith('https:'):
    return False

  dest = open(os.path.join(cwd, '.git', 'clone.bundle'), 'w+b')
  try:
    try:
      r = urllib.request.urlopen(url)
    except urllib.error.HTTPError as e:
      if e.code in [401, 403, 404, 501]:
        return False
      print('fatal: Cannot get %s' % url, file=sys.stderr)
      print('fatal: HTTP error %s' % e.code, file=sys.stderr)
      raise CloneFailure()
    except urllib.error.URLError as e:
      print('fatal: Cannot get %s' % url, file=sys.stderr)
      print('fatal: error %s' % e.reason, file=sys.stderr)
      raise CloneFailure()
    try:
      if verbose:
        print('Downloading clone bundle %s' % url, file=sys.stderr)
      while True:
        buf = r.read(8192)
        if not buf:
          return True
        dest.write(buf)
    finally:
      r.close()
  finally:
    dest.close()


def _ImportBundle(cwd):
  path = os.path.join(cwd, '.git', 'clone.bundle')
  try:
    _Fetch(cwd, cwd, path, True, False)
  finally:
    os.remove(path)


def _Clone(url, cwd, clone_bundle, quiet, verbose):
  """Clones a git repository to a new subdirectory of repodir
  """
  if verbose:
    print('Cloning git repository', url)

  try:
    os.mkdir(cwd)
  except OSError as e:
    print('fatal: cannot make %s directory: %s' % (cwd, e.strerror),
          file=sys.stderr)
    raise CloneFailure()

  run_git('init', '--quiet', cwd=cwd)

  _InitHttp()
  _SetConfig(cwd, 'remote.origin.url', url)
  _SetConfig(cwd,
             'remote.origin.fetch',
             '+refs/heads/*:refs/remotes/origin/*')
  if clone_bundle and _DownloadBundle(url, cwd, quiet, verbose):
    _ImportBundle(cwd)
  _Fetch(url, cwd, 'origin', quiet, verbose)


def resolve_repo_rev(cwd, committish):
  """Figure out what REPO_REV represents.

  We support:
  * refs/heads/xxx: Branch.
  * refs/tags/xxx: Tag.
  * xxx: Branch or tag or commit.

  Args:
    cwd: The git checkout to run in.
    committish: The REPO_REV argument to resolve.

  Returns:
    A tuple of (remote ref, commit) as makes sense for the committish.
    For branches, this will look like ('refs/heads/stable', <revision>).
    For tags, this will look like ('refs/tags/v1.0', <revision>).
    For commits, this will be (<revision>, <revision>).
  """
  def resolve(committish):
    ret = run_git('rev-parse', '--verify', '%s^{commit}' % (committish,),
                  cwd=cwd, check=False)
    return None if ret.returncode else ret.stdout.strip()

  # An explicit branch.
  if committish.startswith('refs/heads/'):
    remote_ref = committish
    committish = committish[len('refs/heads/'):]
    rev = resolve('refs/remotes/origin/%s' % committish)
    if rev is None:
      print('repo: error: unknown branch "%s"' % (committish,),
            file=sys.stderr)
      raise CloneFailure()
    return (remote_ref, rev)

  # An explicit tag.
  if committish.startswith('refs/tags/'):
    remote_ref = committish
    committish = committish[len('refs/tags/'):]
    rev = resolve(remote_ref)
    if rev is None:
      print('repo: error: unknown tag "%s"' % (committish,),
            file=sys.stderr)
      raise CloneFailure()
    return (remote_ref, rev)

  # See if it's a short branch name.
  rev = resolve('refs/remotes/origin/%s' % committish)
  if rev:
    return ('refs/heads/%s' % (committish,), rev)

  # See if it's a tag.
  rev = resolve('refs/tags/%s' % committish)
  if rev:
    return ('refs/tags/%s' % (committish,), rev)

  # See if it's a commit.
  rev = resolve(committish)
  if rev and rev.lower().startswith(committish.lower()):
    return (rev, rev)

  # Give up!
  print('repo: error: unable to resolve "%s"' % (committish,), file=sys.stderr)
  raise CloneFailure()


def verify_rev(cwd, remote_ref, rev, quiet):
  """Verify the commit has been signed by a tag."""
  ret = run_git('describe', rev, cwd=cwd)
  cur = ret.stdout.strip()

  m = re.compile(r'^(.*)-[0-9]{1,}-g[0-9a-f]{1,}$').match(cur)
  if m:
    cur = m.group(1)
    if not quiet:
      print(file=sys.stderr)
      print("warning: '%s' is not signed; falling back to signed release '%s'"
            % (remote_ref, cur), file=sys.stderr)
      print(file=sys.stderr)

  env = os.environ.copy()
  _setenv('GNUPGHOME', gpg_dir, env)
  run_git('tag', '-v', cur, cwd=cwd, env=env)
  return '%s^0' % cur


def _Checkout(cwd, remote_ref, rev, quiet):
  """Checkout an upstream branch into the repository and track it.
  """
  run_git('update-ref', 'refs/heads/default', rev, cwd=cwd)

  _SetConfig(cwd, 'branch.default.remote', 'origin')
  _SetConfig(cwd, 'branch.default.merge', remote_ref)

  run_git('symbolic-ref', 'HEAD', 'refs/heads/default', cwd=cwd)

  cmd = ['read-tree', '--reset', '-u']
  if not quiet:
    cmd.append('-v')
  cmd.append('HEAD')
  run_git(*cmd, cwd=cwd)


def _FindRepo():
  """Look for a repo installation, starting at the current directory.
  """
  curdir = os.getcwd()
  repo = None

  olddir = None
  while curdir != '/' \
          and curdir != olddir \
          and not repo:
    repo = os.path.join(curdir, repodir, REPO_MAIN)
    if not os.path.isfile(repo):
      repo = None
      olddir = curdir
      curdir = os.path.dirname(curdir)
  return (repo, os.path.join(curdir, repodir))


class _Options(object):
  help = False
  version = False


def _ExpandAlias(name):
  """Look up user registered aliases."""
  # We don't resolve aliases for existing subcommands.  This matches git.
  if name in {'gitc-init', 'help', 'init'}:
    return name, []

  alias = _GetRepoConfig('alias.%s' % (name,))
  if alias is None:
    return name, []

  args = alias.strip().split(' ', 1)
  name = args[0]
  if len(args) == 2:
    args = shlex.split(args[1])
  else:
    args = []
  return name, args


def _ParseArguments(args):
  cmd = None
  opt = _Options()
  arg = []

  for i in range(len(args)):
    a = args[i]
    if a == '-h' or a == '--help':
      opt.help = True
    elif a == '--version':
      opt.version = True
    elif a == '--trace':
      trace.set(True)
    elif not a.startswith('-'):
      cmd = a
      arg = args[i + 1:]
      break
  return cmd, opt, arg


def _Usage():
  gitc_usage = ""
  if get_gitc_manifest_dir():
    gitc_usage = "  gitc-init Initialize a GITC Client.\n"

  print(
      """usage: repo COMMAND [ARGS]

repo is not yet installed.  Use "repo init" to install it here.

The most commonly used repo commands are:

  init      Install repo in the current working directory
""" + gitc_usage +
      """  help      Display detailed help on a command

For access to the full online help, install repo ("repo init").
""")
  sys.exit(0)


def _Help(args):
  if args:
    if args[0] in {'init', 'gitc-init'}:
      parser = GetParser(gitc_init=args[0] == 'gitc-init')
      parser.print_help()
      sys.exit(0)
    else:
      print("error: '%s' is not a bootstrap command.\n"
            '        For access to online help, install repo ("repo init").'
            % args[0], file=sys.stderr)
  else:
    _Usage()
  sys.exit(1)


def _Version():
  """Show version information."""
  print('<repo not installed>')
  print('repo launcher version %s' % ('.'.join(str(x) for x in VERSION),))
  print('       (from %s)' % (__file__,))
  print('git %s' % (ParseGitVersion().full,))
  print('Python %s' % sys.version)
  uname = platform.uname()
  if sys.version_info.major < 3:
    # Python 3 returns a named tuple, but Python 2 is simpler.
    print(uname)
  else:
    print('OS %s %s (%s)' % (uname.system, uname.release, uname.version))
    print('CPU %s (%s)' %
          (uname.machine, uname.processor if uname.processor else 'unknown'))
  sys.exit(0)


def _NotInstalled():
  print('error: repo is not installed.  Use "repo init" to install it here.',
        file=sys.stderr)
  sys.exit(1)


def _NoCommands(cmd):
  print("""error: command '%s' requires repo to be installed first.
        Use "repo init" to install it here.""" % cmd, file=sys.stderr)
  sys.exit(1)


def _RunSelf(wrapper_path):
  my_dir = os.path.dirname(wrapper_path)
  my_main = os.path.join(my_dir, 'main.py')
  my_git = os.path.join(my_dir, '.git')

  if os.path.isfile(my_main) and os.path.isdir(my_git):
    for name in ['git_config.py',
                 'project.py',
                 'subcmds']:
      if not os.path.exists(os.path.join(my_dir, name)):
        return None, None
    return my_main, my_git
  return None, None


def _SetDefaultsTo(gitdir):
  global REPO_URL
  global REPO_REV

  REPO_URL = gitdir
  ret = run_git('--git-dir=%s' % gitdir, 'symbolic-ref', 'HEAD', check=False)
  if ret.returncode:
    # If we're not tracking a branch (bisect/etc...), then fall back to commit.
    print('repo: warning: %s has no current branch; using HEAD' % gitdir,
          file=sys.stderr)
    try:
      ret = run_git('rev-parse', 'HEAD', cwd=gitdir)
    except CloneFailure:
      print('fatal: %s has invalid HEAD' % gitdir, file=sys.stderr)
      sys.exit(1)

  REPO_REV = ret.stdout.strip()


def main(orig_args):
  cmd, opt, args = _ParseArguments(orig_args)

  # We run this early as we run some git commands ourselves.
  SetGitTrace2ParentSid()

  repo_main, rel_repo_dir = None, None
  # Don't use the local repo copy, make sure to switch to the gitc client first.
  if cmd != 'gitc-init':
    repo_main, rel_repo_dir = _FindRepo()

  wrapper_path = os.path.abspath(__file__)
  my_main, my_git = _RunSelf(wrapper_path)

  cwd = os.getcwd()
  if get_gitc_manifest_dir() and cwd.startswith(get_gitc_manifest_dir()):
    print('error: repo cannot be used in the GITC local manifest directory.'
          '\nIf you want to work on this GITC client please rerun this '
          'command from the corresponding client under /gitc/',
          file=sys.stderr)
    sys.exit(1)
  if not repo_main:
    # Only expand aliases here since we'll be parsing the CLI ourselves.
    # If we had repo_main, alias expansion would happen in main.py.
    cmd, alias_args = _ExpandAlias(cmd)
    args = alias_args + args

    if opt.help:
      _Usage()
    if cmd == 'help':
      _Help(args)
    if opt.version or cmd == 'version':
      _Version()
    if not cmd:
      _NotInstalled()
    if cmd == 'init' or cmd == 'gitc-init':
      if my_git:
        _SetDefaultsTo(my_git)
      try:
        _Init(args, gitc_init=(cmd == 'gitc-init'))
      except CloneFailure:
        path = os.path.join(repodir, S_repo)
        print("fatal: cloning the git-repo repository failed, will remove "
              "'%s' " % path, file=sys.stderr)
        shutil.rmtree(path, ignore_errors=True)
        sys.exit(1)
      repo_main, rel_repo_dir = _FindRepo()
    else:
      _NoCommands(cmd)

  if my_main:
    repo_main = my_main

  if not repo_main:
    print("fatal: unable to find repo entry point", file=sys.stderr)
    sys.exit(1)

  ver_str = '.'.join(map(str, VERSION))
  me = [sys.executable, repo_main,
        '--repo-dir=%s' % rel_repo_dir,
        '--wrapper-version=%s' % ver_str,
        '--wrapper-path=%s' % wrapper_path,
        '--']
  me.extend(orig_args)
  exec_command(me)
  print("fatal: unable to start %s" % repo_main, file=sys.stderr)
  sys.exit(148)


if __name__ == '__main__':
  main(sys.argv[1:])
