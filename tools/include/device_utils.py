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

    adb shell doesn't check the remote command's error code.  So to check this
    ourselves, we echo $? after running the command and then strip that off
    before returning the command's output.
    
    '''
    out = shell(r"""adb shell '%s; echo -n "\n$?"'""" % cmd)

    # The final '\n' in |out| separates the command output from the return
    # code.  (There's no newline after the return code because we did echo -n.)
    (cmd_out, _, retcode) = out.rpartition('\n')
    retcode = retcode.strip()

    if retcode == '0':
        return cmd_out

    print('Remote command %s failed with error code %s' % (cmd, retcode),
          file=sys.stderr)
    if cmd_out:
        print(cmd_out, file=sys.stderr)
    raise subprocess.CalledProcessError(retcode, cmd, cmd_out)

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
    procs = remote_shell('ps').split('\n')
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

def send_signal_and_pull_files(signal,
                              outfiles_prefixes,
                              remove_outfiles_from_device,
                              out_dir,
                              optional_outfiles_prefixes=[]):
    '''Send a signal to the main B2G process and pull files created as a
    result.

    We send the given signal (which may be either a number of a string of the
    form 'SIGRTn', which we interpret as the signal SIGRTMIN + n) and pull the
    files generated into out_dir on the host machine.  We only pull files
    which were created after the signal was sent.

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
    (master_pid, child_pids) = get_remote_b2g_pids()
    old_files = _list_remote_temp_files(outfiles_prefixes)
    _send_remote_signal(signal, master_pid)

    all_outfiles_prefixes = outfiles_prefixes + optional_outfiles_prefixes

    num_expected_files = len(outfiles_prefixes) * (1 + len(child_pids))
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

def _list_remote_temp_files(prefixes):
    '''Return a set of absolute filenames in the device's temp directory which
    start with one of the given prefixes.'''
    return set(['/data/local/tmp/' + f.strip() for f in
                remote_shell('ls /data/local/tmp').split('\n')
                if any([f.strip().startswith(prefix) for prefix in prefixes])])

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

    # Hopefully this command line won't get too long for ADB.
    remote_shell('rm %s' % ' '.join([str(f) for f in files_to_remove]))
