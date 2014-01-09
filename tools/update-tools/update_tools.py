# Copyright (C) 2012 Mozilla Foundation
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
#
# APIs for building and testing OTA and FOTA updates for FxOS

import argparse
from cStringIO import StringIO
import datetime
import hashlib
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import xml.dom.minidom as minidom
import zipfile

# This needs to be run from within a B2G checkout
this_dir = os.path.abspath(os.path.dirname(__file__))
b2g_dir = os.path.dirname(os.path.dirname(this_dir))
bin_dir = os.path.join(this_dir, "bin")

def validate_env(parser):
    if platform.system() not in ("Linux", "Darwin"):
        parser.error("This tool only runs in Linux or Mac OS X")

    if not which("bash"):
        parser.error("This tool requires bash to be on your PATH")

    if sys.version_info < (2, 7):
        parser.error("This tool requires Python 2.7 or greater")

def run_command(*args, **kwargs):
    try:
        if "input" in kwargs:
            input = kwargs.pop("input")
            if "stdin" not in kwargs:
                kwargs["stdin"] = subprocess.PIPE
            if "stdout" not in kwargs:
                kwargs["stdout"] = subprocess.PIPE
            if "stderr" not in kwargs:
                kwargs["stderr"] = subprocess.PIPE

            proc = subprocess.Popen(*args, **kwargs)
            out, err = proc.communicate(input)
            if proc.returncode != 0:
                raise UpdateException("Processs returned error code %d: %s" % \
                                      (proc.returncode, err))
            return out

        return subprocess.check_output(*args, **kwargs)
    except subprocess.CalledProcessError, e:
        raise UpdateException("Process returned error code %d: %s" % \
                              (e.returncode, " ".join(e.cmd)))

# Copied from Lib/shutil.py in Python 3.3.0
# http://docs.python.org/3/license.html
def which(cmd, mode=os.F_OK | os.X_OK, path=None):
    """Given a command, mode, and a PATH string, return the path which
    conforms to the given mode on the PATH, or None if there is no such
    file.

    `mode` defaults to os.F_OK | os.X_OK. `path` defaults to the result
    of os.environ.get("PATH"), or can be overridden with a custom search
    path.

    """
    # Check that a given file can be accessed with the correct mode.
    # Additionally check that `file` is not a directory, as on Windows
    # directories pass the os.access check.
    def _access_check(fn, mode):
        return (os.path.exists(fn) and os.access(fn, mode)
                and not os.path.isdir(fn))

    # Short circuit. If we're given a full path which matches the mode
    # and it exists, we're done here.
    if _access_check(cmd, mode):
        return cmd

    path = (path or os.environ.get("PATH", os.defpath)).split(os.pathsep)

    if sys.platform == "win32":
        # The current directory takes precedence on Windows.
        if not os.curdir in path:
            path.insert(0, os.curdir)

        # PATHEXT is necessary to check on Windows.
        pathext = os.environ.get("PATHEXT", "").split(os.pathsep)
        # See if the given file matches any of the expected path extensions.
        # This will allow us to short circuit when given "python.exe".
        matches = [cmd for ext in pathext if cmd.lower().endswith(ext.lower())]
        # If it does match, only test that one, otherwise we have to try
        # others.
        files = [cmd] if matches else [cmd + ext.lower() for ext in pathext]
    else:
        # On other platforms you don't have things like PATHEXT to tell you
        # what file suffixes are executable, so just pass on cmd as-is.
        files = [cmd]

    seen = set()
    for dir in path:
        dir = os.path.normcase(dir)
        if not dir in seen:
            seen.add(dir)
            for thefile in files:
                name = os.path.join(dir, thefile)
                if _access_check(name, mode):
                    return name
    return None

class UpdateException(Exception): pass

class B2GConfig(object):
    CONFIG_VARS = ("GECKO_PATH", "GECKO_OBJDIR", "DEVICE")

    def __init__(self):
        shell = ". load-config.sh 1>&2"
        for var in self.CONFIG_VARS:
            shell += "\necho $%s" % var

        result = run_command(["bash", "-c", shell], cwd=b2g_dir,
                             env={"B2G_DIR": b2g_dir})

        if not result:
            raise UpdateException("Couldn't parse result of load-config.sh")

        lines = result.splitlines()
        if len(lines) != len(self.CONFIG_VARS):
            raise UpdateException("Wrong number of config vars: %d" % len(lines))

        for i in range(len(self.CONFIG_VARS)):
            setattr(self, self.CONFIG_VARS[i].lower(), lines[i].strip())

        self.init_gecko_path()
        if not self.gecko_objdir:
            self.gecko_objdir = os.path.join(self.gecko_path, "objdir-gecko")

    def init_gecko_path(self):
        if not self.gecko_path:
            self.gecko_path = os.path.join(b2g_dir, "gecko")

        if os.path.exists(self.gecko_path):
            return

        relative_gecko_path = os.path.join(b2g_dir, self.gecko_path)
        if os.path.exists(relative_gecko_path):
            self.gecko_path = relative_gecko_path
            return

        raise UpdateException("B2G gecko directory not found: %s" % self.gecko_path)

    def get_gecko_host_bin(self, path):
        return os.path.join(self.gecko_objdir, "dist", "host", "bin", path)

class Tool(object):
    def __init__(self, path, prebuilt=False):
        self.tool = path
        self.debug = False
        if prebuilt:
            self.init_prebuilt(path)

        if not os.path.exists(self.tool):
            raise UpdateException("Couldn't find %s " % self.tool)

    def init_prebuilt(self, path):
        host_dir = "linux-x86"
        if platform.system() == "Darwin":
            host_dir = "darwin-x86"

        self.tool = os.path.join(bin_dir, host_dir, path)

    def get_tool(self):
        return self.tool

    def run(self, *args, **kwargs):
        command = (self.tool, ) + args
        if self.debug:
            print " ".join(['"%s"' % c for c in command])

        return run_command(command, **kwargs)

class AdbTool(Tool):
    DEVICE   = ("-d")
    EMULATOR = ("-e")
    DEVICES_HEADER = "List of devices attached"

    def __init__(self, path=None, device=None):
        prebuilt = path is None
        if not path:
            path = "adb"
        Tool.__init__(self, path, prebuilt=prebuilt)

        self.adb_args = ()
        if device in (self.DEVICE, self.EMULATOR):
            self.adb_args = device
        elif device:
            self.adb_args = ("-s", device)

    def run(self, *args):
        adb_args = self.adb_args + args
        return Tool.run(self, *adb_args)

    def shell(self, *args):
        return self.run("shell", *args)

    def push(self, *args):
        self.run("push", *args)

    def file_exists(self, remote_file):
        result = self.shell("ls %s 2>/dev/null 1>/dev/null; echo $?" % \
                            remote_file)
        return result.strip() == "0"

    def get_pids(self, process):
        result = self.shell(
            "toolbox ps %s | (read header; while read user pid rest; do echo $pid; done)" % \
                process)

        return [line.strip() for line in result.splitlines()]

    def get_cmdline(self, pid):
        cmdline_path = "/proc/%s/cmdline" % pid
        if not self.file_exists(cmdline_path):
            raise UpdateException("Command line file for PID %s not found" % pid)

        result = self.shell("cat %s" % cmdline_path)
        # cmdline is null byte separated and has a trailing null byte
        return result.split("\x00")[:-1]

    def get_online_devices(self):
        output = self.run("devices")
        online = set()
        for line in output.split("\n"):
            if line.startswith(self.DEVICES_HEADER):
                continue

            tokens = line.split("\t")
            if len(tokens) != 2:
                continue

            device = tokens[0]
            state = tokens[1]
            if state == "device":
                online.add(device)

        return online

class MarTool(Tool):
    def __init__(self):
        Tool.__init__(self, b2g_config.get_gecko_host_bin("mar"))

    def list_entries(self, mar_path):
        result = self.run("-t", mar_path)
        entries = []
        for line in result.splitlines():
            words = re.split("\s+", line)
            if len(words) < 3: continue
            if words[0] == "SIZE": continue
            entries.append(words[2])
        return entries

    def create(self, mar_path, src_dir=None):
        if not src_dir:
            src_dir = os.getcwd()

        mar_args = ["-c", mar_path]

        # The MAR tool wants a listing of each file to add
        for root, dirs, files in os.walk(src_dir):
            for f in files:
                file_path = os.path.join(root, f)
                mar_args.append(os.path.relpath(file_path, src_dir))

        self.run(*mar_args, cwd=src_dir)

    def extract(self, mar_path, dest_dir=None):
        self.run("-x", mar_path, cwd=dest_dir)

    def is_gecko_mar(self, mar_path):
        return not self.is_fota_mar(mar_path)

    def is_fota_mar(self, mar_path):
        entries = self.list_entries(mar_path)
        return "update.zip" in entries

class BZip2Mar(object):
    def __init__(self, mar_file, verbose=False):
        self.mar_file = mar_file
        self.verbose = verbose
        self.mar_tool = MarTool()
        self.bzip2_tool = which("bzip2")
        if not self.bzip2_tool:
            raise UpdateException("Couldn't find bzip2 on the PATH")

    def bzip2(self, *args):
        bzargs = [self.bzip2_tool]
        if self.verbose:
            bzargs.append("-v")
        bzargs.extend(args)

        return run_command(bzargs)

    def create(self, src_dir):
        if not os.path.exists(src_dir):
            raise UpdateException("Source directory doesn't exist: %s" % src_dir)

        temp_dir = tempfile.mkdtemp()
        for root, dirs, files in os.walk(src_dir):
            for f in files:
                path = os.path.join(root, f)
                rel_file = os.path.relpath(path, src_dir)
                out_file = os.path.join(temp_dir, rel_file)
                out_dir = os.path.dirname(out_file)
                if not os.path.exists(out_dir):
                    os.makedirs(out_dir)

                shutil.copy(path, out_file)
                self.bzip2("-z", out_file)
                os.rename(out_file + ".bz2", out_file)

        self.mar_tool.create(self.mar_file, src_dir=temp_dir)

    def extract(self, dest_dir):
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
            if not os.path.exists(dest_dir):
                raise UpdateException("Couldn't create directory: %s" % dest_dir)

        self.mar_tool.extract(self.mar_file, dest_dir=dest_dir)
        for root, dirs, files in os.walk(dest_dir):
            for f in files:
                path = os.path.join(root, f)
                os.rename(path, path + ".bz2")
                self.bzip2("-d", path + ".bz2")

class FotaZip(zipfile.ZipFile):
    UPDATE_BINARY  = "META-INF/com/google/android/update-binary"
    UPDATER_SCRIPT = "META-INF/com/google/android/updater-script"
    MANIFEST_MF    = "META-INF/MANIFEST.MF"
    CERT_SF        = "META-INF/CERT.SF"

    def __init__(self, path, mode="r", compression=zipfile.ZIP_DEFLATED):
        zipfile.ZipFile.__init__(self, path, mode, compression)

    def has_entry(self, entry):
        try:
            self.getinfo(entry)
            return True
        except: return False

    def validate(self, signed=False):
        entries = (self.UPDATE_BINARY, self.UPDATER_SCRIPT)
        if signed:
            entries += (self.MANIFEST_MF, self.CERT_SF)

        for entry in entries:
            if not self.has_entry(entry):
                raise UpdateException("Update zip is missing expected file: %s" % entry)

    def write_updater_script(self, script):
        self.writestr(self.UPDATER_SCRIPT, script)

    def write_default_update_binary(self):
        prebuilt_update_binary = os.path.join(bin_dir, "gonk", "update-binary")
        self.write(prebuilt_update_binary, self.UPDATE_BINARY)

    def write_recursive(self, path, zip_path=None, filter=None):
        def zip_relpath(file_path):
            relpath = os.path.relpath(file_path, path)
            relpath = relpath.replace("\\", "/").lstrip("/")
            if zip_path:
                relpath = zip_path + "/" + relpath
            return relpath

        for root, dirs, files in os.walk(path):
            for f in files:
                file_path = os.path.join(root, f)
                relpath = zip_relpath(file_path)
                if not filter or filter(file_path, relpath):
                    self.write(file_path, relpath)

            if not filter:
                continue

            for d in dirs:
                dir_path = os.path.join(root, d)
                relpath = zip_relpath(dir_path)
                if not filter(dir_path, relpath):
                    dirs.remove(d)

class FotaZipBuilder(object):
    def build_unsigned_zip(self, update_dir, output_zip):
        if not os.path.exists(update_dir):
            raise UpdateException("Update dir doesn't exist: %s" % update_dir)

        update_binary = os.path.join(update_dir, FotaZip.UPDATE_BINARY)
        updater_script = os.path.join(update_dir, FotaZip.UPDATER_SCRIPT)
        if not os.path.exists(updater_script):
            raise UpdateException("updater-script not found at %s" % updater_script)

        update_zipfile = FotaZip(output_zip, "w")

        if not os.path.exists(update_binary):
            print "Warning: update-binary not found, using default"
            update_zipfile.write_default_update_binary()

        update_zipfile.write_recursive(update_dir)
        update_zipfile.close()

    def sign_zip(self, unsigned_zip, public_key, private_key, output_zip):
        java = which("java")
        if java is None:
            raise UpdateException("java is required to be on your PATH for signing")

        with FotaZip(unsigned_zip) as fota_zip:
            fota_zip.validate()

        if not os.path.exists(private_key):
            raise UpdateException("Private key doesn't exist: %s" % private_key)

        if not os.path.exists(public_key):
            raise UpdateException("Public key doesn't exist: %s" % public_key)

        signapk_jar = os.path.join(bin_dir, "signapk.jar")

        run_command([java, "-Xmx2048m", "-jar", signapk_jar,
            "-w", public_key, private_key, unsigned_zip, output_zip])

class FotaMarBuilder(object):
    def __init__(self):
        self.stage_dir = tempfile.mkdtemp()

    def __del__(self):
        shutil.rmtree(self.stage_dir)

    def build_mar(self, signed_zip, output_mar):
        with FotaZip(signed_zip) as fota_zip:
            fota_zip.validate(signed=True)

        mar_tool = MarTool()
        make_full_update = os.path.join(b2g_config.gecko_path, "tools",
            "update-packaging", "make_full_update.sh")
        if not os.path.exists(make_full_update):
            raise UpdateException("Couldn't find %s " % make_full_update)

        mar_dir = os.path.join(self.stage_dir, "mar")
        os.mkdir(mar_dir)

        # Inside the FOTA MAR, the update needs to be called "update.zip"
        shutil.copy(signed_zip, os.path.join(mar_dir, "update.zip"))

        precomplete = os.path.join(mar_dir, "precomplete")
        open(precomplete, "w").write("")

        run_command([make_full_update, output_mar, mar_dir],
            env={"MAR": mar_tool.get_tool()})

class GeckoMarBuilder(object):
    def __init__(self):
        self.mar_tool = MarTool()
        self.mbsdiff_tool = Tool(b2g_config.get_gecko_host_bin("mbsdiff"))
        packaging_dir = os.path.join(b2g_config.gecko_path, "tools",
            "update-packaging")

        self.make_full_update = os.path.join(packaging_dir,
            "make_full_update.sh")
        if not os.path.exists(self.make_full_update):
            raise UpdateException("Couldn't find %s " % make_full_update)

        self.make_incremental_update = os.path.join(packaging_dir,
            "make_incremental_update.sh")
        if not os.path.exists(self.make_incremental_update):
            raise UpdateException("Couldn't find %s " % make_incremental_update)

    def build_gecko_mar(self, src_dir, output_mar, from_dir=None):
        if from_dir:
            args = [self.make_incremental_update, output_mar, from_dir, src_dir]
        else:
            args = [self.make_full_update, output_mar, src_dir]

        run_command(args, env={
            "MAR": self.mar_tool.get_tool(),
            "MBSDIFF": self.mbsdiff_tool.get_tool()
        })

class UpdateXmlBuilder(object):
    DEFAULT_URL_TEMPLATE = "http://localhost/%(filename)s"
    DEFAULT_UPDATE_TYPE = "minor"
    DEFAULT_APP_VERSION = "99.0"
    DEFAULT_PLATFORM_VERSION = "99.0"
    DEFAULT_LICENSE_URL = "http://www.mozilla.com/test/sample-eula.html"
    DEFAULT_DETAILS_URL = "http://www.mozilla.com/test/sample-details.html"

    def __init__(self, complete_mar=None, partial_mar=None, url_template=None,
                 update_type=None, app_version=None, platform_version=None,
                 build_id=None, license_url=None, details_url=None,
                 is_fota_update=False):

        if complete_mar is None and partial_mar is None:
            raise UpdateException("either complete_mar or partial_mar is required")

        self.complete_mar = complete_mar
        self.partial_mar = partial_mar
        self.url_template = url_template or self.DEFAULT_URL_TEMPLATE
        self.update_type = update_type or self.DEFAULT_UPDATE_TYPE
        self.app_version = app_version or self.DEFAULT_APP_VERSION
        self.platform_version = platform_version or self.DEFAULT_PLATFORM_VERSION
        self.build_id = build_id or self.generate_build_id()
        self.license_url = license_url or self.DEFAULT_LICENSE_URL
        self.details_url = details_url or self.DEFAULT_DETAILS_URL
        self.is_fota_update = is_fota_update

    def generate_build_id(self):
        return datetime.datetime.now().strftime('%Y%m%d%H%M%S')

    def sha512(self, patch_path):
        patch_hash = hashlib.sha512()
        with open(patch_path, "r") as patch_file:
            data = patch_file.read(512)
            while len(data) > 0:
                patch_hash.update(data)
                data = patch_file.read(512)

        return patch_hash.hexdigest()

    def build_patch(self, patch_type, patch_file):
        patch = self.doc.createElement("patch")
        patch.setAttribute("type", patch_type)

        template_args = self.__dict__.copy()
        template_args["filename"] = os.path.basename(patch_file)
        patch.setAttribute("URL", self.url_template % template_args)

        patch.setAttribute("hashFunction", "SHA512")
        patch.setAttribute("hashValue", self.sha512(patch_file))
        patch.setAttribute("size", str(os.stat(patch_file).st_size))
        return patch

    def build_xml(self):
        impl = minidom.getDOMImplementation()
        self.doc = impl.createDocument(None, "updates", None)

        updates = self.doc.documentElement
        update = self.doc.createElement("update")
        updates.appendChild(update)

        update.setAttribute("type", self.update_type)
        update.setAttribute("appVersion", self.app_version)
        update.setAttribute("version", self.platform_version)
        update.setAttribute("buildID", self.build_id)
        update.setAttribute("licenseURL", self.license_url)
        update.setAttribute("detailsURL", self.details_url)

        if self.is_fota_update:
            update.setAttribute("isOSUpdate", "true")

        if self.complete_mar:
            complete_patch = self.build_patch("complete", self.complete_mar)
            update.appendChild(complete_patch)

        if self.partial_mar:
            partial_patch = self.build_patch("partial", self.partial_mar)
            update.appendChild(partial_patch)

        return self.doc.toprettyxml()

class UpdateXmlOptions(argparse.ArgumentParser):
    def __init__(self, output_arg=True):
        argparse.ArgumentParser.__init__(self, usage="%(prog)s [options] (update.mar)")
        self.add_argument("-c", "--complete-mar", dest="complete_mar", metavar="MAR",
            default=None, help="Path to a 'complete' MAR. This can also be " +
                               "provided as the first argument. Either " +
                               "--complete-mar or --partial-mar must be provided.")

        self.add_argument("-p", "--partial-mar", dest="partial_mar", metavar="MAR",
            default=None, help="Path to a 'partial' MAR")

        if output_arg:
            self.add_argument("-o", "--output", dest="output", metavar="FILE",
                default=None, help="Place to generate the update XML. Default: " +
                                   "print XML to stdout")

        self.add_argument("-u", "--url-template", dest="url_template", metavar="URL",
            default=None, help="A template for building URLs in the update.xml. " +
                               "Default: http://localhost/%%(filename)s")

        self.add_argument("-t", "--update-type", dest="update_type",
            default="minor", help="The update type. Default: minor")

        self.add_argument("-v", "--app-version", dest="app_version",
            default=None, help="The application version of this update. " +
                               "Default: 99.0")
        self.add_argument("-V", "--platform-version", dest="platform_version",
            default=None, help="The platform version of this update. Default: 99.0")

        self.add_argument("-i", "--build-id", dest="build_id",
            default=None, help="The Build ID of this update. Default: Current timestamp")

        self.add_argument("-l", "--license-url", dest="license_url",
            default=None, help="The license URL of this update. Default: " +
                                UpdateXmlBuilder.DEFAULT_LICENSE_URL)
        self.add_argument("-d", "--details-url", dest="details_url",
            default=None, help="The details URL of this update. Default: " +
                                UpdateXmlBuilder.DEFAULT_DETAILS_URL)

        self.add_argument("-O", "--fota-update", dest="fota_update",
            action="store_true", default=None,
            help="The complete MAR contains a FOTA update. " +
                 "Default: detect.\nNote: only 'complete' MARs can be FOTA updates.")

    def parse_args(self):
        validate_env(self)
        options, args = argparse.ArgumentParser.parse_known_args(self)
        if not options.complete_mar and len(args) > 0:
            options.complete_mar = args[0]

        if not options.complete_mar and not options.partial_mar:
            self.print_help()
            print >>sys.stderr, \
                "Error: At least one of --complete-mar or --partial-mar is required."
            sys.exit(1)

        fota_update = False
        if options.fota_update is None and options.complete_mar:
            if not os.path.exists(options.complete_mar):
                print >>sys.stderr, \
                    "Error: MAR doesn't exist: %s" % options.complete_mar
                sys.exit(1)

            mar_tool = MarTool()
            fota_update = mar_tool.is_fota_mar(options.complete_mar)
        elif options.fota_update:
            fota_update = True
            if not options.complete_mar:
                print >>sys.stderr, \
                    "Error: --fota-update provided without a --complete-mar"
                sys.exit(1)

        if options.partial_mar and fota_update:
            print >>sys.stderr, \
                "Warning: --partial-mar ignored for FOTA updates"
            options.partial_mar = None

        self.is_fota_update = fota_update
        self.options, self.args = options, args
        return options, args

    def get_output_xml(self):
        return self.options.output

    def get_complete_mar(self):
        return self.options.complete_mar

    def get_partial_mar(self):
        return self.options.partial_mar

    def get_url_template(self):
        return self.options.url_template

    def build_xml(self):
        option_keys = ("complete_mar", "partial_mar", "url_template",
            "update_type", "app_version", "platform_version", "build_id",
            "license_url", "details_url")

        kwargs = {"is_fota_update": self.is_fota_update}
        for key in option_keys:
            kwargs[key] = getattr(self.options, key)

        builder = UpdateXmlBuilder(**kwargs)
        return builder.build_xml()

class TestUpdate(object):
    REMOTE_BIN_DIR     = "/data/local/bin"
    REMOTE_BUSYBOX     = REMOTE_BIN_DIR + "/busybox"
    LOCAL_BUSYBOX      = os.path.join(bin_dir, "gonk", "busybox-armv6l")
    REMOTE_HTTP_ROOT   = "/data/local/b2g-updates"
    REMOTE_PROFILE_DIR = "/data/b2g/mozilla"

    def __init__(self, update_xml=None, complete_mar=None, partial_mar=None,
                 url_template=None, update_dir=None, only_override=False,
                 adb_path=None, remote_prefs_js=None):
        self.adb = AdbTool(path=adb_path)
        self.update_xml = update_xml

        if complete_mar is None and partial_mar is None and not only_override:
            raise UpdateException(
                "At least one of complete_mar or partial_mar is required")

        self.complete_mar = complete_mar
        self.partial_mar = partial_mar

        if only_override and not url_template:
            raise UpdateException("Update URL template required when only overriding")

        if update_dir and not url_template:
            raise UpdateException("Update URL template required with update dir")

        self.only_override = only_override
        self.is_local = update_dir is not None
        if not self.is_local:
            url_template = url_template or UpdateXmlBuilder.DEFAULT_URL_TEMPLATE

        self.update_url = url_template % { "filename": "update.xml" }
        self.stage_dir = update_dir if self.is_local else tempfile.mkdtemp()
        self.remote_prefs_js = remote_prefs_js

    def __del__(self):
        if not self.is_local:
            shutil.rmtree(self.stage_dir)

    def test_update(self, write_url_pref=True, restart=True):
        output_xml = os.path.join(self.stage_dir, "update.xml")
        with open(output_xml, "w") as out_file:
            out_file.write(self.update_xml)

        if not self.is_local:
            self.push_busybox()

        if not self.only_override:
            self.push_update_site()

        if not self.is_local:
            self.start_http_server()

        if write_url_pref:
            self.override_update_url()

        if restart:
            self.restart_b2g()

    def push_busybox(self):
        if self.adb.file_exists(self.REMOTE_BUSYBOX):
            print "Busybox already found at %s" % self.REMOTE_BUSYBOX
            return

        print "Busybox not found, pushing to %s" % self.REMOTE_BUSYBOX
        self.adb.shell("mkdir", "-p", self.REMOTE_BIN_DIR)
        self.adb.push(self.LOCAL_BUSYBOX, self.REMOTE_BUSYBOX)
        self.adb.shell("chmod", "755", self.REMOTE_BUSYBOX)

    def push_update_site(self):
        if self.complete_mar:
            if self.is_local:
                print "Copying %s to %s" % (self.complete_mar, self.stage_dir)
            shutil.copy(self.complete_mar, self.stage_dir)

        if self.partial_mar:
            if self.is_local:
                print "Copying %s to %s" % (self.partial_mar, self.stage_dir)
            shutil.copy(self.partial_mar, self.stage_dir)

        if not self.is_local:
            self.adb.push(self.stage_dir, self.REMOTE_HTTP_ROOT)

    def get_busybox_httpd_pid(self):
        pids = self.adb.get_pids("busybox")
        for pid in pids:
            cmdline = self.adb.get_cmdline(pid)
            if len(cmdline) > 1 and cmdline[1] == "httpd":
                return pid
        return None

    def start_http_server(self):
        busybox_pid = self.get_busybox_httpd_pid()
        if busybox_pid is not None:
            print "Busybox HTTP server already running, PID: %s" % busybox_pid
            return

        print "Starting Busybox HTTP server"
        self.adb.shell(self.REMOTE_BUSYBOX,
            "httpd", "-h", self.REMOTE_HTTP_ROOT)

        busybox_pid = self.get_busybox_httpd_pid()
        if busybox_pid is not None:
            print "Busybox HTTP server now running. Root: %s, PID: %s" % \
                (self.REMOTE_HTTP_ROOT, busybox_pid)
        else:
            print >>sys.stderr, "Error: Busybox HTTP server PID not running"
            sys.exit(1)

    def override_update_url(self):
        if not self.remote_prefs_js:
            profile_dir = self.adb.shell("echo -n %s/*.default" % \
                                         self.REMOTE_PROFILE_DIR)
            if "*" in profile_dir:
                raise UpdateException("Unable to find profile dir in %s" % \
                                      self.REMOTE_PROFILE_DIR)

            self.remote_prefs_js = profile_dir + "/prefs.js"

        url_pref = "app.update.url.override"
        print "Overriding update URL in %s to %s" % (self.remote_prefs_js, self.update_url)
        self.adb.shell("echo 'user_pref(\"%s\", \"%s\");' >> %s" % \
                       (url_pref, self.update_url, self.remote_prefs_js))

    def restart_b2g(self):
        print "Restarting B2G"
        self.adb.shell("stop b2g; start b2g")

class Partition(object):
    def __init__(self, fs_type, mount_point, device, fs_size=0):
        self.fs_type = fs_type
        self.mount_point = mount_point
        self.device = device
        self.fs_size = fs_size

    @classmethod
    def create_system(cls, fs_type, device):
        return Partition(fs_type, "/system", device)

    @classmethod
    def create_data(cls, fs_type, device):
        return Partition(fs_type, "/data", device)

class FlashFotaBuilder(object):
    def __init__(self, system, data):
        self.fstab = { "/system": system, "/data": data }
        self.symlinks = []

        if "Item" not in globals():
            self.import_releasetools()
        self.generator = edify_generator.EdifyGenerator(1, {"fstab": self.fstab})

    def AssertMountIfNeeded(self, mount_point):
        """
           AssertMount the partition with the given mount_point
           if it is not already mounted.
        """
        fstab = self.generator.info.get("fstab", None)
        if fstab:
            p = fstab[mount_point]
            self.generator.Print("Mounting " + mount_point)
            self.generator.script.append(
               'ifelse(is_mounted("%s"),' \
               'ui_print("Already mounted."),' \
               'assert(mount("%s", "%s", "%s", "%s")));' %
                (p.mount_point,
                 p.fs_type, common.PARTITION_TYPES[p.fs_type],
                 p.device, p.mount_point))
            self.generator.mounts.add(p.mount_point)

    def import_releasetools(self):
        releasetools_dir = os.path.join(b2g_dir, "build", "tools", "releasetools")
        sys.path.append(releasetools_dir)
        execfile(os.path.join(b2g_dir, "build", "tools", "releasetools",
                              "ota_from_target_files"), globals())
        sys.path.pop()

    def zip_filter(self, path, relpath):
        if self.fota_type == 'partial':
            if not relpath in self.fota_files:
                return False
        Item.Get(relpath, dir=os.path.isdir(path))
        if not os.path.isdir(path) and os.path.islink(path):
            # This assumes that system always maps to /system, data to /data, etc
            self.symlinks.append((os.readlink(path), "/" + relpath))
            return False
        return True

    def build_flash_fota(self, system_dir, public_key, private_key, output_zip):
        fd, unsigned_zip = tempfile.mkstemp()
        os.close(fd)

        with FotaZip(unsigned_zip, "w") as flash_zip:
            flash_zip.write_recursive(system_dir, "system", filter=self.zip_filter)
            flash_zip.write_updater_script(self.build_flash_script())
            flash_zip.write_default_update_binary()

        FotaZipBuilder().sign_zip(unsigned_zip, public_key, private_key,
                                  output_zip)
        os.unlink(unsigned_zip)

    def build_flash_script(self):
        self.generator.Print("Starting B2G FOTA: " + self.fota_type)

        if not self.fota_type == 'partial':
            for mount_point, partition in self.fstab.iteritems():
                partition_type = common.PARTITION_TYPES[partition.fs_type]
                self.generator.AppendExtra('format("%s", "%s", "%s", %d);' % \
                    (partition.fs_type, partition_type, partition.device,
                     partition.fs_size))

        for mount_point in self.fstab:
            self.AssertMountIfNeeded(mount_point)

        if self.fota_type == 'partial':
            for d in self.fota_dirs:
                self.generator.Print("Cleaning " + d)
                cmd = ('delete_recursive("%s");' % ("/"+d))
                self.generator.script.append(self.generator._WordWrap(cmd))

            cmd = ('if greater_than_int(run_program("/system/bin/mv", "/system/b2g.bak", "/system/b2g"), 0) then')
            self.generator.script.append(self.generator._WordWrap(cmd))
            self.generator.Print("No previous stale update.")

        self.generator.Print("Remove stale libdmd.so")
        self.generator.DeleteFiles(["/system/b2g/libdmd.so"])

        self.generator.Print("Remove stale update")
        cmd = ('delete_recursive("/system/b2g/updated");')
        self.generator.script.append(self.generator._WordWrap(cmd))

        self.generator.Print("Extracting files to /system")
        self.generator.UnpackPackageDir("system", "/system")

        self.generator.Print("Creating symlinks")
        self.generator.MakeSymlinks(self.symlinks)

        self.generator.Print("Setting file permissions")
        self.build_permissions()

        if self.fota_type == 'partial':
            cmd = ('else ui_print("Restoring previous stale update."); endif;')
            self.generator.script.append(self.generator._WordWrap(cmd))

        self.generator.Print("Unmounting ...")
        self.generator.UnmountAll()

        return "\n".join(self.generator.script) + "\n"

    def build_permissions(self):
        # Put fs_config on the PATH
        host = "linux-x86"
        if platform.system() == "Darwin":
            host = "darwin-x86"

        host_bin_dir = os.path.join(b2g_dir, "out", "host", host, "bin")
        fs_config = Tool(os.path.join(host_bin_dir, "fs_config"))
        suffix = { False: "", True: "/" }
        paths = "\n".join([i.name + suffix[i.dir]
                           for i in Item.ITEMS.itervalues() if i.name]) + '\n'
        self.fs_config_data = fs_config.run(input=paths)

        # see build/tools/releasetools/ota_from_target_files
        Item.GetMetadata(self)
        if not self.fota_type == 'partial':
            Item.Get("system").SetPermissions(self.generator)
        else:
            for d in self.fota_dirs:
                Item.Get(d).SetPermissions(self.generator)

    "Emulate zipfile.read so we can reuse Item.GetMetadata"
    def read(self, path):
        if path == "META/filesystem_config.txt":
            return self.fs_config_data
        raise KeyError

b2g_config = B2GConfig()
