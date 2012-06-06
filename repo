#!/bin/sh

## repo default configuration
##
REPO_URL='https://gerrit.googlesource.com/git-repo'
REPO_REV='stable'

# Copyright (C) 2008 Google Inc.
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

magic='--calling-python-from-/bin/sh--'
"""exec" python -E "$0" "$@" """#$magic"
if __name__ == '__main__':
  import sys
  if sys.argv[-1] == '#%s' % magic:
    del sys.argv[-1]
del magic

# increment this whenever we make important changes to this script
VERSION = (1, 17)

# increment this if the MAINTAINER_KEYS block is modified
KEYRING_VERSION = (1,0)
MAINTAINER_KEYS = """

     Repo Maintainer <repo@android.kernel.org>
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.2.2 (GNU/Linux)

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
=CMiZ
-----END PGP PUBLIC KEY BLOCK-----
"""

GIT = 'git'                     # our git command
MIN_GIT_VERSION = (1, 5, 4)     # minimum supported git version
repodir = '.repo'               # name of repo's private directory
S_repo = 'repo'                 # special repo reposiory
S_manifests = 'manifests'       # special manifest repository
REPO_MAIN = S_repo + '/main.py' # main script


import optparse
import os
import re
import readline
import subprocess
import sys
import urllib2

home_dot_repo = os.path.expanduser('~/.repoconfig')
gpg_dir = os.path.join(home_dot_repo, 'gnupg')

extra_args = []
init_optparse = optparse.OptionParser(usage="repo init -u url [options]")

# Logging
group = init_optparse.add_option_group('Logging options')
group.add_option('-q', '--quiet',
                 dest="quiet", action="store_true", default=False,
                 help="be quiet")

# Manifest
group = init_optparse.add_option_group('Manifest options')
group.add_option('-u', '--manifest-url',
                 dest='manifest_url',
                 help='manifest repository location', metavar='URL')
group.add_option('-b', '--manifest-branch',
                 dest='manifest_branch',
                 help='manifest branch or revision', metavar='REVISION')
group.add_option('-m', '--manifest-name',
                 dest='manifest_name',
                 help='initial manifest file', metavar='NAME.xml')
group.add_option('--mirror',
                 dest='mirror', action='store_true',
                 help='mirror the forrest')
group.add_option('--reference',
                 dest='reference',
                 help='location of mirror directory', metavar='DIR')
group.add_option('--depth', type='int', default=None,
                 dest='depth',
                 help='create a shallow clone with given depth; see git clone')
group.add_option('-g', '--groups',
                 dest='groups', default='default',
                 help='restrict manifest projects to ones with a specified group',
                 metavar='GROUP')
group.add_option('-p', '--platform',
                 dest='platform', default="auto",
                 help='restrict manifest projects to ones with a specified'
                      'platform group [auto|all|none|linux|darwin|...]',
                 metavar='PLATFORM')


# Tool
group = init_optparse.add_option_group('repo Version options')
group.add_option('--repo-url',
                 dest='repo_url',
                 help='repo repository location', metavar='URL')
group.add_option('--repo-branch',
                 dest='repo_branch',
                 help='repo branch or revision', metavar='REVISION')
group.add_option('--no-repo-verify',
                 dest='no_repo_verify', action='store_true',
                 help='do not verify repo source code')

# Other
group = init_optparse.add_option_group('Other options')
group.add_option('--config-name',
                 dest='config_name', action="store_true", default=False,
                 help='Always prompt for name/e-mail')

class CloneFailure(Exception):
  """Indicate the remote clone of repo itself failed.
  """


def _Init(args):
  """Installs repo by cloning it over the network.
  """
  opt, args = init_optparse.parse_args(args)
  if args:
    init_optparse.print_usage()
    sys.exit(1)

  url = opt.repo_url
  if not url:
    url = REPO_URL
    extra_args.append('--repo-url=%s' % url)

  branch = opt.repo_branch
  if not branch:
    branch = REPO_REV
    extra_args.append('--repo-branch=%s' % branch)

  if branch.startswith('refs/heads/'):
    branch = branch[len('refs/heads/'):]
  if branch.startswith('refs/'):
    print >>sys.stderr, "fatal: invalid branch name '%s'" % branch
    raise CloneFailure()

  if not os.path.isdir(repodir):
    try:
      os.mkdir(repodir)
    except OSError, e:
      print >>sys.stderr, \
            'fatal: cannot make %s directory: %s' % (
            repodir, e.strerror)
      # Don't faise CloneFailure; that would delete the
      # name. Instead exit immediately.
      #
      sys.exit(1)

  _CheckGitVersion()
  try:
    if _NeedSetupGnuPG():
      can_verify = _SetupGnuPG(opt.quiet)
    else:
      can_verify = True

    dst = os.path.abspath(os.path.join(repodir, S_repo))
    _Clone(url, dst, opt.quiet)

    if can_verify and not opt.no_repo_verify:
      rev = _Verify(dst, branch, opt.quiet)
    else:
      rev = 'refs/remotes/origin/%s^0' % branch

    _Checkout(dst, branch, rev, opt.quiet)
  except CloneFailure:
    if opt.quiet:
      print >>sys.stderr, \
        'fatal: repo init failed; run without --quiet to see why'
    raise


def _CheckGitVersion():
  cmd = [GIT, '--version']
  try:
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
  except OSError, e:
    print >>sys.stderr
    print >>sys.stderr, "fatal: '%s' is not available" % GIT
    print >>sys.stderr, 'fatal: %s' % e
    print >>sys.stderr
    print >>sys.stderr, 'Please make sure %s is installed'\
                        ' and in your path.' % GIT
    raise CloneFailure()

  ver_str = proc.stdout.read().strip()
  proc.stdout.close()
  proc.wait()

  if not ver_str.startswith('git version '):
    print >>sys.stderr, 'error: "%s" unsupported' % ver_str
    raise CloneFailure()

  ver_str = ver_str[len('git version '):].strip()
  ver_act = tuple(map(lambda x: int(x), ver_str.split('.')[0:3]))
  if ver_act < MIN_GIT_VERSION:
    need = '.'.join(map(lambda x: str(x), MIN_GIT_VERSION))
    print >>sys.stderr, 'fatal: git %s or later required' % need
    raise CloneFailure()


def _NeedSetupGnuPG():
  if not os.path.isdir(home_dot_repo):
    return True

  kv = os.path.join(home_dot_repo, 'keyring-version')
  if not os.path.exists(kv):
    return True

  kv = open(kv).read()
  if not kv:
    return True

  kv = tuple(map(lambda x: int(x), kv.split('.')))
  if kv < KEYRING_VERSION:
    return True
  return False


def _SetupGnuPG(quiet):
  if not os.path.isdir(home_dot_repo):
    try:
      os.mkdir(home_dot_repo)
    except OSError, e:
      print >>sys.stderr, \
            'fatal: cannot make %s directory: %s' % (
            home_dot_repo, e.strerror)
      sys.exit(1)

  if not os.path.isdir(gpg_dir):
    try:
      os.mkdir(gpg_dir, 0700)
    except OSError, e:
      print >>sys.stderr, \
            'fatal: cannot make %s directory: %s' % (
            gpg_dir, e.strerror)
      sys.exit(1)

  env = os.environ.copy()
  env['GNUPGHOME'] = gpg_dir.encode()

  cmd = ['gpg', '--import']
  try:
    proc = subprocess.Popen(cmd,
                            env = env,
                            stdin = subprocess.PIPE)
  except OSError, e:
    if not quiet:
      print >>sys.stderr, 'warning: gpg (GnuPG) is not available.'
      print >>sys.stderr, 'warning: Installing it is strongly encouraged.'
      print >>sys.stderr
    return False

  proc.stdin.write(MAINTAINER_KEYS)
  proc.stdin.close()

  if proc.wait() != 0:
    print >>sys.stderr, 'fatal: registering repo maintainer keys failed'
    sys.exit(1)
  print

  fd = open(os.path.join(home_dot_repo, 'keyring-version'), 'w')
  fd.write('.'.join(map(lambda x: str(x), KEYRING_VERSION)) + '\n')
  fd.close()
  return True


def _SetConfig(local, name, value):
  """Set a git configuration option to the specified value.
  """
  cmd = [GIT, 'config', name, value]
  if subprocess.Popen(cmd, cwd = local).wait() != 0:
    raise CloneFailure()


def _InitHttp():
  handlers = []

  mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
  try:
    import netrc
    n = netrc.netrc()
    for host in n.hosts:
      p = n.hosts[host]
      mgr.add_password(p[1], 'http://%s/'  % host, p[0], p[2])
      mgr.add_password(p[1], 'https://%s/' % host, p[0], p[2])
  except:
    pass
  handlers.append(urllib2.HTTPBasicAuthHandler(mgr))
  handlers.append(urllib2.HTTPDigestAuthHandler(mgr))

  if 'http_proxy' in os.environ:
    url = os.environ['http_proxy']
    handlers.append(urllib2.ProxyHandler({'http': url, 'https': url}))
  if 'REPO_CURL_VERBOSE' in os.environ:
    handlers.append(urllib2.HTTPHandler(debuglevel=1))
    handlers.append(urllib2.HTTPSHandler(debuglevel=1))
  urllib2.install_opener(urllib2.build_opener(*handlers))

def _Fetch(url, local, src, quiet):
  if not quiet:
    print >>sys.stderr, 'Get %s' % url

  cmd = [GIT, 'fetch']
  if quiet:
    cmd.append('--quiet')
    err = subprocess.PIPE
  else:
    err = None
  cmd.append(src)
  cmd.append('+refs/heads/*:refs/remotes/origin/*')
  cmd.append('refs/tags/*:refs/tags/*')

  proc = subprocess.Popen(cmd, cwd = local, stderr = err)
  if err:
    proc.stderr.read()
    proc.stderr.close()
  if proc.wait() != 0:
    raise CloneFailure()

def _DownloadBundle(url, local, quiet):
  if not url.endswith('/'):
    url += '/'
  url += 'clone.bundle'

  proc = subprocess.Popen(
    [GIT, 'config', '--get-regexp', 'url.*.insteadof'],
    cwd = local,
    stdout = subprocess.PIPE)
  for line in proc.stdout:
    m = re.compile(r'^url\.(.*)\.insteadof (.*)$').match(line)
    if m:
      new_url = m.group(1)
      old_url = m.group(2)
      if url.startswith(old_url):
        url = new_url + url[len(old_url):]
        break
  proc.stdout.close()
  proc.wait()

  if not url.startswith('http:') and not url.startswith('https:'):
    return False

  dest = open(os.path.join(local, '.git', 'clone.bundle'), 'w+b')
  try:
    try:
      r = urllib2.urlopen(url)
    except urllib2.HTTPError, e:
      if e.code == 404:
        return False
      print >>sys.stderr, 'fatal: Cannot get %s' % url
      print >>sys.stderr, 'fatal: HTTP error %s' % e.code
      raise CloneFailure()
    except urllib2.URLError, e:
      print >>sys.stderr, 'fatal: Cannot get %s' % url
      print >>sys.stderr, 'fatal: error %s' % e.reason
      raise CloneFailure()
    try:
      if not quiet:
        print >>sys.stderr, 'Get %s' % url
      while True:
        buf = r.read(8192)
        if buf == '':
          return True
        dest.write(buf)
    finally:
      r.close()
  finally:
    dest.close()

def _ImportBundle(local):
  path = os.path.join(local, '.git', 'clone.bundle')
  try:
    _Fetch(local, local, path, True)
  finally:
    os.remove(path)

def _Clone(url, local, quiet):
  """Clones a git repository to a new subdirectory of repodir
  """
  try:
    os.mkdir(local)
  except OSError, e:
    print >>sys.stderr, \
          'fatal: cannot make %s directory: %s' \
          % (local, e.strerror)
    raise CloneFailure()

  cmd = [GIT, 'init', '--quiet']
  try:
    proc = subprocess.Popen(cmd, cwd = local)
  except OSError, e:
    print >>sys.stderr
    print >>sys.stderr, "fatal: '%s' is not available" % GIT
    print >>sys.stderr, 'fatal: %s' % e
    print >>sys.stderr
    print >>sys.stderr, 'Please make sure %s is installed'\
                        ' and in your path.' % GIT
    raise CloneFailure()
  if proc.wait() != 0:
    print >>sys.stderr, 'fatal: could not create %s' % local
    raise CloneFailure()

  _InitHttp()
  _SetConfig(local, 'remote.origin.url', url)
  _SetConfig(local, 'remote.origin.fetch',
                    '+refs/heads/*:refs/remotes/origin/*')
  if _DownloadBundle(url, local, quiet):
    _ImportBundle(local)
  else:
    _Fetch(url, local, 'origin', quiet)


def _Verify(cwd, branch, quiet):
  """Verify the branch has been signed by a tag.
  """
  cmd = [GIT, 'describe', 'origin/%s' % branch]
  proc = subprocess.Popen(cmd,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE,
                          cwd = cwd)
  cur = proc.stdout.read().strip()
  proc.stdout.close()

  proc.stderr.read()
  proc.stderr.close()

  if proc.wait() != 0 or not cur:
    print >>sys.stderr
    print >>sys.stderr,\
      "fatal: branch '%s' has not been signed" \
      % branch
    raise CloneFailure()

  m = re.compile(r'^(.*)-[0-9]{1,}-g[0-9a-f]{1,}$').match(cur)
  if m:
    cur = m.group(1)
    if not quiet:
      print >>sys.stderr
      print >>sys.stderr, \
        "info: Ignoring branch '%s'; using tagged release '%s'" \
        % (branch, cur)
      print >>sys.stderr

  env = os.environ.copy()
  env['GNUPGHOME'] = gpg_dir.encode()

  cmd = [GIT, 'tag', '-v', cur]
  proc = subprocess.Popen(cmd,
                          stdout = subprocess.PIPE,
                          stderr = subprocess.PIPE,
                          cwd = cwd,
                          env = env)
  out = proc.stdout.read()
  proc.stdout.close()

  err = proc.stderr.read()
  proc.stderr.close()

  if proc.wait() != 0:
    print >>sys.stderr
    print >>sys.stderr, out
    print >>sys.stderr, err
    print >>sys.stderr
    raise CloneFailure()
  return '%s^0' % cur


def _Checkout(cwd, branch, rev, quiet):
  """Checkout an upstream branch into the repository and track it.
  """
  cmd = [GIT, 'update-ref', 'refs/heads/default', rev]
  if subprocess.Popen(cmd, cwd = cwd).wait() != 0:
    raise CloneFailure()

  _SetConfig(cwd, 'branch.default.remote', 'origin')
  _SetConfig(cwd, 'branch.default.merge', 'refs/heads/%s' % branch)

  cmd = [GIT, 'symbolic-ref', 'HEAD', 'refs/heads/default']
  if subprocess.Popen(cmd, cwd = cwd).wait() != 0:
    raise CloneFailure()

  cmd = [GIT, 'read-tree', '--reset', '-u']
  if not quiet:
    cmd.append('-v')
  cmd.append('HEAD')
  if subprocess.Popen(cmd, cwd = cwd).wait() != 0:
    raise CloneFailure()


def _FindRepo():
  """Look for a repo installation, starting at the current directory.
  """
  dir = os.getcwd()
  repo = None

  olddir = None
  while dir != '/' \
    and dir != olddir \
    and not repo:
    repo = os.path.join(dir, repodir, REPO_MAIN)
    if not os.path.isfile(repo):
      repo = None
      olddir = dir
      dir = os.path.dirname(dir)
  return (repo, os.path.join(dir, repodir))


class _Options:
  help = False


def _ParseArguments(args):
  cmd = None
  opt = _Options()
  arg = []

  for i in xrange(0, len(args)):
    a = args[i]
    if a == '-h' or a == '--help':
      opt.help = True

    elif not a.startswith('-'):
      cmd = a
      arg = args[i + 1:]
      break
  return cmd, opt, arg


def _Usage():
  print >>sys.stderr,\
"""usage: repo COMMAND [ARGS]

repo is not yet installed.  Use "repo init" to install it here.

The most commonly used repo commands are:

  init      Install repo in the current working directory
  help      Display detailed help on a command

For access to the full online help, install repo ("repo init").
"""
  sys.exit(1)


def _Help(args):
  if args:
    if args[0] == 'init':
      init_optparse.print_help()
      sys.exit(0)
    else:
      print >>sys.stderr,\
      "error: '%s' is not a bootstrap command.\n"\
      '        For access to online help, install repo ("repo init").'\
      % args[0]
  else:
    _Usage()
  sys.exit(1)


def _NotInstalled():
  print >>sys.stderr,\
'error: repo is not installed.  Use "repo init" to install it here.'
  sys.exit(1)


def _NoCommands(cmd):
  print >>sys.stderr,\
"""error: command '%s' requires repo to be installed first.
       Use "repo init" to install it here.""" % cmd
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
  proc = subprocess.Popen([GIT,
                           '--git-dir=%s' % gitdir,
                           'symbolic-ref',
                           'HEAD'],
                          stdout = subprocess.PIPE,
                          stderr = subprocess.PIPE)
  REPO_REV = proc.stdout.read().strip()
  proc.stdout.close()

  proc.stderr.read()
  proc.stderr.close()

  if proc.wait() != 0:
    print >>sys.stderr, 'fatal: %s has no current branch' % gitdir
    sys.exit(1)


def main(orig_args):
  main, dir = _FindRepo()
  cmd, opt, args = _ParseArguments(orig_args)

  wrapper_path = os.path.abspath(__file__)
  my_main, my_git = _RunSelf(wrapper_path)

  if not main:
    if opt.help:
      _Usage()
    if cmd == 'help':
      _Help(args)
    if not cmd:
      _NotInstalled()
    if cmd == 'init':
      if my_git:
        _SetDefaultsTo(my_git)
      try:
        _Init(args)
      except CloneFailure:
        for root, dirs, files in os.walk(repodir, topdown=False):
          for name in files:
            os.remove(os.path.join(root, name))
          for name in dirs:
            os.rmdir(os.path.join(root, name))
        os.rmdir(repodir)
        sys.exit(1)
      main, dir = _FindRepo()
    else:
      _NoCommands(cmd)

  if my_main:
    main = my_main

  ver_str = '.'.join(map(lambda x: str(x), VERSION))
  me = [main,
        '--repo-dir=%s' % dir,
        '--wrapper-version=%s' % ver_str,
        '--wrapper-path=%s' % wrapper_path,
        '--']
  me.extend(orig_args)
  me.extend(extra_args)
  try:
    os.execv(main, me)
  except OSError, e:
    print >>sys.stderr, "fatal: unable to start %s" % main
    print >>sys.stderr, "fatal: %s" % e
    sys.exit(148)


if __name__ == '__main__':
  main(sys.argv[1:])
