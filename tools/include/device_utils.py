'''Utilities for interacting with a remote device.'''

from __future__ import print_function
from __future__ import division

import os
import sys
import re
import subprocess
import textwrap
from time import sleep

def remote_shell(cmd):
    '''Run the given command on on the device and return stdout.  Throw an
    exception if the remote command returns a non-zero return code.

    Don't use this command for programs included in /system/bin/toolbox, such
    as ls and ps; instead, use remote_toolbox_cmd.

    adb shell doesn't check the remote command's error code.  So to check this
    ourselves, we echo $? after running the command and then strip that off
    before returning the command's output.

    '''
    out = shell(r"""adb shell '%s; echo -n "|$?"'""" % cmd)

    # The final '\n' in |out| separates the command output from the return
    # code.  (There's no newline after the return code because we did echo -n.)
    (cmd_out, _, retcode) = out.rpartition('|')
    retcode = retcode.strip()

    if retcode == '0':
        return cmd_out

    print('Remote command %s failed with error code %s' % (cmd, retcode),
          file=sys.stderr)
    if cmd_out:
        print(cmd_out, file=sys.stderr)
    raise subprocess.CalledProcessError(retcode, cmd, cmd_out)

def remote_toolbox_cmd(cmd, args=''):
    '''Run the given command from /system/bin/toolbox on the device.  Pass
    args, if specified, and return stdout.  Throw an exception if the command
    returns a non-zero return code.

    cmd must be a command that's part of /system/bin/toolbox.  If you want to
    run an arbitrary command, use remote_shell.

    Use remote_toolbox_cmd instead of remote_shell if you're invoking a program
    that's included in /system/bin/toolbox.  remote_toolbox_cmd will ensure
    that we use the toolbox's version, instead of busybox's version, even if
    busybox is installed on the system.  This will ensure that we get
    the same output regardless of whether busybox is installed.

    '''
    return remote_shell('/system/bin/toolbox "%s" %s' % (cmd, args))

def remote_ls(dir):
    '''Run ls on the remote device, and return a set containing the results.'''
    return {f.strip() for f in remote_toolbox_cmd('ls', dir).split('\n')}

def shell(cmd, cwd=None, show_errors=True):
    '''Run the given command as a shell script on the host machine.

    If cwd is specified, we run the command from that directory; otherwise, we
    run the command from the current working directory.

    '''
    proc = subprocess.Popen(cmd, shell=True, cwd=cwd,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()
    if proc.returncode:
        if show_errors:
            print('Command %s failed with error code %d' %
                  (cmd, proc.returncode), file=sys.stderr)
            if err:
                print(err, file=sys.stderr)
        raise subprocess.CalledProcessError(proc.returncode, cmd, err)
    return out

def create_specific_output_dir(out_dir):
    '''Create the given directory if it doesn't exist.

    Throw an exception if a non-directory file exists with the same name.

    '''
    if os.path.exists(out_dir):
        if os.path.isdir(out_dir):
            # Directory already exists; we're all good.
            return
        else:
            raise Exception(textwrap.dedent('''\
                Can't use %s as output directory; something that's not a
                directory already exists with that name.''' % out_dir))
    os.mkdir(out_dir)

def create_new_output_dir(out_dir_prefix):
    '''Create a new directory whose name begins with out_dir_prefix.'''
    for i in range(0, 1024):
        try:
            dir = '%s%d' % (out_dir_prefix, i)
            os.mkdir(dir)
            return dir
        except:
            pass
    raise Exception("Couldn't create output directory.")

def get_remote_b2g_pids():
    '''Get the pids of all gecko processes running on the device.

    Returns a tuple (master_pid, child_pids), where child_pids is a list.

    '''
    procs = remote_toolbox_cmd('ps').split('\n')
    master_pid = None
    child_pids = []
    for line in procs:
        if re.search(r'/b2g\s*$', line):
            if master_pid:
                raise Exception('Two copies of b2g process found?')
            master_pid = int(line.split()[1])
        if re.search(r'/plugin-container\s*$', line):
            child_pids.append(int(line.split()[1]))

    if not master_pid:
        raise Exception('b2g does not appear to be running on the device.')

    return (master_pid, child_pids)

def pull_procrank_etc(out_dir):
    '''Get the output of procrank and a few other diagnostic programs and save
    it into out_dir.

    '''
    shell('adb shell b2g-info > b2g-info', cwd=out_dir)
    shell('adb shell procrank > procrank', cwd=out_dir)
    shell('adb shell b2g-ps > b2g-ps', cwd=out_dir)
    shell('adb shell b2g-procrank > b2g-procrank', cwd=out_dir)

def run_and_delete_dir_on_exception(fun, dir):
    '''Run the given function and, if it throws an exception, delete the given
    directory, if it's empty, before re-throwing the exception.

    You might want to wrap your call to send_signal_and_pull_files in this
    function.'''
    try:
        return fun()
    except:
        # os.rmdir will throw if the directory is non-empty, and a simple
        # 'raise' will re-throw the exception from os.rmdir (if that throws),
        # so we need to explicitly save the exception info here.  See
        # http://nedbatchelder.com/blog/200711/rethrowing_exceptions_in_python.html
        exception_info = sys.exc_info()

        try:
            # Throws if the directory is not empty.
            os.rmdir(dir)
        except OSError:
            pass

        # Raise the original exception.
        raise exception_info[1], None, exception_info[2]

def notify_and_pull_files(outfiles_prefixes,
                          remove_outfiles_from_device,
                          out_dir,
                          optional_outfiles_prefixes=[],
                          fifo_msg=None,
                          signal=None,
                          ignore_nuwa=os.getenv("MOZ_IGNORE_NUWA_PROCESS")):
    '''Send a message to the main B2G process (either by sending it a signal or
    by writing to a fifo that it monitors) and pull files created as a result.

    Exactly one of fifo_msg or signal must be non-null; otherwise, we throw
    an exception.

    If fifo_msg is non-null, we write fifo_msg to
    /data/local/debug_info_trigger.  When this comment was written, B2G
    understood the messages 'memory report', 'minimize memory report', and 'gc
    log'.  See nsMemoryInfoDumper.cpp's FifoWatcher.

    If signal is non-null, we send the given signal (which may be either a
    number or a string of the form 'SIGRTn', which we interpret as the signal
    SIGRTMIN + n).

    After writing to the fifo or sending the signal, we pull the files
    generated into out_dir on the host machine.  We only pull files which were
    created after the signal was sent.

    When we're done, we remove the files from the device if
    remote_outfiles_from_device is true.

    outfiles_prefixes must be a list containing the beginnings of the files we
    expect to be created as a result of the signal.  For example, if we expect
    to see files named 'foo-XXX' and 'bar-YYY', we'd set outfiles_prefixes to
    ['foo-', 'bar-'].

    We expect to pull len(outfiles_prefixes) * (# b2g processes) files from the
    device.  If that succeeds, we then pull all files which match
    optional_outfiles_prefixes.

    '''

    if (fifo_msg == None) == (signal == None):
        raise ValueError("Exactly one of the fifo_msg and "
                         "signal kw args must be non-null.")

    (master_pid, child_pids) = get_remote_b2g_pids()
    old_files = _list_remote_temp_files(outfiles_prefixes)

    if signal != None:
        _send_remote_signal(signal, master_pid)
    else:
        _write_to_remote_file('/data/local/debug_info_trigger', fifo_msg)

    all_outfiles_prefixes = outfiles_prefixes + optional_outfiles_prefixes

    num_expected_responses = 1 + len(child_pids)
    if ignore_nuwa:
        num_expected_responses -= 1
    num_expected_files = len(outfiles_prefixes) * num_expected_responses
    _wait_for_remote_files(outfiles_prefixes, num_expected_files, old_files)
    new_files = _pull_remote_files(all_outfiles_prefixes, old_files, out_dir)
    if remove_outfiles_from_device:
        _remove_files_from_device(all_outfiles_prefixes, old_files)
    return [os.path.basename(f) for f in new_files]


# You probably don't need to call the functions below from outside this module,
# but hey, maybe you do.

def _send_remote_signal(signal, pid):
    '''Send a signal to a process on the device.

    signal can be either an integer or a string of the form 'SIGRTn' where n is
    an integer.  We interpret SIGRTn to mean the signal SIGRTMIN + n.

    '''
    # killer is a program we put on the device which is like kill(1), except it
    # accepts signals above 31.  It also understands "SIGRTn" per above.
    remote_shell("killer %s %d" % (signal, pid))

def _write_to_remote_file(file, msg):
    '''Write a message to a file on the device.

    Note that echo is a shell built-in, so we use remote_shell, not
    remote_toolbox_cmd, here.

    Also, due to ghetto string escaping in remote_shell, we must use " and not
    ' in this command.

    '''
    remote_shell('echo -n "%s" > "%s"' % (msg, file))

def _list_remote_temp_files(prefixes):
    '''Return a set of absolute filenames in the device's temp directory which
    start with one of the given prefixes.'''

    # Look for files in both /data/local/tmp/ and
    # /data/local/tmp/memory-reports.  New versions of b2g dump everything into
    # /data/local/tmp/memory-reports, but old versions use /data/local/tmp for
    # some things (e.g. gc/cc logs).
    tmpdir = '/data/local/tmp/'
    outdirs = [d for d in [tmpdir, os.path.join(tmpdir, 'memory-reports')] if
               os.path.basename(d) in remote_ls(os.path.dirname(d))]

    found_files = set()
    for d in outdirs:
        found_files |= {os.path.join(d, file) for file in remote_ls(d)
                        if any(file.startswith(prefix) for prefix in prefixes)}

    return found_files

def _wait_for_remote_files(outfiles_prefixes, num_expected_files, old_files):
    '''Wait for files to appear on the remote device.

    We wait until we see num_expected_files whose names begin with one of the
    elements of outfiles_prefixes and which aren't in old_files appear in the
    device's temp directory.  If we don't see these files after a timeout
    expires, we throw an exception.

    '''
    wait_interval = .25
    max_wait = 60 * 2

    for i in range(0, int(max_wait / wait_interval)):
        new_files = _list_remote_temp_files(outfiles_prefixes) - old_files

        # For some reason, print() doesn't work with the \r hack.
        sys.stdout.write('\rGot %d/%d files.' %
                         (len(new_files), num_expected_files))
        sys.stdout.flush()

        if len(new_files) == num_expected_files:
            print('')
            return

        sleep(wait_interval)

    print("We've waited %ds but the only relevant files we see are" % max_wait)
    print('\n'.join(['  ' + f for f in new_files]))
    print('We expected %d but see only %d files.  Giving up...' %
          (num_expected_files, len(new_files)))
    raise Exception("Unable to pull some files.")

def _pull_remote_files(outfiles_prefixes, old_files, out_dir):
    '''Pull files from the remote device's temp directory into out_dir.

    We pull each file in the temp directory whose name begins with one of the
    elements of outfiles_prefixes and which isn't listed in old_files.

    '''
    new_files = _list_remote_temp_files(outfiles_prefixes) - old_files
    for f in new_files:
        shell('adb pull %s' % f, cwd=out_dir)
        pass
    print("Pulled files into %s." % out_dir)
    return new_files

def _remove_files_from_device(outfiles_prefixes, old_files):
    '''Remove files from the remote device's temp directory.

    We remove all files starting with one of the elements of outfiles_prefixes
    which aren't listed in old_files.

    '''
    files_to_remove = _list_remote_temp_files(outfiles_prefixes) - old_files

    for f in files_to_remove:
        remote_toolbox_cmd('rm', f)
